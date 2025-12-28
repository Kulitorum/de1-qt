#include "batterydrainer.h"
#include <QDebug>
#include <QGuiApplication>
#include <QScreen>
#include <QFile>
#include <QTextStream>
#include <QDir>
#include <QRegularExpression>
#include <cmath>

#ifdef Q_OS_ANDROID
#include <QJniObject>
#include <QJniEnvironment>
#include <QCoreApplication>
#endif

// CPU worker - does heavy math to drain battery
void CpuWorker::run() {
    qDebug() << "CpuWorker: Starting on thread" << QThread::currentThreadId();

    // Mix of integer and floating point work for maximum power draw
    volatile double result = 0.0;
    volatile uint64_t primeCount = 0;

    while (m_running) {
        // Prime number search (integer heavy)
        for (int n = 2; n < 10000 && m_running; n++) {
            bool isPrime = true;
            for (int i = 2; i * i <= n; i++) {
                if (n % i == 0) {
                    isPrime = false;
                    break;
                }
            }
            if (isPrime) primeCount++;
        }

        // Floating point heavy (trig functions, sqrt)
        for (int i = 0; i < 10000 && m_running; i++) {
            result += std::sin(i * 0.001) * std::cos(i * 0.002);
            result += std::sqrt(std::abs(result) + 1.0);
            result += std::tan(i * 0.0001);
            result = std::fmod(result, 1000000.0);  // Prevent overflow
        }

        // Matrix-like operations
        double matrix[4][4];
        for (int i = 0; i < 4; i++) {
            for (int j = 0; j < 4; j++) {
                matrix[i][j] = std::sin(i + j + result);
            }
        }
        for (int k = 0; k < 100; k++) {
            for (int i = 0; i < 4; i++) {
                for (int j = 0; j < 4; j++) {
                    double sum = 0;
                    for (int m = 0; m < 4; m++) {
                        sum += matrix[i][m] * matrix[m][j];
                    }
                    matrix[i][j] = std::fmod(sum, 1000.0);
                }
            }
        }
        result += matrix[0][0];
    }

    qDebug() << "CpuWorker: Stopping, result=" << result << "primes=" << primeCount;
}

BatteryDrainer::BatteryDrainer(QObject* parent)
    : QObject(parent)
{
    // Set up stats timer to update CPU/GPU usage every 500ms
    connect(&m_statsTimer, &QTimer::timeout, this, &BatteryDrainer::updateUsageStats);
    m_statsTimer.setInterval(500);
}

BatteryDrainer::~BatteryDrainer() {
    stop();
}

void BatteryDrainer::start() {
    if (m_running) return;

    qDebug() << "BatteryDrainer: Starting battery drain";
    m_running = true;
    emit runningChanged();

    startCpuWorkers();
    setMaxBrightness();

    // Start monitoring stats
    m_statsTimer.start();
    updateUsageStats();
}

void BatteryDrainer::stop() {
    if (!m_running) return;

    qDebug() << "BatteryDrainer: Stopping battery drain";
    m_running = false;
    emit runningChanged();

    m_statsTimer.stop();
    stopCpuWorkers();
    restoreBrightness();

    m_cpuUsage = 0.0;
    m_gpuUsage = 0.0;
    emit cpuUsageChanged();
    emit gpuUsageChanged();
}

void BatteryDrainer::toggle() {
    if (m_running) {
        stop();
    } else {
        start();
    }
}

void BatteryDrainer::startCpuWorkers() {
    // Create one worker per CPU core for maximum drain
    int numCores = QThread::idealThreadCount();
    qDebug() << "BatteryDrainer: Starting" << numCores << "CPU workers";

    for (int i = 0; i < numCores; i++) {
        auto* worker = new CpuWorker(this);
        worker->start(QThread::HighPriority);
        m_workers.append(worker);
    }
}

void BatteryDrainer::stopCpuWorkers() {
    qDebug() << "BatteryDrainer: Stopping" << m_workers.size() << "CPU workers";

    // Signal all workers to stop
    for (auto* worker : m_workers) {
        worker->stop();
    }

    // Wait for all to finish
    for (auto* worker : m_workers) {
        worker->wait(1000);
        if (worker->isRunning()) {
            worker->terminate();
            worker->wait(500);
        }
        delete worker;
    }

    m_workers.clear();
}

void BatteryDrainer::setMaxBrightness() {
#ifdef Q_OS_ANDROID
    qDebug() << "BatteryDrainer: Setting max brightness";

    // First, read current brightness (can do from any thread)
    QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (!activity.isValid()) return;

    QJniObject window = activity.callObjectMethod(
        "getWindow", "()Landroid/view/Window;");
    if (!window.isValid()) return;

    QJniObject params = window.callObjectMethod(
        "getAttributes", "()Landroid/view/WindowManager$LayoutParams;");
    if (!params.isValid()) return;

    m_savedBrightness = params.getField<jfloat>("screenBrightness") * 255;
    qDebug() << "BatteryDrainer: Saved brightness:" << m_savedBrightness;

    // Set brightness on UI thread
    QNativeInterface::QAndroidApplication::runOnAndroidMainThread([]() {
        QJniObject activity = QNativeInterface::QAndroidApplication::context();
        if (!activity.isValid()) return;

        QJniObject window = activity.callObjectMethod(
            "getWindow", "()Landroid/view/Window;");
        if (!window.isValid()) return;

        QJniObject params = window.callObjectMethod(
            "getAttributes", "()Landroid/view/WindowManager$LayoutParams;");
        if (!params.isValid()) return;

        params.setField<jfloat>("screenBrightness", 1.0f);
        window.callMethod<void>("setAttributes",
            "(Landroid/view/WindowManager$LayoutParams;)V",
            params.object());
    });

    qDebug() << "BatteryDrainer: Brightness set to max";
#else
    qDebug() << "BatteryDrainer: Brightness control not available on this platform";
#endif
}

