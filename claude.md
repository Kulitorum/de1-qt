# Decenza DE1

Qt/C++ cross-platform controller for the Decent Espresso DE1 machine with BLE connectivity.

## Development Environment

- **ADB path**: `/c/Users/Micro/AppData/Local/Android/Sdk/platform-tools/adb.exe`
- **Uninstall app**: `adb uninstall io.github.kulitorum.decenza_de1`
- **WiFi debugging**: `192.168.1.207:5555` (reconnect: `adb connect 192.168.1.207:5555`)
- **Qt version**: 6.8+
- **C++ standard**: C++17

## Project Structure

```
src/
├── ble/                    # Bluetooth LE layer
│   ├── de1device.*         # DE1 machine protocol
│   ├── blemanager.*        # Device discovery
│   ├── scaledevice.*       # Abstract scale interface
│   ├── protocol/           # BLE UUIDs, binary codec
│   └── scales/             # Scale implementations (14+ types)
├── controllers/
│   ├── maincontroller.*    # App logic, profiles, shot processing
│   └── directcontroller.*  # Direct frame control mode
├── machine/
│   └── machinestate.*      # Phase tracking, stop-at-weight
├── profile/
│   ├── profile.*           # Profile container, JSON/TCL formats
│   └── profileframe.*      # Single extraction step
├── models/
│   └── shotdatamodel.*     # Shot data for graphing
├── core/
│   ├── settings.*          # QSettings persistence
│   └── batterymanager.*    # Smart charging control
├── network/
│   ├── visualizeruploader.*  # Upload shots to visualizer.coffee
│   └── visualizerimporter.*  # Import profiles from visualizer.coffee
└── main.cpp                # Entry point, object wiring

qml/
├── pages/                  # EspressoPage, SettingsPage, etc.
├── components/             # ShotGraph, StatusBar, etc.
└── Theme.qml               # Singleton styling
```

## Key Architecture

### Signal/Slot Flow
```
DE1Device (BLE) → signals → MainController → ShotDataModel → QML graphs
ScaleDevice     → signals → MachineState (stop-at-weight)
                          → MainController (graph data)
```

### Scale System
- **ScaleDevice**: Abstract base class
- **FlowScale**: Virtual scale from DE1 flow data (fallback when no physical scale)
- **Physical scales**: DecentScale, AcaiaScale, FelicitaScale, etc. (factory pattern)

### Machine Phases
```
Disconnected → Sleep → Idle → Heating → Ready
Ready → EspressoPreheating → Preinfusion → Pouring → Ending
Also: Steaming, HotWater, Flushing
```

## Conventions

### C++
- Classes: `PascalCase`
- Methods/variables: `camelCase`
- Members: `m_` prefix
- Slots: `onEventName()`
- Use `Q_PROPERTY` with `NOTIFY` for bindable properties

### QML
- Files: `PascalCase.qml`
- IDs/properties: `camelCase`
- Use `Theme.qml` singleton for all styling
- Use `StyledTextField` instead of `TextField` to avoid Material floating label
- `ActionButton` dims icon (50% opacity) and text (secondary color) when disabled
- `native` is a reserved JavaScript keyword - use `nativeName` instead

### QML Gotchas

**Font property conflict**: Cannot use `font: Theme.bodyFont` and then override sub-properties like `font.bold: true`. QML treats this as assigning the property twice.
```qml
// BAD - causes "Property has already been assigned a value" error
Text {
    font: Theme.bodyFont
    font.bold: true  // Error!
}

// GOOD - use individual properties
Text {
    font.family: Theme.bodyFont.family
    font.pixelSize: Theme.bodyFont.pixelSize
    font.bold: true
}
```

## Profile System

- **FrameBased mode**: Upload to machine, executes autonomously
- **DirectControl mode**: App sends setpoints frame-by-frame
- Formats: JSON (native), TCL (de1app import)
- Tare happens when frame 0 starts (after machine preheat)

## Visualizer Integration

