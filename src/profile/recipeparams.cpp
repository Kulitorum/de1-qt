#include "recipeparams.h"

QJsonObject RecipeParams::toJson() const {
    QJsonObject obj;

    // Core
    obj["targetWeight"] = targetWeight;
    obj["temperature"] = temperature;

    // Fill
    obj["fillPressure"] = fillPressure;
    obj["fillTimeout"] = fillTimeout;

    // Infuse
    obj["infusePressure"] = infusePressure;
    obj["infuseTime"] = infuseTime;
    obj["infuseByWeight"] = infuseByWeight;
    obj["infuseWeight"] = infuseWeight;

    // Pour
    obj["pourStyle"] = pourStyle;
    obj["pourPressure"] = pourPressure;
    obj["pourFlow"] = pourFlow;
    obj["flowLimit"] = flowLimit;
    obj["pressureLimit"] = pressureLimit;

    // Decline
    obj["declineEnabled"] = declineEnabled;
    obj["declineTo"] = declineTo;
    obj["declineTime"] = declineTime;

    return obj;
}

RecipeParams RecipeParams::fromJson(const QJsonObject& json) {
    RecipeParams params;

    // Core
    params.targetWeight = json["targetWeight"].toDouble(36.0);
    params.temperature = json["temperature"].toDouble(93.0);

    // Fill
    params.fillPressure = json["fillPressure"].toDouble(2.0);
    params.fillTimeout = json["fillTimeout"].toDouble(25.0);

    // Infuse
    params.infusePressure = json["infusePressure"].toDouble(3.0);
    params.infuseTime = json["infuseTime"].toDouble(20.0);
    params.infuseByWeight = json["infuseByWeight"].toBool(false);
    params.infuseWeight = json["infuseWeight"].toDouble(4.0);

    // Pour
    params.pourStyle = json["pourStyle"].toString("pressure");
    params.pourPressure = json["pourPressure"].toDouble(9.0);
    params.pourFlow = json["pourFlow"].toDouble(2.0);
    params.flowLimit = json["flowLimit"].toDouble(0.0);
    params.pressureLimit = json["pressureLimit"].toDouble(0.0);

    // Decline
    params.declineEnabled = json["declineEnabled"].toBool(false);
    params.declineTo = json["declineTo"].toDouble(6.0);
    params.declineTime = json["declineTime"].toDouble(30.0);

    return params;
}

QVariantMap RecipeParams::toVariantMap() const {
    QVariantMap map;

    // Core
    map["targetWeight"] = targetWeight;
    map["temperature"] = temperature;

    // Fill
    map["fillPressure"] = fillPressure;
    map["fillTimeout"] = fillTimeout;

    // Infuse
    map["infusePressure"] = infusePressure;
    map["infuseTime"] = infuseTime;
    map["infuseByWeight"] = infuseByWeight;
    map["infuseWeight"] = infuseWeight;

    // Pour
    map["pourStyle"] = pourStyle;
    map["pourPressure"] = pourPressure;
    map["pourFlow"] = pourFlow;
    map["flowLimit"] = flowLimit;
    map["pressureLimit"] = pressureLimit;

    // Decline
    map["declineEnabled"] = declineEnabled;
    map["declineTo"] = declineTo;
    map["declineTime"] = declineTime;

    return map;
}

RecipeParams RecipeParams::fromVariantMap(const QVariantMap& map) {
    RecipeParams params;

    // Core
    params.targetWeight = map.value("targetWeight", 36.0).toDouble();
    params.temperature = map.value("temperature", 93.0).toDouble();

    // Fill
    params.fillPressure = map.value("fillPressure", 2.0).toDouble();
    params.fillTimeout = map.value("fillTimeout", 25.0).toDouble();

    // Infuse
    params.infusePressure = map.value("infusePressure", 3.0).toDouble();
    params.infuseTime = map.value("infuseTime", 20.0).toDouble();
    params.infuseByWeight = map.value("infuseByWeight", false).toBool();
    params.infuseWeight = map.value("infuseWeight", 4.0).toDouble();

    // Pour
    params.pourStyle = map.value("pourStyle", "pressure").toString();
    params.pourPressure = map.value("pourPressure", 9.0).toDouble();
    params.pourFlow = map.value("pourFlow", 2.0).toDouble();
    params.flowLimit = map.value("flowLimit", 0.0).toDouble();
    params.pressureLimit = map.value("pressureLimit", 0.0).toDouble();

    // Decline
    params.declineEnabled = map.value("declineEnabled", false).toBool();
    params.declineTo = map.value("declineTo", 6.0).toDouble();
    params.declineTime = map.value("declineTime", 30.0).toDouble();

    return params;
}

// === Presets ===

RecipeParams RecipeParams::classic() {
    RecipeParams params;
    params.targetWeight = 36.0;
    params.temperature = 93.0;

    params.fillPressure = 2.0;
    params.fillTimeout = 25.0;

    params.infusePressure = 3.0;
    params.infuseTime = 8.0;
    params.infuseByWeight = false;

    params.pourStyle = "pressure";
    params.pourPressure = 9.0;
    params.flowLimit = 0.0;

    params.declineEnabled = false;

    return params;
}

RecipeParams RecipeParams::londinium() {
    RecipeParams params;
    params.targetWeight = 36.0;
    params.temperature = 90.0;

    params.fillPressure = 2.0;
    params.fillTimeout = 25.0;

    params.infusePressure = 3.0;
    params.infuseTime = 20.0;
    params.infuseByWeight = false;

    params.pourStyle = "pressure";
    params.pourPressure = 9.0;
    params.flowLimit = 2.5;

    params.declineEnabled = true;
    params.declineTo = 6.0;
    params.declineTime = 30.0;

    return params;
}

RecipeParams RecipeParams::turbo() {
    RecipeParams params;
    params.targetWeight = 36.0;
    params.temperature = 93.0;

    params.fillPressure = 3.0;
    params.fillTimeout = 15.0;

    params.infusePressure = 3.0;
    params.infuseTime = 5.0;
    params.infuseByWeight = false;

    params.pourStyle = "flow";
    params.pourFlow = 4.5;
    params.pressureLimit = 6.0;

    params.declineEnabled = false;

    return params;
}

RecipeParams RecipeParams::blooming() {
    RecipeParams params;
    params.targetWeight = 36.0;
    params.temperature = 92.0;

    params.fillPressure = 2.0;
    params.fillTimeout = 30.0;

    params.infusePressure = 2.0;
    params.infuseTime = 30.0;
    params.infuseByWeight = false;

    params.pourStyle = "pressure";
    params.pourPressure = 6.0;
    params.flowLimit = 2.0;

    params.declineEnabled = false;

    return params;
}
