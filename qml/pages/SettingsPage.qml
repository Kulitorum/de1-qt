import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DE1App
import "../components"

Page {
    objectName: "settingsPage"
    background: Rectangle { color: Theme.backgroundColor }

    Component.onCompleted: root.currentPageTitle = "Settings"

    // Tap 5x anywhere for simulation mode
    property int simTapCount: 0

    Timer {
        id: simTapResetTimer
        interval: 2000
        onTriggered: simTapCount = 0
    }

    // Simulation mode hint toast
    Rectangle {
        id: simToast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 150
        width: simToastText.implicitWidth + 30
        height: simToastText.implicitHeight + 16
        radius: height / 2
        color: "#333"
        opacity: 0
        z: 100

        Text {
            id: simToastText
            anchors.centerIn: parent
            text: simTapCount >= 5 ?
                  (DE1Device.simulationMode ? "Simulation ON" : "Simulation OFF") :
                  (5 - simTapCount) + " taps to toggle simulation"
            color: "white"
            font.pixelSize: 14
        }

        Behavior on opacity { NumberAnimation { duration: 150 } }

        Timer {
            id: simToastHideTimer
            interval: 1500
            onTriggered: simToast.opacity = 0
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1  // Behind all other controls
        onClicked: {
            simTapCount++
            simTapResetTimer.restart()

            if (simTapCount >= 5) {
                var newState = !DE1Device.simulationMode
                console.log("Simulation mode toggled:", newState ? "ON" : "OFF")
                DE1Device.simulationMode = newState
                if (ScaleDevice) {
                    ScaleDevice.simulationMode = newState
                }
                simToast.opacity = 1
                simToastHideTimer.restart()
                simTapCount = 0
            } else if (simTapCount >= 3) {
                simToast.opacity = 1
                simToastHideTimer.restart()
            }
        }
    }

    // Main content area
    Item {
        id: mainContentArea
        anchors.top: parent.top
        anchors.topMargin: Theme.scaled(60)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 200  // Space for bottom panels + nav bar
        anchors.leftMargin: Theme.standardMargin
        anchors.rightMargin: Theme.standardMargin

        // Machine and Scale side by side
        RowLayout {
            anchors.fill: parent
            spacing: 15

            // Machine Connection
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.surfaceColor
                radius: Theme.cardRadius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 10

                    Text {
                        text: "Machine"
                        color: Theme.textColor
                        font.pixelSize: 16
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Status:"
                            color: Theme.textSecondaryColor
                        }

                        Text {
                            text: DE1Device.connected ? "Connected" : "Disconnected"
                            color: DE1Device.connected ? Theme.successColor : Theme.errorColor
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: BLEManager.scanning ? "Stop Scan" : "Scan for DE1"
                            onClicked: {
                                console.log("DE1 scan button clicked! scanning=" + BLEManager.scanning)
                                if (BLEManager.scanning) {
                                    BLEManager.stopScan()
                                } else {
                                    BLEManager.startScan()
                                }
                            }
                            onPressed: console.log("DE1 button PRESSED")
                            onReleased: console.log("DE1 button RELEASED")
                        }
                    }

                    Text {
                        text: "Firmware: " + (DE1Device.firmwareVersion || "Unknown")
                        color: Theme.textSecondaryColor
                        visible: DE1Device.connected
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        clip: true
                        model: BLEManager.discoveredDevices

                        delegate: ItemDelegate {
                            width: ListView.view.width
                            contentItem: Text {
                                text: modelData.name + " (" + modelData.address + ")"
                                color: Theme.textColor
                            }
                            background: Rectangle {
                                color: parent.hovered ? Theme.accentColor : "transparent"
                                radius: 4
                            }
                            onClicked: DE1Device.connectToDevice(modelData.address)
                        }

                        Label {
                            anchors.centerIn: parent
                            text: "No devices found"
                            visible: parent.count === 0
                            color: Theme.textSecondaryColor
                        }
                    }

                    // DE1 scan log
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Qt.darker(Theme.surfaceColor, 1.2)
                        radius: 4

                        ScrollView {
                            id: de1LogScroll
                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true

                            TextArea {
                                id: de1LogText
                                readOnly: true
                                color: Theme.textSecondaryColor
                                font.pixelSize: 11
                                font.family: "monospace"
                                wrapMode: Text.Wrap
                                background: null
                                text: ""
                            }
                        }

                        Connections {
                            target: BLEManager
                            function onDe1LogMessage(message) {
                                de1LogText.text += message + "\n"
                                de1LogScroll.ScrollBar.vertical.position = 1.0 - de1LogScroll.ScrollBar.vertical.size
                            }
                        }
                    }
                }
            }

            // Scale Connection
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.surfaceColor
                radius: Theme.cardRadius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 10

                    Text {
                        text: "Scale"
                        color: Theme.textColor
                        font.pixelSize: 16
                        font.bold: true
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Status:"
                            color: Theme.textSecondaryColor
                        }

                        Text {
                            text: (ScaleDevice && ScaleDevice.connected) ? "Connected" :
                                  BLEManager.scaleConnectionFailed ? "Not found" : "Disconnected"
                            color: (ScaleDevice && ScaleDevice.connected) ? Theme.successColor :
                                   BLEManager.scaleConnectionFailed ? Theme.errorColor : Theme.textSecondaryColor
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: BLEManager.scanning ? "Scanning..." : "Scan for Scales"
                            enabled: !BLEManager.scanning
                            onClicked: BLEManager.scanForScales()
                        }
                    }

                    // Saved scale info
                    RowLayout {
                        Layout.fillWidth: true
                        visible: BLEManager.hasSavedScale

                        Text {
                            text: "Saved scale:"
                            color: Theme.textSecondaryColor
                        }

                        Text {
                            text: Settings.scaleType || "Unknown"
                            color: Theme.textColor
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: "Forget"
                            onClicked: {
                                Settings.setScaleAddress("")
                                Settings.setScaleType("")
                                BLEManager.clearSavedScale()
                            }
                        }
                    }

                    // Show weight when connected
                    RowLayout {
                        Layout.fillWidth: true
                        visible: ScaleDevice && ScaleDevice.connected

                        Text {
                            text: "Weight:"
                            color: Theme.textSecondaryColor
                        }

                        Text {
                            text: ScaleDevice ? ScaleDevice.weight.toFixed(1) + " g" : "0.0 g"
                            color: Theme.textColor
                            font: Theme.bodyFont
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: "Tare"
                            onClicked: {
                                if (ScaleDevice) ScaleDevice.tare()
                            }
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 60
                        clip: true
                        visible: !ScaleDevice || !ScaleDevice.connected
                        model: BLEManager.discoveredScales

                        delegate: ItemDelegate {
                            width: ListView.view.width
                            contentItem: RowLayout {
                                Text {
                                    text: modelData.name
                                    color: Theme.textColor
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: modelData.type
                                    color: Theme.textSecondaryColor
                                    font.pixelSize: 12
                                }
                            }
                            background: Rectangle {
                                color: parent.hovered ? Theme.accentColor : "transparent"
                                radius: 4
                            }
                            onClicked: {
                                console.log("Connect to scale:", modelData.name, modelData.type)
                            }
                        }

                        Label {
                            anchors.centerIn: parent
                            text: "No scales found"
                            visible: parent.count === 0
                            color: Theme.textSecondaryColor
                        }
                    }

                    // Scale scan log
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Qt.darker(Theme.surfaceColor, 1.2)
                        radius: 4

                        ScrollView {
                            id: scaleLogScroll
                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true

                            TextArea {
                                id: scaleLogText
                                readOnly: true
                                color: Theme.textSecondaryColor
                                font.pixelSize: 11
                                font.family: "monospace"
                                wrapMode: Text.Wrap
                                background: null
                                text: ""
                            }
                        }

                        Connections {
                            target: BLEManager
                            function onScaleLogMessage(message) {
                                scaleLogText.text += message + "\n"
                                scaleLogScroll.ScrollBar.vertical.position = 1.0 - scaleLogScroll.ScrollBar.vertical.size
                            }
                        }
                    }
                }
            }
        }
    }

    // Bottom panels row
    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.standardMargin
        anchors.rightMargin: Theme.standardMargin
        anchors.bottomMargin: 85
        spacing: 15
        height: 100

        // About - bottom left
        Rectangle {
            id: aboutBox
            Layout.preferredWidth: 140
            Layout.fillHeight: true
            color: Theme.surfaceColor
            radius: Theme.cardRadius

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 2

                Text {
                    text: "DE1 Controller"
                    color: Theme.textColor
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    text: "Version 1.0.0"
                    color: DE1Device.simulationMode ? Theme.primaryColor : Theme.textSecondaryColor
                    font.pixelSize: 12
                }

                Text {
                    text: DE1Device.simulationMode ? "SIM MODE" : "Built with Qt 6"
                    color: DE1Device.simulationMode ? Theme.primaryColor : Theme.textSecondaryColor
                    font.pixelSize: 12
                    font.bold: DE1Device.simulationMode
                }
            }
        }

        // Auto-sleep settings
        Rectangle {
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            color: Theme.surfaceColor
            radius: Theme.cardRadius

            // Map slider position (0-8) to minutes (0=never, then 15,30,45,60,90,120,180,240)
            property var sleepValues: [0, 15, 30, 45, 60, 90, 120, 180, 240]
            property int currentMinutes: Settings.value("autoSleepMinutes", 0)

            function minutesToIndex(mins) {
                for (var i = 0; i < sleepValues.length; i++) {
                    if (sleepValues[i] === mins) return i
                }
                return 0  // Default to "Never"
            }

            function formatTime(mins) {
                if (mins === 0) return "Never"
                if (mins < 60) return mins + " min"
                var hours = mins / 60
                if (hours === 1) return "1 hour"
                return hours + " hours"
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4

                Text {
                    text: "Auto-Sleep"
                    color: Theme.textColor
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    text: parent.parent.formatTime(parent.parent.currentMinutes)
                    color: Theme.primaryColor
                    font.pixelSize: 16
                    font.bold: true
                }

                Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: 8
                    stepSize: 1
                    value: parent.parent.minutesToIndex(parent.parent.currentMinutes)
                    onMoved: {
                        var mins = parent.parent.sleepValues[Math.round(value)]
                        parent.parent.currentMinutes = mins
                        Settings.setValue("autoSleepMinutes", mins)
                    }
                }
            }
        }

        // Screensaver settings
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surfaceColor
            radius: Theme.cardRadius

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 20

                ColumnLayout {
                    spacing: 4

                    Text {
                        text: "Screensaver"
                        color: Theme.textColor
                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        text: ScreensaverManager.itemCount + " videos" +
                              (ScreensaverManager.isDownloading ? " (downloading...)" : "")
                        color: Theme.textSecondaryColor
                        font.pixelSize: 12
                    }

                    Text {
                        text: "Cache: " + (ScreensaverManager.cacheUsedBytes / 1024 / 1024).toFixed(0) + " MB / " +
                              (ScreensaverManager.maxCacheBytes / 1024 / 1024 / 1024).toFixed(1) + " GB"
                        color: Theme.textSecondaryColor
                        font.pixelSize: 12
                    }
                }

                Item { Layout.fillWidth: true }

                ColumnLayout {
                    spacing: 8

                    RowLayout {
                        spacing: 10

                        Text {
                            text: "Enabled"
                            color: Theme.textColor
                            font.pixelSize: 12
                        }

                        Switch {
                            checked: ScreensaverManager.enabled
                            onCheckedChanged: ScreensaverManager.enabled = checked
                        }
                    }

                    RowLayout {
                        spacing: 10

                        Text {
                            text: "Cache"
                            color: Theme.textColor
                            font.pixelSize: 12
                        }

                        Switch {
                            checked: ScreensaverManager.cacheEnabled
                            onCheckedChanged: ScreensaverManager.cacheEnabled = checked
                        }
                    }
                }

                ColumnLayout {
                    spacing: 8

                    Button {
                        text: "Refresh"
                        onClicked: ScreensaverManager.refreshCatalog()
                        enabled: !ScreensaverManager.isRefreshing
                    }

                    Button {
                        text: "Clear Cache"
                        onClicked: ScreensaverManager.clearCache()
                    }
                }
            }
        }
    }

    // Bottom bar with back button
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 70
        color: Theme.surfaceColor

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 20
            spacing: 15

            // Back button
            RoundButton {
                Layout.preferredWidth: 50
                Layout.preferredHeight: 50
                icon.source: "qrc:/icons/back.svg"
                icon.width: 28
                icon.height: 28
                flat: true
                icon.color: Theme.textColor
                onClicked: root.goToIdle()
            }

            Item { Layout.fillWidth: true }
        }
    }
}
