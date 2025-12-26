#pragma once

#include <QObject>
#include <QTimer>
#include <QVector>
#include <QPointF>
#include <QVariantList>
#include <QtCharts/QLineSeries>

struct PhaseMarker {
    double time;
    QString label;
    int frameNumber;
};

class ShotDataModel : public QObject {
    Q_OBJECT

    Q_PROPERTY(QVariantList phaseMarkers READ phaseMarkersVariant NOTIFY phaseMarkersChanged)
    Q_PROPERTY(double maxTime READ maxTime NOTIFY maxTimeChanged)

public:
    explicit ShotDataModel(QObject* parent = nullptr);
    ~ShotDataModel();

    double maxTime() const { return m_maxTime; }
    QVariantList phaseMarkersVariant() const;

    // Register chart series - C++ takes ownership of updating them
    Q_INVOKABLE void registerSeries(QLineSeries* pressure, QLineSeries* flow, QLineSeries* temperature,
                                     QLineSeries* pressureGoal, QLineSeries* flowGoal, QLineSeries* temperatureGoal,
                                     QLineSeries* weight, QLineSeries* extractionMarker,
                                     const QVariantList& frameMarkers);

    // Data export for visualizer upload
    const QVector<QPointF>& pressureData() const { return m_pressurePoints; }
    const QVector<QPointF>& flowData() const { return m_flowPoints; }
    const QVector<QPointF>& temperatureData() const { return m_temperaturePoints; }
    const QVector<QPointF>& pressureGoalData() const { return m_pressureGoalPoints; }
    const QVector<QPointF>& flowGoalData() const { return m_flowGoalPoints; }
    const QVector<QPointF>& temperatureGoalData() const { return m_temperatureGoalPoints; }
    const QVector<QPointF>& weightData() const { return m_weightPoints; }

public slots:
    void clear();

    // Fast data ingestion - no chart updates, just vector append
    void addSample(double time, double pressure, double flow, double temperature,
                   double pressureGoal, double flowGoal, double temperatureGoal,
                   int frameNumber = -1);
    void addWeightSample(double time, double weight, double flowRate);
    void markExtractionStart(double time);
    void addPhaseMarker(double time, const QString& label, int frameNumber = -1);

signals:
    void cleared();
    void maxTimeChanged();
    void phaseMarkersChanged();

private slots:
    void flushToChart();  // Called by timer - batched update to chart

private:
    // Data storage - fast vector appends
    QVector<QPointF> m_pressurePoints;
    QVector<QPointF> m_flowPoints;
    QVector<QPointF> m_temperaturePoints;
    QVector<QPointF> m_pressureGoalPoints;
    QVector<QPointF> m_flowGoalPoints;
    QVector<QPointF> m_temperatureGoalPoints;
    QVector<QPointF> m_weightPoints;

    // Chart series pointers
    QLineSeries* m_pressureSeries = nullptr;
    QLineSeries* m_flowSeries = nullptr;
    QLineSeries* m_temperatureSeries = nullptr;
    QLineSeries* m_pressureGoalSeries = nullptr;
    QLineSeries* m_flowGoalSeries = nullptr;
    QLineSeries* m_temperatureGoalSeries = nullptr;
    QLineSeries* m_weightSeries = nullptr;
    QLineSeries* m_extractionMarkerSeries = nullptr;
    QList<QLineSeries*> m_frameMarkerSeries;

    // Batched update timer (30fps)
    QTimer* m_flushTimer = nullptr;
    bool m_dirty = false;

    double m_maxTime = 5.0;
    int m_frameMarkerIndex = 0;

    // Phase markers for QML labels
    QList<PhaseMarker> m_phaseMarkers;
    QList<QPair<double, QString>> m_pendingMarkers;  // Pending vertical lines

    static constexpr int FLUSH_INTERVAL_MS = 33;  // ~30fps
    static constexpr int INITIAL_CAPACITY = 600;  // Pre-allocate for 2min at 5Hz
};
