#include "visualizeruploader.h"
#include "../models/shotdatamodel.h"
#include "../core/settings.h"
#include "../profile/profile.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QHttpMultiPart>
#include <QDateTime>
#include <QDebug>
#include <QUuid>

VisualizerUploader::VisualizerUploader(Settings* settings, QObject* parent)
    : QObject(parent)
    , m_settings(settings)
    , m_networkManager(new QNetworkAccessManager(this))
{
}

void VisualizerUploader::uploadShot(ShotDataModel* shotData,
                                     const Profile* profile,
                                     double duration,
                                     double finalWeight,
                                     double doseWeight,
                                     const ShotMetadata& metadata)
{
    if (!shotData) {
        emit uploadFailed("No shot data available");
        return;
    }

    // Check credentials
    QString username = m_settings->value("visualizer/username", "").toString();
    QString password = m_settings->value("visualizer/password", "").toString();

    if (username.isEmpty() || password.isEmpty()) {
        m_lastUploadStatus = "No credentials configured";
        emit lastUploadStatusChanged();
        emit uploadFailed("Visualizer credentials not configured");
        return;
    }

    // Check minimum duration
    double minDuration = m_settings->value("visualizer/minDuration", 6.0).toDouble();
    if (duration < minDuration) {
        m_lastUploadStatus = QString("Shot too short (%1s < %2s)").arg(duration, 0, 'f', 1).arg(minDuration, 0, 'f', 0);
        emit lastUploadStatusChanged();
        qDebug() << "Visualizer: Shot too short, not uploading";
        return;
    }

    m_uploading = true;
    emit uploadingChanged();
    m_lastUploadStatus = "Uploading...";
    emit lastUploadStatusChanged();

    // Build JSON payload
    QByteArray jsonData = buildShotJson(shotData, profile, finalWeight, doseWeight, metadata);

    // Build multipart form data
    QString boundary = QUuid::createUuid().toString(QUuid::WithoutBraces);
    QByteArray multipartData = buildMultipartData(jsonData, boundary);

    // Create request
    QUrl url(VISUALIZER_API_URL);
    QNetworkRequest request(url);
    request.setRawHeader("Authorization", authHeader().toUtf8());
    request.setRawHeader("Content-Type", QString("multipart/form-data; boundary=%1").arg(boundary).toUtf8());

    // Send request
    QNetworkReply* reply = m_networkManager->post(request, multipartData);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onUploadFinished(reply);
    });

    qDebug() << "Visualizer: Uploading shot...";
}

void VisualizerUploader::testConnection()
{
    QString username = m_settings->value("visualizer/username", "").toString();
    QString password = m_settings->value("visualizer/password", "").toString();

    if (username.isEmpty() || password.isEmpty()) {
        emit connectionTestResult(false, "Username or password not set");
        return;
    }

    // Try to access the API to verify credentials
    // We'll use a simple GET to the shots endpoint
    QNetworkRequest request(QUrl("https://visualizer.coffee/api/shots?items=1"));
    request.setRawHeader("Authorization", authHeader().toUtf8());

    QNetworkReply* reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onTestFinished(reply);
    });
}

void VisualizerUploader::onUploadFinished(QNetworkReply* reply)
{
    m_uploading = false;
    emit uploadingChanged();

    if (reply->error() == QNetworkReply::NoError) {
        QByteArray response = reply->readAll();
        QJsonDocument doc = QJsonDocument::fromJson(response);
        QJsonObject obj = doc.object();

        QString shotId = obj["id"].toString();
        if (!shotId.isEmpty()) {
            m_lastShotUrl = QString(VISUALIZER_SHOT_URL) + shotId;
            m_lastUploadStatus = "Upload successful";
            emit lastShotUrlChanged();
            emit lastUploadStatusChanged();
            emit uploadSuccess(shotId, m_lastShotUrl);
            qDebug() << "Visualizer: Upload successful, ID:" << shotId;
        } else {
            m_lastUploadStatus = "Upload completed (no ID returned)";
            emit lastUploadStatusChanged();
            qDebug() << "Visualizer: Upload response:" << response;
        }
    } else {
        int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QString errorMsg;

        if (statusCode == 401) {
            errorMsg = "Invalid credentials";
        } else if (statusCode == 422) {
            QByteArray response = reply->readAll();
            QJsonDocument doc = QJsonDocument::fromJson(response);
            errorMsg = doc.object()["error"].toString();
            if (errorMsg.isEmpty()) {
                errorMsg = "Invalid shot data";
            }
        } else {
            errorMsg = reply->errorString();
        }

        m_lastUploadStatus = "Failed: " + errorMsg;
        emit lastUploadStatusChanged();
        emit uploadFailed(errorMsg);
        qDebug() << "Visualizer: Upload failed -" << errorMsg;
    }

    reply->deleteLater();
}

