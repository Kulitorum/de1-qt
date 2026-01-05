#include "recipeanalyzer.h"
#include <QDebug>

bool RecipeAnalyzer::canConvertToRecipe(const Profile& profile) {
    const auto& steps = profile.steps();

    // Need at least 2 frames (Fill + Pour) and at most 5 frames
    if (steps.size() < 2 || steps.size() > 5) {
        return false;
    }

    // Check for basic D-Flow pattern
    // Pattern 1: Fill → Pour (2 frames)
    // Pattern 2: Fill → Infuse → Pour (3 frames)
    // Pattern 3: Fill → Infuse → Ramp → Pour (4 frames)
    // Pattern 4: Fill → Infuse → Pour → Decline (4 frames)
    // Pattern 5: Fill → Infuse → Ramp → Pour → Decline (5 frames)

    // First frame should be a fill frame
    if (!isFillFrame(steps[0])) {
        return false;
    }

    // Last frame (or second-to-last if decline) should be a pour frame
    int pourIndex = steps.size() - 1;
    if (steps.size() >= 2 && isDeclineFrame(steps[pourIndex], &steps[pourIndex - 1])) {
        pourIndex--;
    }

    if (pourIndex < 1) {
        return false;
    }

    if (!isPourFrame(steps[pourIndex])) {
        return false;
    }

    return true;
}

RecipeParams RecipeAnalyzer::extractRecipeParams(const Profile& profile) {
    RecipeParams params;
    const auto& steps = profile.steps();

    if (steps.isEmpty()) {
        return params;
    }

    // Extract target weight and temperature from profile
    params.targetWeight = profile.targetWeight();
    params.temperature = profile.espressoTemperature();

    // Find frame indices
    int fillIndex = 0;
    int infuseIndex = -1;
    int pourIndex = -1;
    int declineIndex = -1;

    // First frame is fill
    if (isFillFrame(steps[0])) {
        fillIndex = 0;
    }

    // Find pour frame (last non-decline frame)
    for (int i = steps.size() - 1; i >= 1; i--) {
        if (i > 0 && isDeclineFrame(steps[i], &steps[i - 1])) {
            declineIndex = i;
            continue;
        }
        if (isPourFrame(steps[i])) {
            pourIndex = i;
            break;
        }
    }

    // Find infuse frame (between fill and pour)
    for (int i = fillIndex + 1; i < pourIndex; i++) {
        if (isInfuseFrame(steps[i])) {
            infuseIndex = i;
            break;
        }
    }

    // Extract fill parameters
    if (fillIndex >= 0 && fillIndex < steps.size()) {
        params.fillPressure = extractFillPressure(steps[fillIndex]);
        params.fillTimeout = steps[fillIndex].seconds;
        // Use fill frame temperature if available
        if (steps[fillIndex].temperature > 0) {
            params.temperature = steps[fillIndex].temperature;
        }
    }

    // Extract infuse parameters
    if (infuseIndex >= 0 && infuseIndex < steps.size()) {
        params.infusePressure = extractInfusePressure(steps[infuseIndex]);
        params.infuseTime = extractInfuseTime(steps[infuseIndex]);
        params.infuseByWeight = false;  // Hard to detect from frames
    }

    // Extract pour parameters
    if (pourIndex >= 0 && pourIndex < steps.size()) {
        const auto& pourFrame = steps[pourIndex];

        if (pourFrame.pump == "flow") {
            params.pourStyle = "flow";
            params.pourFlow = extractPourFlow(pourFrame);
            params.pressureLimit = extractPressureLimit(pourFrame);
        } else {
            params.pourStyle = "pressure";
            params.pourPressure = extractPourPressure(pourFrame);
            params.flowLimit = extractFlowLimit(pourFrame);
        }

        // Use pour frame temperature if higher (main extraction temp)
        if (pourFrame.temperature > params.temperature) {
            params.temperature = pourFrame.temperature;
        }
    }

    // Extract decline parameters
    if (declineIndex >= 0 && declineIndex < steps.size()) {
        params.declineEnabled = true;
        params.declineTo = extractDeclinePressure(steps[declineIndex]);
        params.declineTime = extractDeclineTime(steps[declineIndex]);
    } else {
        params.declineEnabled = false;
    }

    return params;
}

bool RecipeAnalyzer::convertToRecipeMode(Profile& profile) {
    if (!canConvertToRecipe(profile)) {
        qDebug() << "Profile" << profile.title() << "cannot be converted to recipe mode";
        return false;
    }

    RecipeParams params = extractRecipeParams(profile);
    profile.setRecipeMode(true);
    profile.setRecipeParams(params);

    qDebug() << "Converted profile" << profile.title() << "to recipe mode";
    return true;
}

// === Frame Pattern Detection ===

