#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include "../profile/profile.h"

class MainController;

class VisualizerImporter : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool importing READ isImporting NOTIFY importingChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit VisualizerImporter(MainController* controller, QObject* parent = nullptr);

    bool isImporting() const { return m_importing; }
    QString lastError() const { return m_lastError; }

    // Import profile from a Visualizer shot ID
    Q_INVOKABLE void importFromShotId(const QString& shotId);

    // Import profile from a 4-character share code
    Q_INVOKABLE void importFromShareCode(const QString& shareCode);

    // Extract shot ID from a Visualizer URL
    // Returns empty string if URL is not a valid Visualizer shot URL
    Q_INVOKABLE QString extractShotId(const QString& url) const;

    // Called after duplicate dialog - save with overwrite or new name
    Q_INVOKABLE void saveOverwrite();
    Q_INVOKABLE void saveAsNew();  // Auto-generate unique name with _1, _2 suffix
    Q_INVOKABLE void saveWithNewName(const QString& newTitle);  // User-provided name

signals:
    void importingChanged();
    void lastErrorChanged();
    void importSuccess(const QString& profileTitle);
    void importFailed(const QString& error);
    void duplicateFound(const QString& profileTitle, const QString& existingPath);

private slots:
    void onFetchFinished(QNetworkReply* reply);

private:
    // Convert Visualizer JSON format to our Profile format
    Profile parseVisualizerProfile(const QJsonObject& json);
    ProfileFrame parseVisualizerStep(const QJsonObject& stepJson);

    // Save profile to disk and refresh profile list
    // Returns: 1 = saved, 0 = waiting for user (duplicate), -1 = failed
    int saveImportedProfile(const Profile& profile);

    MainController* m_controller;
    QNetworkAccessManager* m_networkManager;
    bool m_importing = false;
    QString m_lastError;

    // Pending profile for duplicate handling
    Profile m_pendingProfile;
    QString m_pendingPath;

    // Track request type for response handling
    bool m_fetchingFromShareCode = false;

    static constexpr const char* VISUALIZER_PROFILE_API = "https://visualizer.coffee/api/shots/%1/profile.json";
    static constexpr const char* VISUALIZER_SHARED_API = "https://visualizer.coffee/api/shots/shared?code=%1";
};
