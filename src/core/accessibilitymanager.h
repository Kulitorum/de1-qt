#ifndef ACCESSIBILITYMANAGER_H
#define ACCESSIBILITYMANAGER_H

#include <QObject>
#include <QPointer>
#include <QTextToSpeech>
#include <QSoundEffect>
#include <QSettings>

class AccessibilityManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool ttsEnabled READ ttsEnabled WRITE setTtsEnabled NOTIFY ttsEnabledChanged)
    Q_PROPERTY(bool tickEnabled READ tickEnabled WRITE setTickEnabled NOTIFY tickEnabledChanged)
    Q_PROPERTY(int verbosity READ verbosity WRITE setVerbosity NOTIFY verbosityChanged)
    Q_PROPERTY(QObject* lastAnnouncedItem READ lastAnnouncedItem WRITE setLastAnnouncedItem NOTIFY lastAnnouncedItemChanged)

public:
    explicit AccessibilityManager(QObject *parent = nullptr);
    ~AccessibilityManager();

    // Verbosity levels
    enum Verbosity {
        Minimal = 0,   // Start/stop + errors only
        Normal = 1,    // + milestones (pressure reached, weight reached)
        Verbose = 2    // + periodic status updates
    };
    Q_ENUM(Verbosity)

    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);

    bool ttsEnabled() const { return m_ttsEnabled; }
    void setTtsEnabled(bool enabled);

    bool tickEnabled() const { return m_tickEnabled; }
    void setTickEnabled(bool enabled);

    int verbosity() const { return m_verbosity; }
    void setVerbosity(int level);

    QObject* lastAnnouncedItem() const { return m_lastAnnouncedItem; }
    void setLastAnnouncedItem(QObject* item);

    // Called from QML
    Q_INVOKABLE void announce(const QString& text, bool interrupt = false);
    Q_INVOKABLE void playTick();
    Q_INVOKABLE void toggleEnabled();  // For backdoor gesture

    // Must be called before app shutdown to avoid TTS race conditions
    void shutdown();

signals:
    void enabledChanged();
    void ttsEnabledChanged();
    void tickEnabledChanged();
    void verbosityChanged();
    void lastAnnouncedItemChanged();

private:
    void loadSettings();
    void saveSettings();
    void initTts();
    void initTickSound();

    bool m_enabled = false;
    bool m_ttsEnabled = true;
    bool m_tickEnabled = true;
    int m_verbosity = Normal;
    QPointer<QObject> m_lastAnnouncedItem;
    bool m_shuttingDown = false;

    QTextToSpeech* m_tts = nullptr;
    QSoundEffect* m_tickSound = nullptr;
    QSettings m_settings;
};

#endif // ACCESSIBILITYMANAGER_H
