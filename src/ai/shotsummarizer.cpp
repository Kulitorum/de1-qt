#include "shotsummarizer.h"
#include "../models/shotdatamodel.h"
#include "../profile/profile.h"
#include "../network/visualizeruploader.h"

#include <cmath>
#include <algorithm>

ShotSummarizer::ShotSummarizer(QObject* parent)
    : QObject(parent)
{
}

ShotSummary ShotSummarizer::summarize(const ShotDataModel* shotData,
                                       const Profile* profile,
                                       const ShotMetadata& metadata,
                                       double doseWeight,
                                       double finalWeight) const
{
    ShotSummary summary;

    if (!shotData) {
        return summary;
    }

    // Profile info
    if (profile) {
        summary.profileTitle = profile->title();
        summary.profileType = profile->mode() == Profile::Mode::FrameBased ? "Frame-based" : "Direct Control";
    }

    // Get the data vectors
    const auto& pressureData = shotData->pressureData();
    const auto& flowData = shotData->flowData();
    const auto& tempData = shotData->temperatureData();
    const auto& weightData = shotData->weightData();

    if (pressureData.isEmpty()) {
        return summary;
    }

    // Overall metrics
    summary.totalDuration = pressureData.last().x();
    summary.doseWeight = doseWeight;
    summary.finalWeight = finalWeight;
    summary.ratio = doseWeight > 0 ? finalWeight / doseWeight : 0;

    // DYE metadata
    summary.beanBrand = metadata.beanBrand;
    summary.beanType = metadata.beanType;
    summary.roastDate = metadata.roastDate;
    summary.roastLevel = metadata.roastLevel;
    summary.grinderModel = metadata.grinderModel;
    summary.grinderSetting = metadata.grinderSetting;
    summary.enjoymentScore = metadata.espressoEnjoyment;
    summary.tastingNotes = metadata.espressoNotes;

    // Extraction indicators
    summary.timeToFirstDrip = findTimeToFirstDrip(flowData);
    summary.channelingDetected = detectChanneling(flowData);

    // Temperature stability check
    double tempStdDev = calculateStdDev(tempData, 0, summary.totalDuration);
    summary.temperatureUnstable = tempStdDev > 2.0;

    // Get phase markers from shot data
    QVariantList markers = shotData->phaseMarkersVariant();

    if (markers.isEmpty()) {
        // No markers - create a single "Extraction" phase
        PhaseSummary phase;
        phase.name = "Extraction";
        phase.startTime = 0;
        phase.endTime = summary.totalDuration;
        phase.duration = summary.totalDuration;

        phase.avgPressure = calculateAverage(pressureData, 0, summary.totalDuration);
        phase.maxPressure = calculateMax(pressureData, 0, summary.totalDuration);
        phase.minPressure = calculateMin(pressureData, 0, summary.totalDuration);
        phase.pressureAtStart = findValueAtTime(pressureData, 0);
        phase.pressureAtMiddle = findValueAtTime(pressureData, summary.totalDuration / 2);
        phase.pressureAtEnd = findValueAtTime(pressureData, summary.totalDuration);

        phase.avgFlow = calculateAverage(flowData, 0, summary.totalDuration);
        phase.maxFlow = calculateMax(flowData, 0, summary.totalDuration);
        phase.minFlow = calculateMin(flowData, 0, summary.totalDuration);
        phase.flowAtStart = findValueAtTime(flowData, 0);
        phase.flowAtMiddle = findValueAtTime(flowData, summary.totalDuration / 2);
        phase.flowAtEnd = findValueAtTime(flowData, summary.totalDuration);

        phase.avgTemperature = calculateAverage(tempData, 0, summary.totalDuration);
        phase.tempStability = tempStdDev;

        double startWeight = findValueAtTime(weightData, 0);
        double endWeight = findValueAtTime(weightData, summary.totalDuration);
        phase.weightGained = endWeight - startWeight;

        summary.phases.append(phase);
    } else {
        // Process each phase from markers
        for (int i = 0; i < markers.size(); i++) {
            QVariantMap marker = markers[i].toMap();
            double startTime = marker["time"].toDouble();
            double endTime = (i + 1 < markers.size())
                ? markers[i + 1].toMap()["time"].toDouble()
                : summary.totalDuration;

            if (endTime <= startTime) continue;

            PhaseSummary phase;
            phase.name = marker["label"].toString();
            phase.startTime = startTime;
            phase.endTime = endTime;
            phase.duration = endTime - startTime;

            // Pressure metrics
            phase.avgPressure = calculateAverage(pressureData, startTime, endTime);
            phase.maxPressure = calculateMax(pressureData, startTime, endTime);
            phase.minPressure = calculateMin(pressureData, startTime, endTime);
            phase.pressureAtStart = findValueAtTime(pressureData, startTime);
            phase.pressureAtMiddle = findValueAtTime(pressureData, (startTime + endTime) / 2);
            phase.pressureAtEnd = findValueAtTime(pressureData, endTime);

            // Flow metrics
            phase.avgFlow = calculateAverage(flowData, startTime, endTime);
            phase.maxFlow = calculateMax(flowData, startTime, endTime);
            phase.minFlow = calculateMin(flowData, startTime, endTime);
            phase.flowAtStart = findValueAtTime(flowData, startTime);
            phase.flowAtMiddle = findValueAtTime(flowData, (startTime + endTime) / 2);
            phase.flowAtEnd = findValueAtTime(flowData, endTime);

            // Temperature metrics
            phase.avgTemperature = calculateAverage(tempData, startTime, endTime);
            phase.tempStability = calculateStdDev(tempData, startTime, endTime);

            // Weight gained
            double startWeight = findValueAtTime(weightData, startTime);
            double endWeight = findValueAtTime(weightData, endTime);
            phase.weightGained = endWeight - startWeight;

            // Track preinfusion duration
            QString lowerName = phase.name.toLower();
            if (lowerName.contains("preinfus") || lowerName.contains("pre-infus") ||
                lowerName.contains("bloom") || lowerName.contains("soak")) {
                summary.preinfusionDuration += phase.duration;
            } else {
                summary.mainExtractionDuration += phase.duration;
            }

            summary.phases.append(phase);
        }
    }

    return summary;
}

