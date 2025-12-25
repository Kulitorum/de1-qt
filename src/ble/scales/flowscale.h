#pragma once

#include "../scaledevice.h"

/**
 * FlowScale - A virtual scale that estimates weight from DE1 flow data.
 *
 * This is used as a fallback when no physical scale is connected.
 * It integrates flow rate over time to estimate weight (assuming ~1g/mL).
 */
class FlowScale : public ScaleDevice {
    Q_OBJECT

public:
    explicit FlowScale(QObject* parent = nullptr);

    // ScaleDevice interface
    void connectToDevice(const QBluetoothDeviceInfo& device) override;
    QString name() const override { return "Flow Scale"; }
    QString type() const override { return "flow"; }

public slots:
    void tare() override;

    // Override from ScaleDevice - receives flow samples from DE1
    void addFlowSample(double flowRate, double deltaTime) override;

    // Reset for new shot
    void reset();

private:
    double m_accumulatedWeight = 0.0;
};
