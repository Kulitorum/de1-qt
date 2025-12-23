import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DE1App
import "../components"

Page {
    objectName: "settingsPage"
    background: Rectangle { color: Theme.backgroundColor }

    Component.onCompleted: root.currentPageTitle = "Settings"

    // Main content area
    Item {
        anchors.top: parent.top
        anchors.topMargin: Theme.scaled(60)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: aboutBox.top
        anchors.bottomMargin: 15
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
                            text: BLEManager.scanning ? "Stop" : "Scan"
                            onClicked: {
                                if (BLEManager.scanning) {
                                    BLEManager.stopScan()
                                } else {
                                    BLEManager.startScan()
                                }
                            }
                        }
                    }

                    Text {
                        text: "Firmware: " + (DE1Device.firmwareVersion || "Unknown")
                        color: Theme.textSecondaryColor
                        visible: DE1Device.connected
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
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
                            text: (ScaleDevice && ScaleDevice.connected) ? "Connected" : "Disconnected"
                            color: (ScaleDevice && ScaleDevice.connected) ? Theme.successColor : Theme.textSecondaryColor
                        }

                        Item { Layout.fillWidth: true }

                        Button {
                            text: BLEManager.scanning ? "Scanning..." : "Scan"
                            enabled: !BLEManager.scanning
                            onClicked: BLEManager.startScan()
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
                        Layout.fillHeight: true
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
                }
            }
        }
    }

    // About - bottom left
    Rectangle {
        id: aboutBox
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: Theme.standardMargin
        anchors.bottomMargin: 85
        width: 200
        height: 80
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
                color: Theme.textSecondaryColor
                font.pixelSize: 12
            }

            Text {
                text: "Built with Qt 6"
                color: Theme.textSecondaryColor
                font.pixelSize: 12
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
