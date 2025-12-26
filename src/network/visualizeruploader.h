#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QVector>
#include <QPointF>

class ShotDataModel;
class Settings;

class VisualizerUploader : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool uploading READ isUploading NOTIFY uploadingChanged)
    Q_PROPERTY(QString lastUploadStatus READ lastUploadStatus NOTIFY lastUploadStatusChanged)
    Q_PROPERTY(QString lastShotUrl READ lastShotUrl NOTIFY lastShotUrlChanged)

public:
    explicit VisualizerUploader(Settings* settings, QObject* parent = nullptr);

    bool isUploading() const { return m_uploading; }
    QString lastUploadStatus() const { return m_lastUploadStatus; }
    QString lastShotUrl() const { return m_lastShotUrl; }

    // Upload shot data to visualizer.coffee
    Q_INVOKABLE void uploadShot(ShotDataModel* shotData,
                                 const QString& profileTitle,
                                 double duration,
                                 double finalWeight = 0,
                                 double doseWeight = 0);

    // Test connection with current credentials
    Q_INVOKABLE void testConnection();

signals:
    void uploadingChanged();
    void lastUploadStatusChanged();
    void lastShotUrlChanged();
    void uploadSuccess(const QString& shotId, const QString& url);
    void uploadFailed(const QString& error);
    void connectionTestResult(bool success, const QString& message);

private slots:
    void onUploadFinished(QNetworkReply* reply);
    void onTestFinished(QNetworkReply* reply);

private:
    QByteArray buildShotJson(ShotDataModel* shotData,
                             const QString& profileTitle,
                             double finalWeight,
                             double doseWeight);

    QByteArray buildMultipartData(const QByteArray& jsonData, const QString& boundary);
    QString authHeader() const;

    Settings* m_settings;
    QNetworkAccessManager* m_networkManager;
    bool m_uploading = false;
    QString m_lastUploadStatus;
    QString m_lastShotUrl;

    static constexpr const char* VISUALIZER_API_URL = "https://visualizer.coffee/api/shots/upload";
    static constexpr const char* VISUALIZER_SHOT_URL = "https://visualizer.coffee/shots/";
};
