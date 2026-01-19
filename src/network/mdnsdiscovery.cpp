#include "mdnsdiscovery.h"

#include <QDebug>
#include <QVariantMap>

#ifdef Q_OS_ANDROID
#include <QJniEnvironment>
#include <QCoreApplication>
#endif

MdnsDiscovery::MdnsDiscovery(QObject* parent)
    : QObject(parent)
{
    m_timeoutTimer.setSingleShot(true);
    connect(&m_timeoutTimer, &QTimer::timeout, this, &MdnsDiscovery::onDiscoveryTimeout);
}

MdnsDiscovery::~MdnsDiscovery()
{
    stopDiscovery();
}

void MdnsDiscovery::startDiscovery()
{
    if (m_scanning) {
        return;
    }

    m_scanning = true;
    emit scanningChanged();

    qDebug() << "MdnsDiscovery: Starting discovery for _mqtt._tcp services";

#ifdef Q_OS_ANDROID
    // Android NSD discovery
    // Note: Full implementation requires a Java helper class for NsdManager callbacks
    // For now, we'll use a simplified approach

    QJniObject context = QJniObject::callStaticObjectMethod(
        "org/qtproject/qt/android/QtNative",
        "getContext",
        "()Landroid/content/Context;");

    if (context.isValid()) {
        m_nsdManager = context.callObjectMethod(
            "getSystemService",
            "(Ljava/lang/String;)Ljava/lang/Object;",
            QJniObject::fromString("servicediscovery").object<jstring>());

        if (m_nsdManager.isValid()) {
            qDebug() << "MdnsDiscovery: Got NsdManager, discovery active";
            m_androidDiscoveryActive = true;
            // Note: Full discovery requires implementing DiscoveryListener in Java
            // For now, show a message that discovery is running
        } else {
            qWarning() << "MdnsDiscovery: Failed to get NsdManager";
            emit discoveryError("Failed to initialize network service discovery");
        }
    } else {
        qWarning() << "MdnsDiscovery: Failed to get Android context";
        emit discoveryError("Failed to get Android context");
    }
#else
    // Non-Android platforms
    // mDNS discovery requires platform-specific implementations:
    // - macOS/iOS: NSNetServiceBrowser
    // - Linux: Avahi client
    // - Windows: dns-sd.exe or Bonjour SDK
    // For now, indicate that manual entry is required
    qDebug() << "MdnsDiscovery: mDNS discovery not fully implemented on this platform";
    qDebug() << "MdnsDiscovery: Please enter broker address manually";
#endif

    // Start timeout timer
    m_timeoutTimer.start(DISCOVERY_TIMEOUT_MS);
}

void MdnsDiscovery::stopDiscovery()
{
    if (!m_scanning) {
        return;
    }

    m_timeoutTimer.stop();

#ifdef Q_OS_ANDROID
    if (m_androidDiscoveryActive && m_nsdManager.isValid()) {
        // Stop discovery
        m_androidDiscoveryActive = false;
    }
#endif

    m_scanning = false;
    emit scanningChanged();

    qDebug() << "MdnsDiscovery: Discovery stopped";
}

void MdnsDiscovery::clearServices()
{
    m_services.clear();
    emit servicesChanged();
}

void MdnsDiscovery::onDiscoveryTimeout()
{
    qDebug() << "MdnsDiscovery: Discovery timeout reached";
    stopDiscovery();

    if (m_services.isEmpty()) {
        qDebug() << "MdnsDiscovery: No services found";
    }
}

void MdnsDiscovery::addService(const QString& name, const QString& host, int port)
{
    // Check if service already exists
    for (const QVariant& service : m_services) {
        QVariantMap map = service.toMap();
        if (map["host"].toString() == host && map["port"].toInt() == port) {
            return;  // Already exists
        }
    }

    QVariantMap service;
    service["name"] = name;
    service["host"] = host;
    service["port"] = port;

    m_services.append(service);
    emit servicesChanged();
    emit serviceFound(name, host, port);

    qDebug() << "MdnsDiscovery: Found service" << name << "at" << host << ":" << port;
}

void MdnsDiscovery::removeService(const QString& name)
{
    for (int i = 0; i < m_services.size(); ++i) {
        QVariantMap map = m_services[i].toMap();
        if (map["name"].toString() == name) {
            m_services.removeAt(i);
            emit servicesChanged();
            qDebug() << "MdnsDiscovery: Removed service" << name;
            return;
        }
    }
}

#ifdef Q_OS_ANDROID
void MdnsDiscovery::onServiceFound(const QString& name, const QString& host, int port)
{
    addService(name, host, port);
}

void MdnsDiscovery::onServiceLost(const QString& name)
{
    removeService(name);
}
#endif
