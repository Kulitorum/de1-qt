#include "bookooscale.h"
#include "../protocol/de1characteristics.h"
#include <QDebug>

// Helper macro that logs to both qDebug and emits signal for UI/file logging
#define BOOKOO_LOG(msg) do { \
    QString _msg = msg; \
    qDebug().noquote() << _msg; \
    emit logMessage(_msg); \
} while(0)

BookooScale::BookooScale(QObject* parent)
    : ScaleDevice(parent)
{
    m_watchdogTimer.setSingleShot(true);
    connect(&m_watchdogTimer, &QTimer::timeout, this, &BookooScale::onWatchdogTimeout);
}

BookooScale::~BookooScale() {
    stopWatchdog();
    disconnectFromScale();
}

void BookooScale::connectToDevice(const QBluetoothDeviceInfo& device) {
    if (m_controller) {
        disconnectFromScale();
    }

    m_name = device.name();
    m_controller = QLowEnergyController::createCentral(device, this);

    connect(m_controller, &QLowEnergyController::connected,
            this, &BookooScale::onControllerConnected);
    connect(m_controller, &QLowEnergyController::disconnected,
            this, &BookooScale::onControllerDisconnected);
    connect(m_controller, &QLowEnergyController::errorOccurred,
            this, &BookooScale::onControllerError);
    connect(m_controller, &QLowEnergyController::serviceDiscovered,
            this, &BookooScale::onServiceDiscovered);

    m_controller->connectToDevice();
}

void BookooScale::onControllerConnected() {
    BOOKOO_LOG("Bookoo: Controller connected, starting service discovery");
    connect(m_controller, &QLowEnergyController::discoveryFinished,
            this, [this]() {
        BOOKOO_LOG(QString("Bookoo: Service discovery finished, service found: %1").arg(m_service != nullptr));
        if (!m_service) {
            BOOKOO_LOG(QString("Bookoo: Service %1 not found!").arg(Scale::Bookoo::SERVICE.toString()));
            BOOKOO_LOG("Bookoo: Available services:");
            for (const auto& uuid : m_controller->services()) {
                BOOKOO_LOG(QString("  - %1").arg(uuid.toString()));
            }
            emit errorOccurred("Bookoo service not found");
        }
    });
    m_controller->discoverServices();
}

void BookooScale::onControllerDisconnected() {
    stopWatchdog();
    m_receivedData = false;
    setConnected(false);
}

void BookooScale::onControllerError(QLowEnergyController::Error error) {
    Q_UNUSED(error)
    stopWatchdog();
    m_receivedData = false;
    emit errorOccurred("Bookoo scale connection error");
    setConnected(false);
}

void BookooScale::onServiceDiscovered(const QBluetoothUuid& uuid) {
    BOOKOO_LOG(QString("Bookoo: Service discovered: %1").arg(uuid.toString()));
    if (uuid == Scale::Bookoo::SERVICE) {
        BOOKOO_LOG("Bookoo: Found Bookoo service, creating service object");
        m_service = m_controller->createServiceObject(uuid, this);
        if (m_service) {
            connect(m_service, &QLowEnergyService::stateChanged,
                    this, &BookooScale::onServiceStateChanged);
            connect(m_service, &QLowEnergyService::characteristicChanged,
                    this, &BookooScale::onCharacteristicChanged);
            connect(m_service, &QLowEnergyService::descriptorWritten,
                    this, &BookooScale::onDescriptorWritten);
            connect(m_service, &QLowEnergyService::errorOccurred,
                    this, [this](QLowEnergyService::ServiceError error) {
                BOOKOO_LOG(QString("Bookoo: Service error: %1").arg(static_cast<int>(error)));
            });
            m_service->discoverDetails();
        } else {
            BOOKOO_LOG("Bookoo: Failed to create service object!");
        }
    }
}

void BookooScale::onServiceStateChanged(QLowEnergyService::ServiceState state) {
    BOOKOO_LOG(QString("Bookoo: Service state changed to: %1").arg(static_cast<int>(state)));
    if (state == QLowEnergyService::RemoteServiceDiscovered) {
        m_statusChar = m_service->characteristic(Scale::Bookoo::STATUS);
        m_cmdChar = m_service->characteristic(Scale::Bookoo::CMD);

        BOOKOO_LOG(QString("Bookoo: STATUS char valid: %1, properties: %2")
                   .arg(m_statusChar.isValid())
                   .arg(static_cast<int>(m_statusChar.properties())));
        BOOKOO_LOG(QString("Bookoo: CMD char valid: %1").arg(m_cmdChar.isValid()));

        if (!m_statusChar.isValid()) {
            BOOKOO_LOG("Bookoo: STATUS characteristic not found! Available characteristics:");
            for (const auto& c : m_service->characteristics()) {
                BOOKOO_LOG(QString("  - %1 properties: %2")
                           .arg(c.uuid().toString())
                           .arg(static_cast<int>(c.properties())));
            }
            emit errorOccurred("Bookoo STATUS characteristic not found");
            return;
        }

        // Reset watchdog state for new connection
        m_notificationRetries = 0;
        m_receivedData = false;

        // Delay notification subscription by 200ms (matches de1app behavior)
        // This gives the BLE stack time to stabilize after service discovery
        QTimer::singleShot(INITIAL_DELAY_MS, this, &BookooScale::enableNotifications);
    }
}