void VisualizerUploader::onTestFinished(QNetworkReply* reply)
{
    if (reply->error() == QNetworkReply::NoError) {
        emit connectionTestResult(true, "Connection successful!");
    } else {
        int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QString errorMsg;

        if (statusCode == 401) {
            errorMsg = "Invalid username or password";
        } else {
            errorMsg = reply->errorString();
        }

        emit connectionTestResult(false, errorMsg);
    }

    reply->deleteLater();
}

QByteArray VisualizerUploader::buildShotJson(ShotDataModel* shotData,
                                              const Profile* profile,
                                              double finalWeight,
                                              double doseWeight,
                                              const ShotMetadata& metadata)
{
    QJsonObject root;

    // Timestamp (Unix epoch in seconds)
    root["timestamp"] = static_cast<qint64>(QDateTime::currentSecsSinceEpoch());

    // Get data from ShotDataModel
    const auto& pressureData = shotData->pressureData();
    const auto& flowData = shotData->flowData();
    const auto& temperatureData = shotData->temperatureData();
    const auto& pressureGoalData = shotData->pressureGoalData();
    const auto& flowGoalData = shotData->flowGoalData();
    const auto& temperatureGoalData = shotData->temperatureGoalData();
    const auto& weightData = shotData->weightData();

    // Build elapsed time array (from pressure data timestamps)
    QJsonArray elapsed;
    for (const auto& pt : pressureData) {
        elapsed.append(pt.x());
    }
    root["elapsed"] = elapsed;

    // Pressure data
    QJsonObject pressure;
    QJsonArray pressureValues;
    for (const auto& pt : pressureData) {
        pressureValues.append(pt.y());
    }
    pressure["pressure"] = pressureValues;

    // Pressure goal
    if (!pressureGoalData.isEmpty()) {
        QJsonArray pressureGoalValues;
        for (const auto& pt : pressureGoalData) {
            pressureGoalValues.append(pt.y());
        }
        pressure["pressure_goal"] = pressureGoalValues;
    }
    root["pressure"] = pressure;

    // Flow data
    QJsonObject flow;
    QJsonArray flowValues;
    for (const auto& pt : flowData) {
        flowValues.append(pt.y());
    }
    flow["flow"] = flowValues;

    // Flow goal
    if (!flowGoalData.isEmpty()) {
        QJsonArray flowGoalValues;
        for (const auto& pt : flowGoalData) {
            flowGoalValues.append(pt.y());
        }
        flow["flow_goal"] = flowGoalValues;
    }

    // Weight data (scaled back - we divided by 5 for display)
    // This goes in flow.by_weight for flow-based weight estimate
    if (!weightData.isEmpty()) {
        QJsonArray weightValues;
        for (const auto& pt : weightData) {
            weightValues.append(pt.y() * 5.0);  // Undo the /5 scaling
        }
        flow["by_weight"] = weightValues;
    }
    root["flow"] = flow;

    // Temperature data
    QJsonObject temperature;
    QJsonArray basketValues;
    for (const auto& pt : temperatureData) {
        basketValues.append(pt.y());
    }
    temperature["basket"] = basketValues;

    // Temperature goal
    if (!temperatureGoalData.isEmpty()) {
        QJsonArray tempGoalValues;
        for (const auto& pt : temperatureGoalData) {
            tempGoalValues.append(pt.y());
        }
        temperature["goal"] = tempGoalValues;
    }
    root["temperature"] = temperature;

    // Profile info - include full profile data in Visualizer format
    root["profile"] = buildVisualizerProfileJson(profile);

    // Totals - weight should be an array (espresso_weight time series)
    QJsonObject totals;
    if (!weightData.isEmpty()) {
        QJsonArray totalWeightValues;
        for (const auto& pt : weightData) {
            totalWeightValues.append(pt.y() * 5.0);  // Undo the /5 scaling
        }
        totals["weight"] = totalWeightValues;
    }
    if (doseWeight > 0) {
        totals["dose"] = doseWeight;
    }
    root["totals"] = totals;

    // App info
    QJsonObject app;
    app["name"] = "Decenza DE1";
    app["version"] = "1.0.0";
    root["app"] = app;

    // DYE metadata (only include non-empty fields)
    if (!metadata.beanBrand.isEmpty())
        root["bean_brand"] = metadata.beanBrand;
    if (!metadata.beanType.isEmpty())
        root["bean_type"] = metadata.beanType;
    if (!metadata.roastDate.isEmpty())
        root["roast_date"] = metadata.roastDate;
    if (!metadata.roastLevel.isEmpty())
        root["roast_level"] = metadata.roastLevel;
    if (!metadata.grinderModel.isEmpty())
        root["grinder_model"] = metadata.grinderModel;
    if (!metadata.grinderSetting.isEmpty())
        root["grinder_setting"] = metadata.grinderSetting;
    if (metadata.drinkTds > 0)
        root["drink_tds"] = metadata.drinkTds;
    if (metadata.drinkEy > 0)
        root["drink_ey"] = metadata.drinkEy;
    if (metadata.espressoEnjoyment > 0)
        root["espresso_enjoyment"] = metadata.espressoEnjoyment;
    if (!metadata.espressoNotes.isEmpty())
        root["espresso_notes"] = metadata.espressoNotes;
    if (!metadata.barista.isEmpty())
        root["barista"] = metadata.barista;

    return QJsonDocument(root).toJson(QJsonDocument::Compact);
}

