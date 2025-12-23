#pragma once

#include <QObject>
#include <QVariantList>
#include <QMap>
#include "../profile/profile.h"

class Settings;
class DE1Device;
class MachineState;
class ShotDataModel;
struct ShotSample;

class MainController : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString currentProfileName READ currentProfileName NOTIFY currentProfileChanged)
    Q_PROPERTY(double targetWeight READ targetWeight WRITE setTargetWeight NOTIFY targetWeightChanged)
    Q_PROPERTY(QVariantList availableProfiles READ availableProfiles NOTIFY profilesChanged)

public:
    explicit MainController(Settings* settings, DE1Device* device,
                           MachineState* machineState, ShotDataModel* shotDataModel,
                           QObject* parent = nullptr);

    QString currentProfileName() const;
    double targetWeight() const;
    void setTargetWeight(double weight);
    QVariantList availableProfiles() const;

    const Profile& currentProfile() const { return m_currentProfile; }

    Q_INVOKABLE QVariantMap getCurrentProfile() const;

public slots:
    void loadProfile(const QString& profileName);
    void refreshProfiles();
    void uploadCurrentProfile();

    void applySteamSettings();
    void applyHotWaterSettings();

    // Real-time steam setting updates
    void setSteamTemperatureImmediate(double temp);
    void setSteamFlowImmediate(int flow);
    void setSteamTimeoutImmediate(int timeout);

    void onEspressoCycleStarted();
    void onShotEnded();

signals:
    void currentProfileChanged();
    void targetWeightChanged();
    void profilesChanged();

private slots:
    void onShotSampleReceived(const ShotSample& sample);
    void onWeightChanged(double weight);

private:
    void loadDefaultProfile();
    QString profilesPath() const;

    Settings* m_settings = nullptr;
    DE1Device* m_device = nullptr;
    MachineState* m_machineState = nullptr;
    ShotDataModel* m_shotDataModel = nullptr;

    Profile m_currentProfile;
    QStringList m_availableProfiles;
    QMap<QString, QString> m_profileTitles;  // filename -> display title
    double m_shotStartTime = 0;
    bool m_extractionStarted = false;
    int m_lastFrameNumber = -1;
};
