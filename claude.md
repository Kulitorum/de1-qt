# Decenza DE1

Qt/C++ cross-platform controller for the Decent Espresso DE1 machine with BLE connectivity.

## Development Environment

- **ADB path**: `/c/Users/Micro/AppData/Local/Android/Sdk/platform-tools/adb.exe`
- **Uninstall app**: `adb uninstall io.github.kulitorum.decenza_de1`
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
│   └── settings.*          # QSettings persistence
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

## Profile System

- **FrameBased mode**: Upload to machine, executes autonomously
- **DirectControl mode**: App sends setpoints frame-by-frame
- Formats: JSON (native), TCL (de1app import)
- Tare happens when frame 0 starts (after machine preheat)

## BLE Protocol Notes

- DE1 Service: `0000A000-...`
- Command queue prevents BLE overflow (50ms between writes)
- Shot samples at ~5Hz during extraction
- Profile upload: header (5 bytes) + frames (8 bytes each)

## Platforms

- Desktop: Windows, macOS, Linux
- Mobile: Android (API 28+), iOS (14.0+)
- Android needs Location permission for BLE scanning
