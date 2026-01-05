# D-Flow and Recipe Editor

This document describes D-Flow profile support and the Recipe Editor feature in Decenza DE1.

## What is D-Flow?

D-Flow is a plugin for the de1app created by Damian Brakel that provides a simplified, coffee-concept-based interface for creating Londinium-style espresso profiles. Instead of editing raw machine frames, users adjust intuitive parameters like "infuse pressure" and "pour flow", and D-Flow automatically generates the underlying DE1 frames.

### Key Insight

**D-Flow is NOT a different profile format** - it's a UI abstraction layer. D-Flow profiles are standard `settings_2c` (advanced) profiles with the `advanced_shot` array fully populated. The innovation is in the editor, not the storage format.

```
┌─────────────────────────────────────────────────────────────┐
│                     D-Flow Architecture                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   User edits "coffee concepts":     Generated frames:        │
│   ┌──────────────────────────┐     ┌────────────────────┐   │
│   │ • Infuse temp: 92°C      │     │ Frame 0: Fill      │   │
│   │ • Infuse pressure: 3 bar │ ──► │ Frame 1: Infuse    │   │
│   │ • Pour flow: 2 mL/s      │     │ Frame 2: Ramp      │   │
│   │ • Pour pressure: 6 bar   │     │ Frame 3: Pour      │   │
│   └──────────────────────────┘     │ Frame 4: Decline   │   │
│                                     └────────────────────┘   │
│                                              │               │
│                                              ▼               │
│                                     ┌────────────────────┐   │
│                                     │ BLE Upload to DE1  │   │
│                                     └────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Profile Types in de1app

The de1app uses `settings_profile_type` to distinguish profile complexity:

| Type | Name | Has advanced_shot? | Description |
|------|------|-------------------|-------------|
| `settings_2a` | Simple Pressure | Empty `{}` | Basic pressure profile, converted at runtime |
| `settings_2b` | Simple Flow | Empty `{}` | Basic flow profile, converted at runtime |
| `settings_2c` | Advanced | Populated | Full frame control (D-Flow outputs this) |
| `settings_2c2` | Advanced + Limiter | Populated | Advanced with limiter UI |

### Current Support Status

| Profile Type | Import | Execute | Edit |
|--------------|--------|---------|------|
| `settings_2c` (Advanced/D-Flow) | Yes | Yes | Yes (frame editor) |
| `settings_2c2` (Advanced + Limiter) | Yes | Yes | Yes (frame editor) |
| `settings_2a` (Simple Pressure) | **No** | N/A | N/A |
| `settings_2b` (Simple Flow) | **No** | N/A | N/A |

Simple profiles (`settings_2a`, `settings_2b`) have empty `advanced_shot` arrays and require conversion functions that we haven't implemented yet.

## D-Flow Parameters (Reference)

These are the user-adjustable parameters in the original D-Flow plugin:

| Parameter | Variable | Default | Range | Description |
|-----------|----------|---------|-------|-------------|
| Dose Weight | `grinder_dose_weight` | 18g | 0-40g | Input coffee weight |
| Fill Temperature | `Dflow_filling_temperature` | 86°C | 80-105°C | Initial fill temp |
| Infuse Pressure | `Dflow_soaking_pressure` | 3.0 bar | 1.2-12 bar | Soak/preinfusion pressure |
| Infuse Time | `Dflow_soaking_seconds` | 20s | 1-127s | Soak duration |
| Infuse Volume | `Dflow_soaking_volume` | 100ml | 50-127ml | Max infuse volume |
| Infuse Weight | `Dflow_soaking_weight` | 4.0g | 0-500g | Weight to exit infuse |
| Pour Temperature | `Dflow_pouring_temperature` | 88°C | 80-105°C | Extraction temp |
| Pour Flow | `Dflow_pouring_flow` | 1.7 mL/s | 0.1-8 mL/s | Extraction flow rate |
| Pour Pressure | `Dflow_pouring_pressure` | 4.8 bar | 1-12 bar | Max pour pressure |
| Target Volume | `final_desired_shot_volume_advanced` | 54ml | 0-1000ml | Stop at volume |
| Target Weight | `final_desired_shot_weight_advanced` | 50g | 0-1000g | Stop at weight |

---

# Recipe Editor

The Recipe Editor is our implementation of a D-Flow-style simplified profile editor. It provides intuitive coffee-concept controls that automatically generate DE1 frames.

## Design Philosophy

1. **Simplicity First** - 12 parameters vs 20+ frame fields
2. **Live Preview** - Graph updates as you adjust
3. **Presets** - One-click common styles
4. **Backward Compatible** - Saves both recipe params AND generated frames
5. **Escape Hatch** - Can convert to advanced frames for fine-tuning

## Recipe Parameters

### Core Parameters

| Parameter | Key | Default | Range | Step | Unit |
|-----------|-----|---------|-------|------|------|
| Stop at Weight | `targetWeight` | 36 | 0-100 | 1 | g |
| Temperature | `temperature` | 93 | 80-100 | 0.5 | °C |

### Fill Phase

| Parameter | Key | Default | Range | Step | Unit |
|-----------|-----|---------|-------|------|------|
| Fill Pressure | `fillPressure` | 2.0 | 1-6 | 0.1 | bar |
| Fill Timeout | `fillTimeout` | 25 | 5-60 | 1 | s |

### Infuse Phase

| Parameter | Key | Default | Range | Step | Unit |
|-----------|-----|---------|-------|------|------|
| Infuse Pressure | `infusePressure` | 3.0 | 1-6 | 0.1 | bar |
| Infuse Time | `infuseTime` | 20 | 0-60 | 1 | s |
| Infuse by Weight | `infuseByWeight` | false | - | - | bool |
| Infuse Weight | `infuseWeight` | 4.0 | 0-20 | 0.5 | g |

### Pour Phase

| Parameter | Key | Default | Range | Step | Unit |
|-----------|-----|---------|-------|------|------|
| Pour Style | `pourStyle` | "pressure" | - | - | enum |
| Pour Pressure | `pourPressure` | 9.0 | 3-12 | 0.1 | bar |
| Pour Flow | `pourFlow` | 2.0 | 0.5-4 | 0.1 | mL/s |
| Flow Limit | `flowLimit` | 0 | 0-6 | 0.1 | mL/s |
| Pressure Limit | `pressureLimit` | 0 | 0-12 | 0.1 | bar |

### Decline Phase

| Parameter | Key | Default | Range | Step | Unit |
|-----------|-----|---------|-------|------|------|
| Enable Decline | `declineEnabled` | false | - | - | bool |
| Decline To | `declineTo` | 6.0 | 1-9 | 0.1 | bar |
| Decline Time | `declineTime` | 30 | 5-60 | 1 | s |

## Presets

| Preset | Description | Key Settings |
|--------|-------------|--------------|
| **Classic** | Traditional 9-bar Italian | 9 bar, no decline, short infuse |
| **Londinium** | Lever machine style | 9→6 bar decline, flow limit 2.5 |
| **Turbo** | Fast high-extraction | Flow mode 4.5 mL/s, short infuse |
| **Blooming** | Modern specialty | Long 30s infuse, 6 bar pour |

## Frame Generation

The Recipe Editor generates 4-5 frames from recipe parameters:

```
Recipe Parameters          Generated Frames
─────────────────          ────────────────
Fill: 2 bar, 25s    ───►   Frame 0: Fill
                           • pump: pressure, pressure: 2.0
                           • exit: pressure_over 2.5 bar
                           • maxFlow: 8.0 mL/s (limiter)

