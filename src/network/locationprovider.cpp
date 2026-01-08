#include "locationprovider.h"

#include <QGeoPositionInfo>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>
#include <cmath>

LocationProvider::LocationProvider(QObject* parent)
    : QObject(parent)
    , m_networkManager(new QNetworkAccessManager(this))
{
    // Try to create a position source
    m_source = QGeoPositionInfoSource::createDefaultSource(this);

    if (m_source) {
        connect(m_source, &QGeoPositionInfoSource::positionUpdated,
                this, &LocationProvider::onPositionUpdated);
        connect(m_source, &QGeoPositionInfoSource::errorOccurred,
                this, &LocationProvider::onPositionError);

        qDebug() << "LocationProvider: GPS source available:" << m_source->sourceName();
    } else {
        qDebug() << "LocationProvider: No GPS source available";
    }
}

LocationProvider::~LocationProvider()
{
    if (m_source) {
        m_source->stopUpdates();
    }
}

double LocationProvider::roundedLatitude() const
{
    // Round to 1 decimal place (~11km precision)
    return std::round(m_currentLocation.latitude * 10.0) / 10.0;
}

double LocationProvider::roundedLongitude() const
{
    // Round to 1 decimal place (~11km precision)
    return std::round(m_currentLocation.longitude * 10.0) / 10.0;
}

void LocationProvider::requestUpdate()
{
    if (!m_source) {
        emit locationError("No GPS source available");
        return;
    }

    qDebug() << "LocationProvider: Requesting position update...";
    m_source->requestUpdate(30000);  // 30 second timeout
}

void LocationProvider::onPositionUpdated(const QGeoPositionInfo& info)
{
    if (!info.isValid()) {
        qDebug() << "LocationProvider: Received invalid position";
        return;
    }

    QGeoCoordinate coord = info.coordinate();
    qDebug() << "LocationProvider: Position updated -"
             << "Lat:" << coord.latitude()
             << "Lon:" << coord.longitude();

    m_currentLocation.latitude = coord.latitude();
    m_currentLocation.longitude = coord.longitude();

    // Check if we need to reverse geocode (position changed significantly)
    double latDiff = std::abs(coord.latitude() - m_lastGeocodedLat);
    double lonDiff = std::abs(coord.longitude() - m_lastGeocodedLon);

    if (latDiff > GEOCODE_THRESHOLD_DEGREES || lonDiff > GEOCODE_THRESHOLD_DEGREES
        || m_currentLocation.city.isEmpty()) {
        reverseGeocode(coord.latitude(), coord.longitude());
    } else {
        // Position hasn't changed much, just update coordinates
        m_currentLocation.valid = true;
        emit locationChanged();
    }
}

void LocationProvider::onPositionError(QGeoPositionInfoSource::Error error)
{
    QString errorStr;
    switch (error) {
    case QGeoPositionInfoSource::AccessError:
        errorStr = "Location permission denied";
        break;
    case QGeoPositionInfoSource::ClosedError:
        errorStr = "Location source closed";
        break;
    case QGeoPositionInfoSource::NoError:
        return;
    default:
        errorStr = "Unknown location error";
        break;
    }

    qDebug() << "LocationProvider: Error -" << errorStr;
    emit locationError(errorStr);
}

void LocationProvider::reverseGeocode(double lat, double lon)
{
    // Use Nominatim for reverse geocoding (free, no API key needed)
    // Note: Must respect usage policy - max 1 request/second, include User-Agent
    QString url = QString("https://nominatim.openstreetmap.org/reverse?format=json&lat=%1&lon=%2&zoom=10")
                      .arg(lat, 0, 'f', 6)
                      .arg(lon, 0, 'f', 6);

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, "Decenza_DE1/1.0 (espresso app)");

    qDebug() << "LocationProvider: Reverse geocoding...";

    QNetworkReply* reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onReverseGeocodeFinished(reply);
    });

    // Remember this position to avoid re-geocoding
    m_lastGeocodedLat = lat;
    m_lastGeocodedLon = lon;
}

void LocationProvider::onReverseGeocodeFinished(QNetworkReply* reply)
{
    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        qDebug() << "LocationProvider: Reverse geocode failed -" << reply->errorString();
        // Still mark as valid - we have coordinates, just no city name
        m_currentLocation.valid = true;
        emit locationChanged();
        return;
    }

    QByteArray data = reply->readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    QJsonObject obj = doc.object();

    // Extract city and country from address
    QJsonObject address = obj["address"].toObject();

    // Try different fields for city (Nominatim uses different names depending on location)
    QString city = address["city"].toString();
    if (city.isEmpty()) city = address["town"].toString();
    if (city.isEmpty()) city = address["village"].toString();
    if (city.isEmpty()) city = address["municipality"].toString();
    if (city.isEmpty()) city = address["county"].toString();
    if (city.isEmpty()) city = address["state"].toString();

    QString countryCode = address["country_code"].toString().toUpper();

    qDebug() << "LocationProvider: Geocoded to" << city << countryCode;

    m_currentLocation.city = city;
    m_currentLocation.countryCode = countryCode;
    m_currentLocation.valid = true;

    emit locationChanged();
}