### DYE (Describe Your Espresso) Metadata
- **Location**: `qml/pages/ShotMetadataPage.qml`
- **Settings**: `src/core/settings.h` - dye* properties (sticky between shots)
- **Feature toggle**: Settings → Visualizer → "Extended metadata"
- **Auto-show**: Settings → Visualizer → "Edit after shot"
- **Access**: Shot Info button on IdlePage (between Espresso and Steam)

Supported metadata fields:
- `bean_brand`, `bean_type`, `roast_date`, `roast_level`
- `grinder_model`, `grinder_setting`
- `drink_tds`, `drink_ey`, `espresso_enjoyment`
- `espresso_notes`, `barista`

### Profile Import (VisualizerImporter)
- **Location**: `src/network/visualizerimporter.cpp/.h`
- **QML Page**: `qml/pages/VisualizerBrowserPage.qml`
- **Browser**: Uses QtWebEngineQuick (full Chromium) - NOT QtWebView (native WebView looks bad on old Android)
- **API**: `GET https://visualizer.coffee/api/shots/{id}/profile.json`

### Import Flow
1. User browses visualizer.coffee in embedded WebEngineView
2. User navigates to a shot page and clicks "Import Profile"
3. JavaScript searches DOM for `profile.json` link
4. VisualizerImporter fetches profile JSON and converts to native format
5. If duplicate exists, shows overwrite/save-as-new dialog

### Key Implementation Notes
- `QtWebEngineQuick::initialize()` must be called before QApplication in main.cpp
- WebEngineView respects `visible` property (unlike native WebView which needs size=0 hack)
- WebEngineView properly tracks SPA navigation URL changes
- Duplicate handling: `saveOverwrite()`, `saveAsNew()`, `saveWithNewName(newTitle)`
- Keyboard handling for Android: FocusScope + keyboardOffset pattern for text input

### Visualizer Profile Format Conversion
- Visualizer stores values as strings (we convert to doubles)
- Exit conditions: `{type, value, condition}` → `exitType`, `exitPressureOver`, etc.
- Limiter: `{value, range}` → `maxFlowOrPressure`, `maxFlowOrPressureRange`

## BLE Protocol Notes

- DE1 Service: `0000A000-...`
- Command queue prevents BLE overflow (50ms between writes)
- Shot samples at ~5Hz during extraction
- Profile upload: header (5 bytes) + frames (8 bytes each)
- USB charger control: MMR address `0x803854` (1=on, 0=off)
- DE1 has 10-minute timeout that auto-enables charger; must resend command every 60s

## Battery Management

### Smart Charging (BatteryManager)
- **Off**: Charger always on (no control)
- **On** (default): Maintains 55-65% charge
- **Night**: Maintains 90-95% charge
- Commands sent every 60 seconds with `force=true` to overcome DE1 timeout

## Platforms

- Desktop: Windows, macOS, Linux
- Mobile: Android (API 28+), iOS (14.0+)
- Android needs Location permission for BLE scanning

## Android Build & Signing

### Build Process
- **Build tool**: Qt's `androiddeployqt.exe` handles APK creation and signing
- **Keystore**: `C:/CODE/Android APK keystore.jks` (configured in Qt Creator, stored in `CMakeLists.txt.user`)
- **Key alias**: `de1-key`
- **Signing**: Automatic during release build via `--sign` flag

### How Signing & Renaming Works
1. Qt Creator triggers `androiddeployqt` with `--sign` flag
2. Gradle builds unsigned APK (`android-build-Decenza_DE1-release-unsigned.apk`)
3. `gradle.buildFinished` hook in `android/build.gradle` triggers:
   - Finds unsigned APK
   - Signs it with `apksigner` from Android SDK build-tools
   - Outputs as `Decenza_DE1_<version>.apk`
4. `androiddeployqt` also signs the original (creates `-signed.apk`)
5. For AAB: same hook copies and signs with `jarsigner` to `Decenza_DE1-<version>.aab`

### Output Files
- **APK output**: `build/Qt_6_10_1_for_Android_arm64_v8a-Release/android-build-Decenza_DE1/build/outputs/apk/release/`
  - `android-build-Decenza_DE1-release-signed.apk` (original name)
  - `Decenza_DE1_1.0.XXX.apk` (versioned copy)