bool RecipeAnalyzer::isFillFrame(const ProfileFrame& frame) {
    // Fill frame characteristics:
    // - Usually named "Fill" or "Filling"
    // - Low pressure (1-6 bar)
    // - Has exit condition (pressure_over) to detect puck saturation
    // - Usually flow or pressure pump mode

    QString nameLower = frame.name.toLower();
    if (nameLower.contains("fill")) {
        return true;
    }

    // Heuristic: first frame with low pressure and pressure_over exit
    if (frame.pressure <= 6.0 && frame.exitIf && frame.exitType == "pressure_over") {
        return true;
    }

    return false;
}

bool RecipeAnalyzer::isInfuseFrame(const ProfileFrame& frame) {
    // Infuse frame characteristics:
    // - Usually named "Infuse", "Infusing", "Soak", "Preinfusion"
    // - Low-medium pressure (2-6 bar)
    // - Pressure pump mode
    // - Often no exit condition (time-based)

    QString nameLower = frame.name.toLower();
    if (nameLower.contains("infus") || nameLower.contains("soak") ||
        nameLower.contains("preinf")) {
        return true;
    }

    // Heuristic: pressure mode, low pressure, time-based
    if (frame.pump == "pressure" && frame.pressure <= 6.0 &&
        frame.seconds > 0 && frame.seconds <= 60) {
        return true;
    }

    return false;
}

bool RecipeAnalyzer::isPourFrame(const ProfileFrame& frame) {
    // Pour frame characteristics:
    // - Usually named "Pour", "Pouring", "Extraction", "Hold"
    // - Higher pressure (6-12 bar) or flow mode
    // - Long duration or until weight stops it

    QString nameLower = frame.name.toLower();
    if (nameLower.contains("pour") || nameLower.contains("extract") ||
        nameLower.contains("hold")) {
        return true;
    }

    // Heuristic: higher pressure or flow mode with long duration
    if ((frame.pressure >= 6.0 || frame.pump == "flow") && frame.seconds >= 30) {
        return true;
    }

    return false;
}

bool RecipeAnalyzer::isDeclineFrame(const ProfileFrame& frame, const ProfileFrame* previousFrame) {
    // Decline frame characteristics:
    // - Usually named "Decline", "Ramp Down"
    // - Smooth transition
    // - Lower pressure than previous frame
    // - Pressure pump mode

    QString nameLower = frame.name.toLower();
    if (nameLower.contains("decline") || nameLower.contains("ramp down")) {
        return true;
    }

    // Heuristic: smooth transition to lower pressure
    if (frame.transition == "smooth" && frame.pump == "pressure" && previousFrame) {
        if (frame.pressure < previousFrame->pressure) {
            return true;
        }
    }

    return false;
}

// === Parameter Extraction ===

double RecipeAnalyzer::extractFillPressure(const ProfileFrame& frame) {
    // For fill frame, use the setpoint pressure
    if (frame.pump == "pressure") {
        return frame.pressure;
    }
    // For flow mode fill, use exit pressure as approximation
    if (frame.exitPressureOver > 0) {
        return frame.exitPressureOver;
    }
    return 2.0;  // Default
}

double RecipeAnalyzer::extractInfusePressure(const ProfileFrame& frame) {
    return frame.pressure > 0 ? frame.pressure : 3.0;
}

double RecipeAnalyzer::extractInfuseTime(const ProfileFrame& frame) {
    return frame.seconds > 0 ? frame.seconds : 20.0;
}

double RecipeAnalyzer::extractPourPressure(const ProfileFrame& frame) {
    return frame.pressure > 0 ? frame.pressure : 9.0;
}

double RecipeAnalyzer::extractPourFlow(const ProfileFrame& frame) {
    return frame.flow > 0 ? frame.flow : 2.0;
}

double RecipeAnalyzer::extractFlowLimit(const ProfileFrame& frame) {
    // Flow limit is stored in maxFlowOrPressure when in pressure mode
    if (frame.pump == "pressure" && frame.maxFlowOrPressure > 0) {
        return frame.maxFlowOrPressure;
    }
    return 0.0;
}

double RecipeAnalyzer::extractPressureLimit(const ProfileFrame& frame) {
    // Pressure limit is stored in maxFlowOrPressure when in flow mode
    if (frame.pump == "flow" && frame.maxFlowOrPressure > 0) {
        return frame.maxFlowOrPressure;
    }
    return 0.0;
}

double RecipeAnalyzer::extractDeclinePressure(const ProfileFrame& frame) {
    return frame.pressure > 0 ? frame.pressure : 6.0;
}

double RecipeAnalyzer::extractDeclineTime(const ProfileFrame& frame) {
    return frame.seconds > 0 ? frame.seconds : 30.0;
}