Infuse: 3 bar, 20s  ───►   Frame 1: Infuse
                           • pump: pressure, pressure: 3.0
                           • seconds: 20 (time-based exit)

Pour: 9 bar         ───►   Frame 2: Ramp
                           • pump: pressure, pressure: 9.0
                           • seconds: 4 (quick transition)
                           • transition: fast

                    ───►   Frame 3: Pour
                           • pump: pressure, pressure: 9.0
                           • seconds: 60 (weight stops it)
                           • maxFlow: flowLimit (if set)

Decline: 6 bar, 30s ───►   Frame 4: Decline (if enabled)
                           • pump: pressure, pressure: 6.0
                           • seconds: 30
                           • transition: smooth
```

## JSON Format

Recipe profiles store both the recipe parameters and generated frames:

```json
{
  "title": "My Morning Shot",
  "author": "Recipe Editor",
  "beverage_type": "espresso",
  "profile_type": "settings_2c",
  "target_weight": 36.0,
  "espresso_temperature": 93.0,
  "mode": "frame_based",

  "is_recipe_mode": true,
  "recipe": {
    "temperature": 93.0,
    "targetWeight": 36.0,
    "fillPressure": 2.0,
    "fillTimeout": 25.0,
    "infusePressure": 3.0,
    "infuseTime": 20.0,
    "infuseByWeight": false,
    "infuseWeight": 4.0,
    "pourStyle": "pressure",
    "pourPressure": 9.0,
    "pourFlow": 2.0,
    "flowLimit": 0.0,
    "pressureLimit": 0.0,
    "declineEnabled": true,
    "declineTo": 6.0,
    "declineTime": 30.0
  },

  "steps": [
    { "name": "Fill", "pump": "pressure", "pressure": 2.0, ... },
    { "name": "Infuse", "pump": "pressure", "pressure": 3.0, ... },
    { "name": "Ramp", "pump": "pressure", "pressure": 9.0, ... },
    { "name": "Pour", "pump": "pressure", "pressure": 9.0, ... },
    { "name": "Decline", "pump": "pressure", "pressure": 6.0, ... }
  ]
}
```

This dual storage ensures:
- Recipe profiles work on older versions (they just see the frames)
- Recipe parameters are preserved for re-editing
- Advanced users can convert to pure frame mode

## File Structure

```
src/profile/
├── recipeparams.h          # RecipeParams struct
├── recipeparams.cpp        # JSON serialization
├── recipegenerator.h       # Frame generation interface
├── recipegenerator.cpp     # Frame generation algorithm
├── profile.h               # Extended with recipe support
└── profile.cpp

qml/pages/
├── RecipeEditorPage.qml    # Main recipe editor UI
└── ProfileEditorPage.qml   # Advanced frame editor (existing)

qml/components/
├── RecipeSection.qml       # Collapsible section
├── RecipeRow.qml           # Label + input row
└── PresetButton.qml        # Preset selector
```

## Future Enhancements

1. **Import D-Flow profiles** - Parse D-Flow-specific variables and populate recipe params
2. **Temperature steps** - Add per-phase temperature control
3. **Dose weight integration** - Connect to grinder/scale for ratio calculations
4. **Profile comparison** - Side-by-side recipe vs shot result analysis
5. **Simple profile conversion** - Implement `settings_2a`/`settings_2b` to frame conversion

## References

- [D-Flow GitHub Repository](https://github.com/Damian-AU/D_Flow_Espresso_Profile)
- [D-Flow Blog Post](https://decentespresso.com/blog/dflow_an_easy_editor_for_the_londinium_family_of_espresso_profiles)
- [de1app Profile System](https://github.com/decentespresso/de1app/blob/main/de1plus/profile.tcl)
