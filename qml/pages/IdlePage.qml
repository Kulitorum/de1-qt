import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DE1App
import "../components"

Page {
    objectName: "idlePage"
    background: Rectangle { color: Theme.backgroundColor }

    Component.onCompleted: root.currentPageTitle = ""

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
                onClicked: root.goToProfileEditor()
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
                onClicked: root.goToHotWater()
            }

            ActionButton {
                text: "Flush"
                iconSource: "qrc:/icons/flush.svg"
                enabled: MachineState.isReady && DE1Device.connected
                onClicked: DE1Device.startFlush()
            }
        }

        // Preset row with animation
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: activePresetFunction === "steam" ? steamPresetRow.implicitHeight : 0
            Layout.preferredWidth: steamPresetRow.implicitWidth
            clip: true

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
            }

            PresetPillRow {
                id: steamPresetRow
                anchors.horizontalCenter: parent.horizontalCenter
                visible: activePresetFunction === "steam"
                opacity: visible ? 1.0 : 0.0

                presets: Settings.steamCupPresets
                selectedIndex: Settings.selectedSteamCup

                onPresetSelected: function(index) {
                    Settings.selectedSteamCup = index
                    var preset = Settings.getSteamCupPreset(index)
                    if (preset) {
                        Settings.steamTimeout = preset.duration
                        Settings.steamFlow = preset.flow !== undefined ? preset.flow : 150
                    }
                    MainController.applySteamSettings()
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
        anchors.topMargin: Theme.scaled(60)  // Leave room for status bar
        spacing: Theme.scaled(20)

        // Profile selector
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Theme.scaled(600)
            Layout.preferredHeight: Theme.scaled(60)
            color: Theme.surfaceColor
            radius: Theme.cardRadius

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.smallMargin
                spacing: Theme.scaled(12)

                Text {
                    text: "Profile:"
                    color: Theme.textSecondaryColor
                    font: Theme.bodyFont
                }

                Text {
                    Layout.fillWidth: true
                    text: MainController.currentProfileName
                    color: Theme.textColor
                    font: Theme.bodyFont
                    elide: Text.ElideRight
                }

                Button {
                    text: "Change"
                    onClicked: profileDialog.open()
                    background: Rectangle {
                        implicitWidth: Theme.scaled(100)
                        implicitHeight: Theme.scaled(40)
                        color: parent.down ? Qt.darker(Theme.primaryColor, 1.2) : Theme.primaryColor
                        radius: Theme.scaled(8)
                    }
                    contentItem: Text {
                        text: parent.text
                        font: Theme.bodyFont
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

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

    // Profile selection dialog
    Dialog {
        id: profileDialog
        title: "Select Profile"
        anchors.centerIn: parent
        width: Theme.scaled(500)
        height: Theme.scaled(500)
        modal: true
        standardButtons: Dialog.Cancel

        ListView {
            anchors.fill: parent
            clip: true
            model: MainController.availableProfiles
            delegate: ItemDelegate {
                width: parent ? parent.width : 0
                height: Theme.scaled(36)
                text: modelData.title
                font: Theme.bodyFont
                highlighted: modelData.title === MainController.currentProfileName
                onClicked: {
                    MainController.loadProfile(modelData.name)
                    profileDialog.close()
                }
            }
        }
    }
}
