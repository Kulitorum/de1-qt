#include "scaledevice.h"
#include <QDateTime>

ScaleDevice::ScaleDevice(QObject* parent)
    : QObject(parent)
{
}

ScaleDevice::~ScaleDevice() {
    disconnectFromScale();
}

bool ScaleDevice::isConnected() const {
    // Simulation mode always reports connected
    if (m_simulationMode) {
        return true;
    }
    return m_connected;
}

void ScaleDevice::setSimulationMode(bool enabled) {
    if (m_simulationMode == enabled) {
        return;
    }
    m_simulationMode = enabled;
    qDebug() << "ScaleDevice: Simulation mode" << (enabled ? "ENABLED" : "DISABLED");

    if (enabled) {
        // Set some default simulated state
        m_weight = 0.0;
        m_flowRate = 0.0;
        m_batteryLevel = 85;
        emit weightChanged(m_weight);
        emit flowRateChanged(m_flowRate);
        emit batteryLevelChanged(m_batteryLevel);
    }

    emit simulationModeChanged();
    emit connectedChanged();
}

void ScaleDevice::disconnectFromScale() {
    if (m_service) {
        delete m_service;
        m_service = nullptr;
    }

    if (m_controller) {
        m_controller->disconnectFromDevice();
        delete m_controller;
        m_controller = nullptr;
    }

    setConnected(false);
}

void ScaleDevice::setConnected(bool connected) {
    if (m_connected != connected) {
        m_connected = connected;
        emit connectedChanged();
    }
}

void ScaleDevice::setWeight(double weight) {
    if (m_weight != weight) {
        calculateFlowRate(weight);
        m_weight = weight;
        emit weightChanged(weight);
    }
}

void ScaleDevice::setFlowRate(double rate) {
    if (m_flowRate != rate) {
        m_flowRate = rate;
        emit flowRateChanged(rate);
    }
}

void ScaleDevice::setBatteryLevel(int level) {
    if (m_batteryLevel != level) {
        m_batteryLevel = level;
        emit batteryLevelChanged(level);
    }
}

void ScaleDevice::calculateFlowRate(double newWeight) {
    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();

    if (m_prevTimestamp > 0) {
        double timeDelta = (currentTime - m_prevTimestamp) / 1000.0;
        if (timeDelta > 0.01 && timeDelta < 1.0) {  // Valid time range
            double instantRate = (newWeight - m_prevWeight) / timeDelta;

            // Add to history for smoothing
            m_flowHistory.append(instantRate);
            if (m_flowHistory.size() > FLOW_HISTORY_SIZE) {
                m_flowHistory.removeFirst();
            }

            // Calculate average flow rate
            double sum = 0;
            for (double rate : m_flowHistory) {
                sum += rate;
            }
            setFlowRate(sum / m_flowHistory.size());
        }
    }

    m_prevWeight = newWeight;
    m_prevTimestamp = currentTime;
}
