#include "accessibilitymanager.h"
#include <QDebug>
#include <QCoreApplication>
#include <QApplication>

AccessibilityManager::AccessibilityManager(QObject *parent)
    : QObject(parent)
    , m_settings("Decenza", "DE1")
{
    loadSettings();
    initTts();
    initTickSound();
}

AccessibilityManager::~AccessibilityManager()
{
    // Don't call m_tts->stop() here - it causes race conditions with Android TTS
    // shutdown() should have been called already via aboutToQuit
    // The QObject parent-child relationship will handle deletion
}

void AccessibilityManager::shutdown()
{
    if (m_shuttingDown) return;
    m_shuttingDown = true;

    qDebug() << "AccessibilityManager shutting down";

    // Disconnect all signals from TTS to prevent callbacks during shutdown
    if (m_tts) {
        disconnect(m_tts, nullptr, this, nullptr);

        // Only try to stop if TTS is in a valid state
        // This minimizes the window for race conditions
        if (m_tts->state() == QTextToSpeech::Speaking ||
            m_tts->state() == QTextToSpeech::Synthesizing) {
            m_tts->stop();
        }

        // Don't delete m_tts - it's a child QObject and will be cleaned up
        // Setting to nullptr prevents any further use
        m_tts = nullptr;
    }

    if (m_tickSound) {
        m_tickSound->stop();
        m_tickSound = nullptr;
    }
}

void AccessibilityManager::loadSettings()
{
    m_enabled = m_settings.value("accessibility/enabled", false).toBool();
    m_ttsEnabled = m_settings.value("accessibility/ttsEnabled", true).toBool();
    m_tickEnabled = m_settings.value("accessibility/tickEnabled", true).toBool();
    m_verbosity = m_settings.value("accessibility/verbosity", Normal).toInt();
}

void AccessibilityManager::saveSettings()
{
    m_settings.setValue("accessibility/enabled", m_enabled);
    m_settings.setValue("accessibility/ttsEnabled", m_ttsEnabled);
    m_settings.setValue("accessibility/tickEnabled", m_tickEnabled);
    m_settings.setValue("accessibility/verbosity", m_verbosity);
    m_settings.sync();
}

void AccessibilityManager::initTts()
{
    // Check available engines first
    auto engines = QTextToSpeech::availableEngines();
    qDebug() << "Available TTS engines:" << engines;

    // On Android, explicitly use the "android" engine which delegates to system TTS
    // This allows eSpeak or any other TTS engine set in Android settings to work
#ifdef Q_OS_ANDROID
    if (engines.contains("android")) {
        m_tts = new QTextToSpeech("android", this);
        qDebug() << "Using Android TTS engine";
    } else {
        m_tts = new QTextToSpeech(this);
    }
#else
    m_tts = new QTextToSpeech(this);
#endif

    connect(m_tts, &QTextToSpeech::stateChanged, this, [this](QTextToSpeech::State state) {
        qDebug() << "TTS state changed:" << state;
        if (state == QTextToSpeech::Error) {
            qWarning() << "TTS error:" << m_tts->errorString();
        } else if (state == QTextToSpeech::Ready) {
            qDebug() << "TTS ready";
        }
    });
}

void AccessibilityManager::initTickSound()
{
    m_tickSound = new QSoundEffect(this);
    m_tickSound->setSource(QUrl("qrc:/sounds/tick.wav"));
    m_tickSound->setVolume(0.5);
}

void AccessibilityManager::setEnabled(bool enabled)
{
    if (m_shuttingDown || m_enabled == enabled) return;
    m_enabled = enabled;
    saveSettings();
    emit enabledChanged();

    qDebug() << "Accessibility" << (m_enabled ? "enabled" : "disabled");

    // Announce the change
    if (m_tts && m_ttsEnabled) {
        m_tts->say(m_enabled ? "Accessibility enabled" : "Accessibility disabled");
    }
}

void AccessibilityManager::setTtsEnabled(bool enabled)
{
    if (m_ttsEnabled == enabled) return;
    m_ttsEnabled = enabled;
    saveSettings();
    emit ttsEnabledChanged();
}

void AccessibilityManager::setTickEnabled(bool enabled)
{
    if (m_tickEnabled == enabled) return;
    m_tickEnabled = enabled;
    saveSettings();
    emit tickEnabledChanged();
}

void AccessibilityManager::setVerbosity(int level)
{
    if (m_verbosity == level) return;
    m_verbosity = qBound(0, level, 2);
    saveSettings();
    emit verbosityChanged();
}

void AccessibilityManager::setLastAnnouncedItem(QObject* item)
{
    if (m_lastAnnouncedItem == item) return;
    m_lastAnnouncedItem = item;
    emit lastAnnouncedItemChanged();
}

void AccessibilityManager::announce(const QString& text, bool interrupt)
{
    if (m_shuttingDown || !m_enabled || !m_ttsEnabled || !m_tts) return;

    if (interrupt) {
        m_tts->stop();
    }

    m_tts->say(text);
    qDebug() << "Accessibility announcement:" << text;
}

void AccessibilityManager::playTick()
{
    if (m_shuttingDown || !m_enabled || !m_tickEnabled) return;

    if (m_tickSound && m_tickSound->status() == QSoundEffect::Ready) {
        m_tickSound->play();
    } else {
        // Fallback to system beep if tick sound not available
        QApplication::beep();
    }
}

void AccessibilityManager::toggleEnabled()
{
    if (m_shuttingDown) return;

    bool wasEnabled = m_enabled;
    setEnabled(!m_enabled);

    // Always announce toggle result
    if (m_tts && m_ttsEnabled) {
        m_tts->stop();
        m_tts->say(m_enabled ? "Accessibility enabled" : "Accessibility disabled");
    }
}
