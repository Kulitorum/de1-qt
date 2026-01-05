#pragma once

#include <QString>
#include <QJsonObject>
#include <QVariantMap>

/**
 * RecipeParams holds the high-level "coffee concept" parameters
 * for the Recipe Editor. These parameters are converted to DE1
 * frames by RecipeGenerator.
 *
 * This provides a D-Flow-style simplified interface where users
 * edit intuitive values like "infuse pressure" instead of raw
 * machine frames.
 */
struct RecipeParams {
    // === Core Parameters ===
    double targetWeight = 36.0;     // Stop at weight (grams)
    double temperature = 93.0;      // Extraction temperature (Celsius)

    // === Fill Phase ===
    double fillPressure = 2.0;      // Gentle fill pressure (bar)
    double fillTimeout = 25.0;      // Max fill duration (seconds)

    // === Infuse Phase (Preinfusion/Soak) ===
    double infusePressure = 3.0;    // Soak pressure (bar)
    double infuseTime = 20.0;       // Soak duration (seconds)
    bool infuseByWeight = false;    // Exit on weight instead of time
    double infuseWeight = 4.0;      // Weight to exit infuse (grams)

    // === Pour Phase (Extraction) ===
    QString pourStyle = "pressure"; // "pressure" or "flow"
    double pourPressure = 9.0;      // Extraction pressure (bar)
    double pourFlow = 2.0;          // Extraction flow (mL/s) - if flow mode
    double flowLimit = 0.0;         // Max flow in pressure mode (0=disabled)
    double pressureLimit = 0.0;     // Max pressure in flow mode (0=disabled)

    // === Decline Phase (Optional) ===
    bool declineEnabled = false;    // Enable pressure ramp-down
    double declineTo = 6.0;         // Target end pressure (bar)
    double declineTime = 30.0;      // Ramp duration (seconds)

    // === Serialization ===
    QJsonObject toJson() const;
    static RecipeParams fromJson(const QJsonObject& json);

    // === QML Integration ===
    QVariantMap toVariantMap() const;
    static RecipeParams fromVariantMap(const QVariantMap& map);

    // === Presets ===
    static RecipeParams classic();      // Traditional 9-bar Italian
    static RecipeParams londinium();    // Lever machine style with decline
    static RecipeParams turbo();        // Fast high-extraction flow profile
    static RecipeParams blooming();     // Long infuse, lower pressure
};
