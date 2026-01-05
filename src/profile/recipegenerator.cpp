#include "recipegenerator.h"
#include "profile.h"

QList<ProfileFrame> RecipeGenerator::generateFrames(const RecipeParams& recipe) {
    QList<ProfileFrame> frames;

    // Frame 0: Fill - gentle pressure to saturate puck
    frames.append(createFillFrame(recipe));

    // Frame 1: Infuse - hold at soak pressure (if time > 0 or weight-based)
    if (recipe.infuseTime > 0 || recipe.infuseByWeight) {
        frames.append(createInfuseFrame(recipe));
    }

    // Frame 2: Ramp - quick transition to pour setpoint
    frames.append(createRampFrame(recipe));

    // Frame 3: Pour - main extraction phase
    frames.append(createPourFrame(recipe));

    // Frame 4: Decline - optional pressure ramp-down (only for pressure mode)
    if (recipe.declineEnabled && recipe.pourStyle == "pressure") {
        frames.append(createDeclineFrame(recipe));
    }

    return frames;
}

Profile RecipeGenerator::createProfile(const RecipeParams& recipe, const QString& title) {
    Profile profile;

    // Metadata
    profile.setTitle(title);
    profile.setAuthor("Recipe Editor");
    profile.setBeverageType("espresso");
    profile.setProfileType("settings_2c");

    // Targets
    profile.setTargetWeight(recipe.targetWeight);
    profile.setTargetVolume(100.0);  // Volume as backup
    profile.setEspressoTemperature(recipe.temperature);

    // Mode
    profile.setMode(Profile::Mode::FrameBased);

    // Generate and set frames
    profile.setSteps(generateFrames(recipe));

    // Calculate preinfuse frame count (fill + infuse)
    int preinfuseCount = 1;  // Fill is always preinfuse
    if (recipe.infuseTime > 0 || recipe.infuseByWeight) {
        preinfuseCount = 2;  // Fill + Infuse
    }
    profile.setPreinfuseFrameCount(preinfuseCount);

    // Store recipe params for re-editing
    profile.setRecipeMode(true);
    profile.setRecipeParams(recipe);

    return profile;
}

ProfileFrame RecipeGenerator::createFillFrame(const RecipeParams& recipe) {
    ProfileFrame frame;

    frame.name = "Fill";
    frame.pump = "pressure";
    frame.pressure = recipe.fillPressure;
    frame.flow = 8.0;  // Fast fill rate (will be limited)
    frame.temperature = recipe.temperature;
    frame.seconds = recipe.fillTimeout;
    frame.transition = "fast";
    frame.sensor = "coffee";
    frame.volume = 0.0;

    // Exit when pressure builds (indicates puck is saturated)
    frame.exitIf = true;
    frame.exitType = "pressure_over";
    frame.exitPressureOver = recipe.fillPressure + 0.5;
    frame.exitPressureUnder = 0.0;
    frame.exitFlowOver = 6.0;
    frame.exitFlowUnder = 0.0;

    // Flow limiter for controlled fill
    frame.maxFlowOrPressure = 8.0;
    frame.maxFlowOrPressureRange = 0.6;

    return frame;
}

ProfileFrame RecipeGenerator::createInfuseFrame(const RecipeParams& recipe) {
    ProfileFrame frame;

    frame.name = "Infuse";
    frame.pump = "pressure";
    frame.pressure = recipe.infusePressure;
    frame.flow = 0.0;
    frame.temperature = recipe.temperature;
    frame.transition = "fast";
    frame.sensor = "coffee";
    frame.volume = 0.0;

    // Duration depends on mode
    if (recipe.infuseByWeight) {
        // Long timeout, actual exit handled by stop-at-weight system
        frame.seconds = 60.0;
    } else {
        frame.seconds = recipe.infuseTime;
    }

    // No exit condition - time-based or global weight system handles exit
    frame.exitIf = false;
    frame.exitType = "";
    frame.exitPressureOver = 0.0;
    frame.exitPressureUnder = 0.0;
    frame.exitFlowOver = 0.0;
    frame.exitFlowUnder = 0.0;

    // No limiter during infuse
    frame.maxFlowOrPressure = 0.0;
    frame.maxFlowOrPressureRange = 0.6;

    return frame;
}

