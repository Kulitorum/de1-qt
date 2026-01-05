#pragma once

#include "profileframe.h"
#include "recipeparams.h"
#include <QList>

class Profile;

/**
 * RecipeGenerator converts high-level RecipeParams into DE1 frames.
 *
 * This is the core of the Recipe Editor functionality, providing
 * a D-Flow-style simplified interface. Users edit intuitive parameters
 * like "infuse pressure" and "pour flow", and this class generates
 * the underlying machine frames.
 *
 * Generated frame structure:
 *   Frame 0: Fill      - Gentle pressure to saturate puck
 *   Frame 1: Infuse    - Hold at low pressure (preinfusion/soak)
 *   Frame 2: Ramp      - Quick transition to pour pressure/flow
 *   Frame 3: Pour      - Main extraction phase
 *   Frame 4: Decline   - Optional pressure ramp-down (Londinium style)
 */
class RecipeGenerator {
public:
    /**
     * Generate frames from recipe parameters.
     * @param recipe The recipe parameters to convert
     * @return List of ProfileFrame objects ready for upload
     */
    static QList<ProfileFrame> generateFrames(const RecipeParams& recipe);

    /**
     * Create a complete Profile from recipe parameters.
     * @param recipe The recipe parameters
     * @param title Profile title (default: "Recipe Profile")
     * @return Complete Profile object with frames and metadata
     */
    static Profile createProfile(const RecipeParams& recipe,
                                  const QString& title = "Recipe Profile");

private:
    // Individual frame generators
    static ProfileFrame createFillFrame(const RecipeParams& recipe);
    static ProfileFrame createInfuseFrame(const RecipeParams& recipe);
    static ProfileFrame createRampFrame(const RecipeParams& recipe);
    static ProfileFrame createPourFrame(const RecipeParams& recipe);
    static ProfileFrame createDeclineFrame(const RecipeParams& recipe);
};