QString ShotSummarizer::buildUserPrompt(const ShotSummary& summary) const
{
    QString prompt;
    QTextStream out(&prompt);

    out << "## Shot Data Summary\n\n";

    out << "**Profile**: " << (summary.profileTitle.isEmpty() ? "Unknown" : summary.profileTitle) << "\n";
    out << "**Dose**: " << QString::number(summary.doseWeight, 'f', 1) << "g";
    out << " -> **Yield**: " << QString::number(summary.finalWeight, 'f', 1) << "g";
    out << " (1:" << QString::number(summary.ratio, 'f', 1) << " ratio)\n";
    out << "**Total Time**: " << QString::number(summary.totalDuration, 'f', 1) << " seconds\n\n";

    // Bean information
    if (!summary.beanBrand.isEmpty() || !summary.beanType.isEmpty()) {
        out << "### Bean Information\n";
        if (!summary.beanBrand.isEmpty()) out << "- **Brand**: " << summary.beanBrand << "\n";
        if (!summary.beanType.isEmpty()) out << "- **Coffee**: " << summary.beanType << "\n";
        if (!summary.roastLevel.isEmpty()) out << "- **Roast Level**: " << summary.roastLevel << "\n";
        if (!summary.roastDate.isEmpty()) out << "- **Roast Date**: " << summary.roastDate << "\n";
        if (!summary.grinderModel.isEmpty()) out << "- **Grinder**: " << summary.grinderModel;
        if (!summary.grinderSetting.isEmpty()) out << " at setting " << summary.grinderSetting;
        out << "\n\n";
    }

    // Phase breakdown
    out << "### Phase Breakdown\n\n";
    for (const auto& phase : summary.phases) {
        out << "**" << phase.name << "** (" << QString::number(phase.duration, 'f', 1) << "s)\n";
        out << "- Pressure: " << QString::number(phase.avgPressure, 'f', 1) << " bar avg";
        out << " (range: " << QString::number(phase.minPressure, 'f', 1);
        out << " - " << QString::number(phase.maxPressure, 'f', 1) << ")\n";
        out << "- Flow: " << QString::number(phase.avgFlow, 'f', 1) << " mL/s avg";
        out << " (range: " << QString::number(phase.minFlow, 'f', 1);
        out << " - " << QString::number(phase.maxFlow, 'f', 1) << ")\n";
        out << "- Temperature: " << QString::number(phase.avgTemperature, 'f', 1) << " C";
        if (phase.tempStability > 1.0) {
            out << " (unstable: +/-" << QString::number(phase.tempStability, 'f', 1) << " C)";
        }
        out << "\n";
        if (phase.weightGained > 0) {
            out << "- Weight gained: " << QString::number(phase.weightGained, 'f', 1) << "g\n";
        }
        out << "\n";
    }

    // Extraction indicators
    out << "### Extraction Indicators\n";
    out << "- Time to first drip: " << QString::number(summary.timeToFirstDrip, 'f', 1) << "s\n";
    if (summary.preinfusionDuration > 0) {
        out << "- Preinfusion duration: " << QString::number(summary.preinfusionDuration, 'f', 1) << "s\n";
    }
    if (summary.channelingDetected) {
        out << "- **Warning**: Channeling detected (erratic flow)\n";
    }
    if (summary.temperatureUnstable) {
        out << "- **Warning**: Temperature unstable (>2C variation)\n";
    }
    out << "\n";

    // User feedback
    if (summary.enjoymentScore > 0 || !summary.tastingNotes.isEmpty()) {
        out << "### User Feedback\n";
        if (summary.enjoymentScore > 0) {
            out << "- Enjoyment score: " << summary.enjoymentScore << "/100\n";
        }
        if (!summary.tastingNotes.isEmpty()) {
            out << "- Tasting notes: \"" << summary.tastingNotes << "\"\n";
        }
        out << "\n";
    }

    out << "Please analyze this shot and provide ONE specific recommendation to improve it.\n";

    return prompt;
}

