import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DecenzaDE1
import "../components"

Page {
    objectName: "idlePage"
    background: Rectangle { color: Theme.backgroundColor }

    Component.onCompleted: root.currentPageTitle = "Idle"
    StackView.onActivated: root.currentPageTitle = "Idle"

    // Track which function's presets are showing
    property string activePresetFunction: ""  // "", "steam", "espresso" (future)

    // Click away to hide presets
    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: activePresetFunction !== ""
        onClicked: activePresetFunction = ""
    }

    // Main content area - centered
    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.scaled(20)

        // Main action buttons row
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 30

            ActionButton {
                text: "Espresso"
                iconSource: "qrc:/icons/espresso.svg"
                enabled: DE1Device.connected
                onClicked: {
                    activePresetFunction = (activePresetFunction === "espresso") ? "" : "espresso"
                }
                onPressAndHold: root.goToProfileSelector()
                onDoubleClicked: root.goToProfileSelector()
            }

            ActionButton {
                text: "Steam"
                iconSource: "qrc:/icons/steam.svg"
                enabled: DE1Device.connected
                onClicked: {
                    activePresetFunction = (activePresetFunction === "steam") ? "" : "steam"
                }
                onPressAndHold: root.goToSteam()
                onDoubleClicked: root.goToSteam()
            }

            ActionButton {
                text: "Hot Water"
                iconSource: "qrc:/icons/water.svg"
                enabled: DE1Device.connected
                onClicked: {
                    activePresetFunction = (activePresetFunction === "hotwater") ? "" : "hotwater"
                }
                onPressAndHold: root.goToHotWater()
                onDoubleClicked: root.goToHotWater()
            }

            ActionButton {
                text: "Flush"
                iconSource: "qrc:/icons/flush.svg"
                enabled: DE1Device.connected
                onClicked: {
                    activePresetFunction = (activePresetFunction === "flush") ? "" : "flush"
                }
                onPressAndHold: root.goToFlush()
                onDoubleClicked: root.goToFlush()
            }
        }

        // Single container for all preset rows - ensures consistent Y position
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: activePresetFunction !== "" ? activePresetRow.implicitHeight : 0
            Layout.preferredWidth: activePresetRow.implicitWidth
            clip: true

            // Get the currently active preset row
            property var activePresetRow: {
                switch (activePresetFunction) {
                    case "steam": return steamPresetRow
                    case "espresso": return espressoPresetRow
                    case "hotwater": return hotWaterPresetRow
                    case "flush": return flushPresetRow
                    default: return steamPresetRow  // fallback
                }
            }

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
            }

            // All preset rows stacked in same position
            PresetPillRow {
                id: steamPresetRow
                anchors.horizontalCenter: parent.horizontalCenter
                visible: activePresetFunction === "steam"
                opacity: visible ? 1.0 : 0.0

                presets: Settings.steamPitcherPresets
                selectedIndex: Settings.selectedSteamPitcher

                onPresetSelected: function(index) {
                    Settings.selectedSteamPitcher = index
                    var preset = Settings.getSteamPitcherPreset(index)
                    if (preset) {
                        Settings.steamTimeout = preset.duration
                        Settings.steamFlow = preset.flow !== undefined ? preset.flow : 150
                    }
                    MainController.applySteamSettings()
                }

                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            PresetPillRow {
                id: espressoPresetRow
                anchors.horizontalCenter: parent.horizontalCenter
                visible: activePresetFunction === "espresso"
                opacity: visible ? 1.0 : 0.0

                presets: Settings.favoriteProfiles
                selectedIndex: Settings.selectedFavoriteProfile

                onPresetSelected: function(index) {
                    Settings.selectedFavoriteProfile = index
                    var preset = Settings.getFavoriteProfile(index)
                    if (preset && preset.filename) {
                        MainController.loadProfile(preset.filename)
                    }
                }

                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            PresetPillRow {
                id: hotWaterPresetRow
                anchors.horizontalCenter: parent.horizontalCenter
                visible: activePresetFunction === "hotwater"
                opacity: visible ? 1.0 : 0.0

                presets: Settings.waterVesselPresets
                selectedIndex: Settings.selectedWaterVessel

                onPresetSelected: function(index) {
                    Settings.selectedWaterVessel = index
                    var preset = Settings.getWaterVesselPreset(index)
                    if (preset) {
                        Settings.hotWaterVolume = preset.volume
                    }
                    MainController.applyHotWaterSettings()
                    // Start hot water immediately after selecting preset
                    if (MachineState.isReady) {
                        DE1Device.startHotWater()
                    }
                }

                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            PresetPillRow {
                id: flushPresetRow
                anchors.horizontalCenter: parent.horizontalCenter
                visible: activePresetFunction === "flush"
                opacity: visible ? 1.0 : 0.0

                presets: Settings.flushPresets
                selectedIndex: Settings.selectedFlushPreset

                onPresetSelected: function(index) {
                    Settings.selectedFlushPreset = index
                    var preset = Settings.getFlushPreset(index)
                    if (preset) {
                        Settings.flushFlow = preset.flow
                        Settings.flushSeconds = preset.seconds
                    }
                    MainController.applyFlushSettings()
                    // Start flush immediately after selecting preset
                    if (MachineState.isReady) {
                        DE1Device.startFlush()
                    }
                }

                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }
    }

    // Top info section
    ColumnLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.standardMargin
        anchors.topMargin: 80  // Leave room for status bar
        spacing: Theme.scaled(20)

        // Status section
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 50

            // Temperature
            Column {
                spacing: 5
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: DE1Device.temperature.toFixed(1) + "°C"
                    color: Theme.temperatureColor
                    font: Theme.valueFont
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Group Temp"
                    color: Theme.textSecondaryColor
                    font: Theme.labelFont
                }
            }

            // Water level
            Column {
                spacing: 5
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: DE1Device.waterLevel.toFixed(0) + "%"
                    color: DE1Device.waterLevel > 20 ? Theme.primaryColor : Theme.warningColor
                    font: Theme.valueFont
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Water Level"
                    color: Theme.textSecondaryColor
                    font: Theme.labelFont
                }
            }

            // Connection status
            ConnectionIndicator {
                machineConnected: DE1Device.connected
                scaleConnected: ScaleDevice && ScaleDevice.connected
            }
        }
    }

    // Bottom bar with Sleep and Settings
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 70
        color: Theme.surfaceColor

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 15
            anchors.rightMargin: 15
            spacing: 15

            // Sleep button
            Button {
                Layout.preferredHeight: 50
                enabled: DE1Device.connected
                onClicked: {
                    // Put scale to sleep and disconnect (if connected)
                    if (ScaleDevice && ScaleDevice.connected) {
                        ScaleDevice.sleep()
                        // Wait 300ms for command to be sent before disconnecting
                        scaleDisconnectTimer.start()
                    }
                    // Put DE1 to sleep
                    DE1Device.goToSleep()
                    // Show screensaver
                    root.goToScreensaver()
                }

                Timer {
                    id: scaleDisconnectTimer
                    interval: 300
                    repeat: false
                    onTriggered: {
                        if (ScaleDevice) {
                            ScaleDevice.disconnectFromScale()
                        }
                    }
                }
                background: Rectangle {
                    implicitWidth: Theme.scaled(120)
                    implicitHeight: 50
                    color: parent.down ? Qt.darker("#555555", 1.2) : "#555555"
                    radius: Theme.scaled(8)
                    opacity: parent.enabled ? 1.0 : 0.5
                }
                contentItem: RowLayout {
                    spacing: 8
                    Image {
                        source: "qrc:/icons/sleep.svg"
                        sourceSize.width: 24
                        sourceSize.height: 24
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: "Sleep"
                        font: Theme.bodyFont
                        color: "white"
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Settings button
            RoundButton {
                Layout.preferredWidth: 50
                Layout.preferredHeight: 50
                icon.source: "qrc:/icons/settings.svg"
                icon.width: 28
                icon.height: 28
                flat: true
                icon.color: Theme.textColor
                onClicked: root.goToSettings()
            }
        }
    }
}
