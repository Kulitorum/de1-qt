#pragma once

#include <QObject>
#include <QGeoPositionInfoSource>
#include <QNetworkAccessManager>
#include <QTimer>

// Location data with city and coordinates
struct LocationInfo {
    QString city;
    QString countryCode;
    double latitude = 0.0;
    double longitude = 0.0;
    bool valid = false;
};

class LocationProvider : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool available READ isAvailable NOTIFY availableChanged)
    Q_PROPERTY(bool hasLocation READ hasLocation NOTIFY locationChanged)
    Q_PROPERTY(QString city READ city NOTIFY locationChanged)
    Q_PROPERTY(QString countryCode READ countryCode NOTIFY locationChanged)

public:
    explicit LocationProvider(QObject* parent = nullptr);
    ~LocationProvider();

    bool isAvailable() const { return m_source != nullptr; }
    bool hasLocation() const { return m_currentLocation.valid; }
    QString city() const { return m_currentLocation.city; }
    QString countryCode() const { return m_currentLocation.countryCode; }
    LocationInfo currentLocation() const { return m_currentLocation; }

    // Get rounded coordinates for privacy (1 decimal ~11km)
    double roundedLatitude() const;
    double roundedLongitude() const;

    // Request a location update (async)
    Q_INVOKABLE void requestUpdate();

signals:
    void availableChanged();
    void locationChanged();
    void locationError(const QString& error);

private slots:
    void onPositionUpdated(const QGeoPositionInfo& info);
    void onPositionError(QGeoPositionInfoSource::Error error);
    void onReverseGeocodeFinished(QNetworkReply* reply);

private:
    void reverseGeocode(double lat, double lon);

    QGeoPositionInfoSource* m_source = nullptr;
    QNetworkAccessManager* m_networkManager;
    LocationInfo m_currentLocation;

    // Throttle reverse geocoding (don't query if position hasn't changed much)
    double m_lastGeocodedLat = 0.0;
    double m_lastGeocodedLon = 0.0;
    static constexpr double GEOCODE_THRESHOLD_DEGREES = 0.01;  // ~1km
};