QString ShotSummarizer::systemPrompt()
{
    return QStringLiteral(R"(You are an expert espresso dialing assistant for the Decent DE1 espresso machine.
Your role is to analyze shot data and provide actionable recommendations following James Hoffmann's methodology: change only ONE variable at a time.

## Parameters You Can Recommend Adjusting:

1. **Grind Size** - Finer = slower flow, more extraction, can become bitter/astringent. Coarser = faster flow, less extraction, can become sour/thin.

2. **Dose** - More coffee = slower flow, more body, higher strength. Less coffee = faster flow, lighter body.

3. **Yield/Ratio** - Lower ratio (1:1.5-2) = more concentrated, intense. Higher ratio (1:2.5-3) = more diluted, clearer flavors.

4. **Temperature** - Higher = more extraction, more body, risk of bitterness. Lower = less extraction, brighter acidity.

5. **Profile Parameters** - Preinfusion time/pressure, extraction pressure/flow curves. Only suggest profile changes if the data strongly indicates it.

## Diagnosis Framework:

- **Sour/acidic/sharp**: Under-extracted. Try: finer grind, higher temp, longer ratio.
- **Bitter/harsh/astringent**: Over-extracted. Try: coarser grind, lower temp, shorter ratio.
- **Thin/watery**: Low extraction or wrong ratio. Try: finer grind, higher dose, shorter ratio.
- **Uneven extraction** (channeling detected): Improve puck prep, check distribution, or adjust preinfusion.
- **Fast shot** (<20s): Grind finer or increase dose.
- **Slow shot** (>35s): Grind coarser or decrease dose.

## Response Format:

### Diagnosis
[1-2 sentences: What the data and tasting notes tell us]

### Recommendation
**Change**: [One specific parameter]
**From**: [Current value/state if known]
**To**: [Suggested adjustment - be specific: "2-3 clicks finer" not just "finer"]
**Rationale**: [Why this change addresses the issue]

### Expected Result
[What should improve with this change]

### If This Doesn't Work
[Next variable to try if this recommendation doesn't help]

## Important Notes:
- Only suggest ONE change at a time
- Be specific with adjustments (e.g., "2 clicks finer" not "grind finer")
- Consider the roast level - light roasts need finer grinds and higher temps
- If the shot looks good on paper but tastes bad, trust the tasting notes
- Acknowledge when a shot is already good and only needs minor tweaks)");
}

double ShotSummarizer::findValueAtTime(const QVector<QPointF>& data, double time) const
{
    if (data.isEmpty()) return 0;

    // Find closest point
    for (int i = 0; i < data.size(); i++) {
        if (data[i].x() >= time) {
            if (i == 0) return data[i].y();
            // Linear interpolation
            double t = (time - data[i-1].x()) / (data[i].x() - data[i-1].x());
            return data[i-1].y() + t * (data[i].y() - data[i-1].y());
        }
    }
    return data.last().y();
}

double ShotSummarizer::calculateAverage(const QVector<QPointF>& data, double startTime, double endTime) const
{
    if (data.isEmpty()) return 0;

    double sum = 0;
    int count = 0;
    for (const auto& point : data) {
        if (point.x() >= startTime && point.x() <= endTime) {
            sum += point.y();
            count++;
        }
    }
    return count > 0 ? sum / count : 0;
}

double ShotSummarizer::calculateMax(const QVector<QPointF>& data, double startTime, double endTime) const
{
    if (data.isEmpty()) return 0;

    double maxVal = -std::numeric_limits<double>::infinity();
    for (const auto& point : data) {
        if (point.x() >= startTime && point.x() <= endTime) {
            maxVal = std::max(maxVal, point.y());
        }
    }
    return maxVal == -std::numeric_limits<double>::infinity() ? 0 : maxVal;
}

double ShotSummarizer::calculateMin(const QVector<QPointF>& data, double startTime, double endTime) const
{
    if (data.isEmpty()) return 0;

    double minVal = std::numeric_limits<double>::infinity();
    for (const auto& point : data) {
        if (point.x() >= startTime && point.x() <= endTime) {
            minVal = std::min(minVal, point.y());
        }
    }
    return minVal == std::numeric_limits<double>::infinity() ? 0 : minVal;
}

double ShotSummarizer::calculateStdDev(const QVector<QPointF>& data, double startTime, double endTime) const
{
    if (data.isEmpty()) return 0;

    double avg = calculateAverage(data, startTime, endTime);
    double sumSquares = 0;
    int count = 0;

    for (const auto& point : data) {
        if (point.x() >= startTime && point.x() <= endTime) {
            double diff = point.y() - avg;
            sumSquares += diff * diff;
            count++;
        }
    }

    return count > 1 ? std::sqrt(sumSquares / (count - 1)) : 0;
}

double ShotSummarizer::findTimeToFirstDrip(const QVector<QPointF>& flowData) const
{
    const double threshold = 0.5;  // mL/s - when we consider "drip" has started
    for (const auto& point : flowData) {
        if (point.y() >= threshold) {
            return point.x();
        }
    }
    return 0;
}

bool ShotSummarizer::detectChanneling(const QVector<QPointF>& flowData) const
{
    if (flowData.size() < 10) return false;

    // Look for sudden flow spikes (>50% increase in 0.5s)
    for (int i = 5; i < flowData.size() - 5; i++) {
        double prevFlow = flowData[i - 5].y();
        double currFlow = flowData[i].y();

        if (prevFlow > 0.5 && currFlow > prevFlow * 1.5) {
            return true;
        }
    }
    return false;
}