void BatteryDrainer::restoreBrightness() {
#ifdef Q_OS_ANDROID
    if (m_savedBrightness < 0) return;

    qDebug() << "BatteryDrainer: Restoring brightness to" << m_savedBrightness;

    float brightness = (m_savedBrightness > 0) ? (m_savedBrightness / 255.0f) : -1.0f;
    m_savedBrightness = -1;

    QNativeInterface::QAndroidApplication::runOnAndroidMainThread([brightness]() {
        QJniObject activity = QNativeInterface::QAndroidApplication::context();
        if (!activity.isValid()) return;

        QJniObject window = activity.callObjectMethod(
            "getWindow", "()Landroid/view/Window;");
        if (!window.isValid()) return;

        QJniObject params = window.callObjectMethod(
            "getAttributes", "()Landroid/view/WindowManager$LayoutParams;");
        if (!params.isValid()) return;

        params.setField<jfloat>("screenBrightness", brightness);
        window.callMethod<void>("setAttributes",
            "(Landroid/view/WindowManager$LayoutParams;)V",
            params.object());
    });
#endif
}

void BatteryDrainer::updateUsageStats() {
    double cpu = readCpuUsage();
    double gpu = readGpuUsage();

    if (cpu != m_cpuUsage) {
        m_cpuUsage = cpu;
        emit cpuUsageChanged();
    }

    if (gpu != m_gpuUsage) {
        m_gpuUsage = gpu;
        emit gpuUsageChanged();
    }
}

double BatteryDrainer::readCpuUsage() {
#if defined(Q_OS_ANDROID) || defined(Q_OS_LINUX)
    // Read /proc/stat to get CPU usage
    QFile file("/proc/stat");
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return 0.0;
    }

    QString line = file.readLine();
    file.close();

    // Parse: cpu  user nice system idle iowait irq softirq steal guest guest_nice
    QStringList parts = line.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);
    if (parts.size() < 5 || parts[0] != "cpu") {
        return 0.0;
    }

    uint64_t user = parts[1].toULongLong();
    uint64_t nice = parts[2].toULongLong();
    uint64_t system = parts[3].toULongLong();
    uint64_t idle = parts[4].toULongLong();
    uint64_t iowait = (parts.size() > 5) ? parts[5].toULongLong() : 0;
    uint64_t irq = (parts.size() > 6) ? parts[6].toULongLong() : 0;
    uint64_t softirq = (parts.size() > 7) ? parts[7].toULongLong() : 0;

    uint64_t idleTime = idle + iowait;
    uint64_t totalTime = user + nice + system + idle + iowait + irq + softirq;

    // Calculate delta since last read
    uint64_t idleDelta = idleTime - m_prevIdleTime;
    uint64_t totalDelta = totalTime - m_prevTotalTime;

    m_prevIdleTime = idleTime;
    m_prevTotalTime = totalTime;

    if (totalDelta == 0) {
        return 0.0;
    }

    double usage = 100.0 * (1.0 - (double)idleDelta / (double)totalDelta);
    return qBound(0.0, usage, 100.0);
#else
    // No /proc/stat on Windows/macOS - estimate based on workers
    return m_running ? 95.0 : 0.0;
#endif
}

double BatteryDrainer::readGpuUsage() {
#ifdef Q_OS_ANDROID
    // Try various GPU sysfs paths (device-specific)
    static const QStringList gpuPaths = {
        // Qualcomm Adreno
        "/sys/class/kgsl/kgsl-3d0/gpu_busy_percentage",
        "/sys/class/kgsl/kgsl-3d0/gpubusy",
        // Mali
        "/sys/devices/platform/mali.0/utilization",
        "/sys/kernel/gpu/gpu_busy",
        // Generic
        "/sys/class/devfreq/gpufreq/load",
    };

    for (const QString& path : gpuPaths) {
        QFile file(path);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QString content = file.readAll().trimmed();
            file.close();

            // Try to parse percentage
            bool ok;
            double value = content.toDouble(&ok);
            if (ok && value >= 0 && value <= 100) {
                return value;
            }

            // Handle "X Y" format (busy total) from some drivers
            QStringList parts = content.split(' ');
            if (parts.size() >= 2) {
                double busy = parts[0].toDouble(&ok);
                if (ok) {
                    double total = parts[1].toDouble();
                    if (total > 0) {
                        return 100.0 * busy / total;
                    }
                }
            }
        }
    }

    // Can't read GPU - estimate based on running state
    return m_running ? 80.0 : 0.0;
#else
    // No GPU stats on desktop platforms
    return m_running ? 80.0 : 0.0;
#endif
}