ProfileFrame RecipeGenerator::createRampFrame(const RecipeParams& recipe) {
    ProfileFrame frame;

    frame.name = "Ramp";
    frame.temperature = recipe.temperature;
    frame.seconds = 4.0;  // Quick ramp-up
    frame.transition = "fast";
    frame.sensor = "coffee";
    frame.volume = 0.0;

    if (recipe.pourStyle == "flow") {
        // Flow mode ramp
        frame.pump = "flow";
        frame.flow = recipe.pourFlow;
        frame.pressure = 0.0;

        // Pressure limiter in flow mode
        if (recipe.pressureLimit > 0) {
            frame.maxFlowOrPressure = recipe.pressureLimit;
            frame.maxFlowOrPressureRange = 0.6;
        } else {
            frame.maxFlowOrPressure = 0.0;
        }
    } else {
        // Pressure mode ramp
        frame.pump = "pressure";
        frame.pressure = recipe.pourPressure;
        frame.flow = 0.0;

        // Flow limiter in pressure mode
        if (recipe.flowLimit > 0) {
            frame.maxFlowOrPressure = recipe.flowLimit;
            frame.maxFlowOrPressureRange = 0.6;
        } else {
            frame.maxFlowOrPressure = 0.0;
        }
    }

    // No exit condition - fixed duration
    frame.exitIf = false;
    frame.exitType = "";
    frame.exitPressureOver = 0.0;
    frame.exitPressureUnder = 0.0;
    frame.exitFlowOver = 0.0;
    frame.exitFlowUnder = 0.0;

    return frame;
}

ProfileFrame RecipeGenerator::createPourFrame(const RecipeParams& recipe) {
    ProfileFrame frame;

    frame.name = "Pour";
    frame.temperature = recipe.temperature;
    frame.seconds = 60.0;  // Long duration - weight system stops the shot
    frame.transition = "fast";
    frame.sensor = "coffee";
    frame.volume = 0.0;

    if (recipe.pourStyle == "flow") {
        // Flow mode extraction
        frame.pump = "flow";
        frame.flow = recipe.pourFlow;
        frame.pressure = 0.0;

        // Pressure limiter in flow mode
        if (recipe.pressureLimit > 0) {
            frame.maxFlowOrPressure = recipe.pressureLimit;
            frame.maxFlowOrPressureRange = 0.6;
        } else {
            frame.maxFlowOrPressure = 0.0;
        }
    } else {
        // Pressure mode extraction
        frame.pump = "pressure";
        frame.pressure = recipe.pourPressure;
        frame.flow = 0.0;

        // Flow limiter in pressure mode
        if (recipe.flowLimit > 0) {
            frame.maxFlowOrPressure = recipe.flowLimit;
            frame.maxFlowOrPressureRange = 0.6;
        } else {
            frame.maxFlowOrPressure = 0.0;
        }
    }

    // No exit condition - weight system handles shot termination
    frame.exitIf = false;
    frame.exitType = "";
    frame.exitPressureOver = 0.0;
    frame.exitPressureUnder = 0.0;
    frame.exitFlowOver = 0.0;
    frame.exitFlowUnder = 0.0;

    return frame;
}

ProfileFrame RecipeGenerator::createDeclineFrame(const RecipeParams& recipe) {
    ProfileFrame frame;

    frame.name = "Decline";
    frame.pump = "pressure";
    frame.pressure = recipe.declineTo;
    frame.flow = 0.0;
    frame.temperature = recipe.temperature;
    frame.seconds = recipe.declineTime;
    frame.transition = "smooth";  // Key: smooth ramp creates the decline curve
    frame.sensor = "coffee";
    frame.volume = 0.0;

    // Maintain flow limiter from pour phase
    if (recipe.flowLimit > 0) {
        frame.maxFlowOrPressure = recipe.flowLimit;
        frame.maxFlowOrPressureRange = 0.6;
    } else {
        frame.maxFlowOrPressure = 0.0;
    }

    // No exit condition - time/weight handles termination
    frame.exitIf = false;
    frame.exitType = "";
    frame.exitPressureOver = 0.0;
    frame.exitPressureUnder = 0.0;
    frame.exitFlowOver = 0.0;
    frame.exitFlowUnder = 0.0;

    return frame;
}