- **AAB output**: `build/Qt_6_10_1_for_Android_arm64_v8a-Release/android-build-Decenza_DE1/build/outputs/bundle/release/`
  - `Decenza_DE1-1.0.XXX.aab` (versioned, for Play Store)

### Gradle Tasks
- `assembleRelease`: Builds signed APK
- `bundleRelease`: Builds signed AAB (for Play Store)
- Post-build hooks in `android/build.gradle` handle versioned naming

## Publishing Releases

### Prerequisites
- GitHub CLI (`gh`) installed: `winget install GitHub.cli`
- Authenticated: `gh auth login`

### Creating a Release
```bash
gh release create v1.0.XXX \
  --title "Decenza DE1 v1.0.XXX" \
  --notes "Release notes here..." \
  "path/to/Decenza_DE1_1.0.XXX.apk"
```

### Example with Full Path
```bash
cd /c/CODE/de1-qt
gh release create v1.0.XXX \
  --title "Decenza DE1 v1.0.XXX" \
  --notes "## Changes
- Feature 1
- Bug fix 2

## Installation
**Direct APK download:** https://github.com/Kulitorum/de1-qt/releases/download/v1.0.XXX/Decenza_DE1_1.0.XXX.apk

Install on your Android device (allow unknown sources)." \
  "build/Qt_6_10_1_for_Android_arm64_v8a-Release/android-build-Decenza_DE1/build/outputs/apk/release/Decenza_DE1_1.0.XXX.apk"
```

### Notes
- Always include direct APK link in release notes (old browsers can't see Assets section)
- APK files are for direct distribution (sideloading)
- AAB files are only for Google Play Store uploads
- Users cannot install AAB files directly

## QML Navigation System

### Page Navigation (main.qml)
- **StackView**: `pageStack` manages page navigation
- **Auto-navigation**: `MachineState.phaseChanged` signal triggers automatic page transitions
- **Operation pages**: SteamPage, HotWaterPage, FlushPage, EspressoPage
- **Completion flow**: When operations end, show 3-second completion overlay, then navigate to IdlePage

### Phase Change Handler Pattern
```qml
// In main.qml onPhaseChanged handler:
// 1. Check pageStack.busy ONLY for navigation calls, not completion handling
// 2. Navigation TO operation pages: check !pageStack.busy before replace()
// 3. Completion handling (Idle/Ready): NEVER skip - always show completion overlay
```

### Operation Page Structure
Each operation page (Steam, HotWater, Flush) has:
- `objectName`: Must be set for navigation detection (e.g., `objectName: "steamPage"`)
- `isOperating` property: Binds to `MachineState.phase === <phase>`
- **Live view**: Shown during operation (timer, progress, stop button)
- **Settings view**: Shown when idle (presets, configuration)
- **Stop button**: Only visible on headless machines (`DE1Device.isHeadless`)

### Common Bug Pattern
**Problem**: Early `return` in `onPhaseChanged` can skip completion handling
**Solution**: Only check `pageStack.busy` before `replace()` calls, not at handler start

## Versioning

- **Display version** (versionName): Set in `CMakeLists.txt` line 2: `project(Decenza_DE1 VERSION x.y.z)`
- **Version code** (versionCode): Auto-increments in `versioncode.txt` on every build (never reset)
- **version.h**: Auto-generated from `src/version.h.in` with VERSION_STRING macro
- To release a new version: Update VERSION in CMakeLists.txt, build, commit, push

## Git Workflow

- **IMPORTANT**: Always push with tags: `git push && git push --tags`
- Version codes auto-increment and create `build-N` tags
- Tags allow users to reference exact builds by version code
- **Version codes are global** across all platforms (Android, iOS, Desktop) - a build on any platform increments the shared counter in `versioncode.txt`
- **IMPORTANT**: Always include version files in every commit if they've changed: `versioncode.txt`, `android/AndroidManifest.xml`, `installer/version.iss`. Never leave these unstaged.