QJsonObject VisualizerUploader::buildVisualizerProfileJson(const Profile* profile)
{
    QJsonObject obj;

    if (!profile) {
        obj["title"] = "Unknown";
        return obj;
    }

    // Basic metadata
    obj["title"] = profile->title();
    obj["author"] = profile->author();
    obj["notes"] = profile->notes();
    obj["beverage_type"] = profile->beverageType();

    // Convert steps to Visualizer format
    QJsonArray stepsArray;
    for (const auto& step : profile->steps()) {
        QJsonObject stepObj;

        // Values as strings (Visualizer format)
        stepObj["name"] = step.name;
        stepObj["temperature"] = QString::number(step.temperature, 'f', 2);
        stepObj["sensor"] = step.sensor;
        stepObj["pump"] = step.pump;
        stepObj["transition"] = step.transition;
        stepObj["pressure"] = QString::number(step.pressure, 'f', 2);
        stepObj["flow"] = QString::number(step.flow, 'f', 2);
        stepObj["seconds"] = QString::number(step.seconds, 'f', 2);
        stepObj["volume"] = QString::number(step.volume, 'f', 0);
        stepObj["weight"] = "0";  // Per-step weight not used

        // Exit condition (Visualizer format: {type, value, condition})
        if (step.exitIf && !step.exitType.isEmpty()) {
            QJsonObject exitObj;
            if (step.exitType == "pressure_over") {
                exitObj["type"] = "pressure";
                exitObj["value"] = QString::number(step.exitPressureOver, 'f', 2);
                exitObj["condition"] = "over";
            } else if (step.exitType == "pressure_under") {
                exitObj["type"] = "pressure";
                exitObj["value"] = QString::number(step.exitPressureUnder, 'f', 2);
                exitObj["condition"] = "under";
            } else if (step.exitType == "flow_over") {
                exitObj["type"] = "flow";
                exitObj["value"] = QString::number(step.exitFlowOver, 'f', 2);
                exitObj["condition"] = "over";
            } else if (step.exitType == "flow_under") {
                exitObj["type"] = "flow";
                exitObj["value"] = QString::number(step.exitFlowUnder, 'f', 2);
                exitObj["condition"] = "under";
            }
            if (!exitObj.isEmpty()) {
                stepObj["exit"] = exitObj;
            }
        }

        // Limiter (Visualizer format: {value, range})
        QJsonObject limiterObj;
        limiterObj["value"] = QString::number(step.maxFlowOrPressure, 'f', 1);
        limiterObj["range"] = QString::number(step.maxFlowOrPressureRange, 'f', 1);
        stepObj["limiter"] = limiterObj;

        stepsArray.append(stepObj);
    }
    obj["steps"] = stepsArray;

    // Additional Visualizer metadata
    obj["tank_temperature"] = "0";
    obj["target_weight"] = QString::number(profile->targetWeight(), 'f', 0);
    obj["target_volume"] = QString::number(profile->targetVolume(), 'f', 0);
    obj["target_volume_count_start"] = "2";
    obj["legacy_profile_type"] = profile->profileType();
    obj["type"] = "advanced";
    obj["lang"] = "en";
    obj["hidden"] = "0";
    obj["reference_file"] = profile->title();
    obj["changes_since_last_espresso"] = "";
    obj["version"] = "2";

    return obj;
}

QByteArray VisualizerUploader::buildMultipartData(const QByteArray& jsonData, const QString& boundary)
{
    QByteArray data;

    // File part
    data.append("--" + boundary.toUtf8() + "\r\n");
    data.append("Content-Disposition: form-data; name=\"file\"; filename=\"shot.json\"\r\n");
    data.append("Content-Type: application/json\r\n\r\n");
    data.append(jsonData);
    data.append("\r\n");

    // End boundary
    data.append("--" + boundary.toUtf8() + "--\r\n");

    return data;
}

QString VisualizerUploader::authHeader() const
{
    QString username = m_settings->value("visualizer/username", "").toString();
    QString password = m_settings->value("visualizer/password", "").toString();
    QString credentials = username + ":" + password;
    return "Basic " + credentials.toUtf8().toBase64();
}
