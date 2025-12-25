#include "flowscale.h"
#include <QDebug>

FlowScale::FlowScale(QObject* parent)
    : ScaleDevice(parent)
{
    // FlowScale is always "connected" since it's virtual
    setConnected(true);
}

void FlowScale::connectToDevice(const QBluetoothDeviceInfo& device) {
    Q_UNUSED(device);
    // No-op - FlowScale doesn't use BLE
}

void FlowScale::tare() {
    qDebug() << "FlowScale: Tare (resetting accumulated weight from" << m_accumulatedWeight << "to 0)";
    m_accumulatedWeight = 0.0;
    setWeight(0.0);
    setFlowRate(0.0);
}

void FlowScale::addFlowSample(double flowRate, double deltaTime) {
    // Integrate flow: weight += flow_rate * time
    // flowRate is in mL/s, deltaTime is in seconds
    // Assumes ~1g/mL density for espresso
    if (deltaTime > 0 && deltaTime < 1.0) {  // Sanity check
        m_accumulatedWeight += flowRate * deltaTime;
        setWeight(m_accumulatedWeight);
        setFlowRate(flowRate);
    }
}

void FlowScale::reset() {
    m_accumulatedWeight = 0.0;
    setWeight(0.0);
    setFlowRate(0.0);
}
