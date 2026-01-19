#pragma once

#include <QObject>
#include <QVariantList>
#include <QTimer>

#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif

class MdnsDiscovery : public QObject {
    Q_OBJECT

    Q_PROPERTY(QVariantList discoveredServices READ discoveredServices NOTIFY servicesChanged)
    Q_PROPERTY(bool scanning READ isScanning NOTIFY scanningChanged)

public:
    explicit MdnsDiscovery(QObject* parent = nullptr);
    ~MdnsDiscovery();

    QVariantList discoveredServices() const { return m_services; }
    bool isScanning() const { return m_scanning; }

    Q_INVOKABLE void startDiscovery();
    Q_INVOKABLE void stopDiscovery();
    Q_INVOKABLE void clearServices();

signals:
    void servicesChanged();
    void scanningChanged();
    void serviceFound(const QString& name, const QString& host, int port);
    void discoveryError(const QString& error);

private slots:
    void onDiscoveryTimeout();

#ifdef Q_OS_ANDROID
    void onServiceFound(const QString& name, const QString& host, int port);
    void onServiceLost(const QString& name);
#endif

private:
    void addService(const QString& name, const QString& host, int port);
    void removeService(const QString& name);

    QVariantList m_services;
    bool m_scanning = false;
    QTimer m_timeoutTimer;

#ifdef Q_OS_ANDROID
    QJniObject m_nsdManager;
    QJniObject m_discoveryListener;
    bool m_androidDiscoveryActive = false;
#endif

    static constexpr int DISCOVERY_TIMEOUT_MS = 10000;  // 10 seconds
};