void BookooScale::enableNotifications() {
    if (!m_service || !m_statusChar.isValid()) {
        BOOKOO_LOG("Bookoo: Cannot enable notifications - service or characteristic invalid");
        return;
    }

    BOOKOO_LOG(QString("Bookoo: Enabling notifications (attempt %1)").arg(m_notificationRetries + 1));

    // Subscribe to status notifications
    QLowEnergyDescriptor notification = m_statusChar.descriptor(
        QBluetoothUuid::DescriptorType::ClientCharacteristicConfiguration);
    if (notification.isValid()) {
        BOOKOO_LOG("Bookoo: Writing CCCD descriptor to enable notifications");
        m_service->writeDescriptor(notification, QByteArray::fromHex("0100"));
    } else {
        BOOKOO_LOG("Bookoo: CCCD descriptor not found! Descriptors available:");
        for (const auto& d : m_statusChar.descriptors()) {
            BOOKOO_LOG(QString("  - %1").arg(d.uuid().toString()));
        }
        // Try enabling without explicit CCCD write - some stacks handle this automatically
        BOOKOO_LOG("Bookoo: Attempting connection anyway...");
    }

    // Start watchdog to retry if no data received
    startWatchdog();
}

void BookooScale::onDescriptorWritten(const QLowEnergyDescriptor& descriptor, const QByteArray& value) {
    Q_UNUSED(descriptor)
    Q_UNUSED(value)
    BOOKOO_LOG("Bookoo: Notification descriptor written successfully");
    // Don't set connected here - wait for actual weight data
}

void BookooScale::onCharacteristicChanged(const QLowEnergyCharacteristic& c, const QByteArray& value) {
    if (c.uuid() == Scale::Bookoo::STATUS) {
        // First data received - we're truly connected now
        if (!m_receivedData) {
            m_receivedData = true;
            stopWatchdog();
            setConnected(true);
            BOOKOO_LOG("Bookoo: First weight data received, connection confirmed");
        }

        // Bookoo format: h1 h2 h3 h4 h5 h6 sign w1 w2 w3
        if (value.size() >= 10) {
            const uint8_t* d = reinterpret_cast<const uint8_t*>(value.constData());

            char sign = static_cast<char>(d[6]);

            // Weight is 3 bytes big-endian in hundredths of gram
            uint32_t weightRaw = (d[7] << 16) | (d[8] << 8) | d[9];
            double weight = weightRaw / 100.0;

            if (sign == '-') {
                weight = -weight;
            }

            setWeight(weight);
        }
    }
}

void BookooScale::sendCommand(const QByteArray& cmd) {
    if (!m_service || !m_cmdChar.isValid()) return;
    m_service->writeCharacteristic(m_cmdChar, cmd);
}

void BookooScale::tare() {
    sendCommand(QByteArray::fromHex("030A01000008"));
}

void BookooScale::startTimer() {
    sendCommand(QByteArray::fromHex("030A0400000A"));
}

void BookooScale::stopTimer() {
    sendCommand(QByteArray::fromHex("030A0500000D"));
}

void BookooScale::resetTimer() {
    sendCommand(QByteArray::fromHex("030A0600000C"));
}

void BookooScale::startWatchdog() {
    m_watchdogTimer.start(WATCHDOG_INTERVAL_MS);
}

void BookooScale::stopWatchdog() {
    m_watchdogTimer.stop();
    m_notificationRetries = 0;
}

void BookooScale::onWatchdogTimeout() {
    // If we've received data, the scale is working - no need to retry
    if (m_receivedData) {
        return;
    }

    m_notificationRetries++;

    if (m_notificationRetries >= MAX_NOTIFICATION_RETRIES) {
        BOOKOO_LOG(QString("Bookoo: Failed to receive weight data after %1 attempts, giving up")
                   .arg(MAX_NOTIFICATION_RETRIES));
        emit errorOccurred("Bookoo scale not responding - no weight data received");
        // Don't disconnect - the BLE connection might still be valid,
        // but we couldn't get notifications working
        return;
    }

    BOOKOO_LOG(QString("Bookoo: No weight data received, retrying notification subscription (%1/%2)")
               .arg(m_notificationRetries).arg(MAX_NOTIFICATION_RETRIES));

    // Retry enabling notifications (matches de1app watchdog_first behavior)
    enableNotifications();
}
