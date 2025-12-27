import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DecenzaDE1
import "../components"

Page {
    id: espressoPage
    objectName: "espressoPage"
    background: Rectangle { color: Theme.backgroundColor }

    // Local weight property - updated directly in signal handler for immediate display
    property real currentWeight: 0.0

    Component.onCompleted: root.currentPageTitle = MainController.currentProfileName
    StackView.onActivated: root.currentPageTitle = MainController.currentProfileName

    // Force immediate weight update on signal (bypasses lazy binding evaluation)
    Connections {
        target: MachineState
        function onScaleWeightChanged() {
            espressoPage.currentWeight = MachineState.scaleWeight
        }
    }

    // Full-screen shot graph
    ShotGraph {
        id: shotGraph
        anchors.fill: parent
        anchors.topMargin: Theme.scaled(50)
        anchors.bottomMargin: Theme.scaled(100)
    }

    // Status indicator for preheating
    Rectangle {
        id: statusBanner
        anchors.top: parent.top
        anchors.topMargin: Theme.pageTopMargin + Theme.scaled(20)
        anchors.horizontalCenter: parent.horizontalCenter
        width: statusText.width + Theme.spacingLarge * 2
        height: Theme.scaled(36)
        radius: Theme.scaled(18)
        color: MachineState.phase === MachineStateType.Phase.EspressoPreheating ?
               Theme.accentColor : "transparent"
        visible: MachineState.phase === MachineStateType.Phase.EspressoPreheating

        Text {
            id: statusText
            anchors.centerIn: parent
            text: "PREHEATING..."
            color: Theme.textColor
            font: Theme.bodyFont
        }
    }

    // Bottom info bar with live values
    Rectangle {
        id: infoBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Theme.scaled(100)
        color: Qt.darker(Theme.surfaceColor, 1.3)

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingMedium
            spacing: Theme.spacingMedium

            // Back button (large hitbox, icon aligned left)
            RoundButton {
                Layout.preferredWidth: Theme.scaled(80)
                Layout.preferredHeight: Theme.bottomBarHeight
                flat: true
                icon.source: "qrc:/icons/back.svg"
                icon.width: Theme.scaled(28)
                icon.height: Theme.scaled(28)
                icon.color: Theme.textColor
                display: AbstractButton.IconOnly
                leftPadding: 0
                rightPadding: Theme.scaled(52)
                onClicked: {
                    DE1Device.stopOperation()
                    root.goToIdle()
                }
            }

            // Timer
            ColumnLayout {
                Layout.preferredWidth: Theme.scaled(100)
                spacing: Theme.scaled(2)

                Text {
                    text: MachineState.shotTime.toFixed(1) + "s"
                    color: Theme.textColor
                    font.pixelSize: Theme.scaled(36)
                    font.weight: Font.Bold
                }
                Text {
                    text: "Time"
                    color: Theme.textSecondaryColor
                    font: Theme.captionFont
                }
            }

            // Divider
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: Theme.chartMarginSmall
                Layout.bottomMargin: Theme.chartMarginSmall
                color: Theme.textSecondaryColor
                opacity: 0.3
            }

            // Pressure
            ColumnLayout {
                Layout.preferredWidth: Theme.scaled(80)
                spacing: Theme.scaled(2)

                Text {
                    text: DE1Device.pressure.toFixed(1)
                    color: Theme.pressureColor
                    font.pixelSize: Theme.scaled(28)
                    font.weight: Font.Medium
                }
                Text {
                    text: "bar"
                    color: Theme.textSecondaryColor
                    font: Theme.captionFont
                }
            }

            // Flow
            ColumnLayout {
                Layout.preferredWidth: Theme.scaled(80)
                spacing: Theme.scaled(2)

                Text {
                    text: DE1Device.flow.toFixed(1)
                    color: Theme.flowColor
                    font.pixelSize: Theme.scaled(28)
                    font.weight: Font.Medium
                }
                Text {
                    text: "mL/s"
                    color: Theme.textSecondaryColor
                    font: Theme.captionFont
                }
            }

            // Temperature
            ColumnLayout {
                Layout.preferredWidth: Theme.scaled(80)
                spacing: Theme.scaled(2)

                Text {
                    text: DE1Device.temperature.toFixed(1)
                    color: Theme.temperatureColor
                    font.pixelSize: Theme.scaled(28)
                    font.weight: Font.Medium
                }
                Text {
                    text: "°C"
                    color: Theme.textSecondaryColor
                    font: Theme.captionFont
                }
            }

            // Divider
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: Theme.chartMarginSmall
                Layout.bottomMargin: Theme.chartMarginSmall
                color: Theme.textSecondaryColor
                opacity: 0.3
            }

            // Weight with progress
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.scaled(4)

                RowLayout {
                    spacing: Theme.spacingSmall

                    Text {
                        text: espressoPage.currentWeight.toFixed(1)
                        color: Theme.weightColor
                        font.pixelSize: Theme.scaled(28)
                        font.weight: Font.Medium
                        Layout.alignment: Qt.AlignBaseline
                    }
                    Text {
                        text: "/ " + MainController.targetWeight.toFixed(0) + " g"
                        color: Theme.textSecondaryColor
                        font.pixelSize: Theme.scaled(18)
                        Layout.alignment: Qt.AlignBaseline
                    }
                }

                ProgressBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.spacingSmall
                    from: 0
                    to: MainController.targetWeight
                    value: espressoPage.currentWeight

                    background: Rectangle {
                        color: Theme.surfaceColor
                        radius: 4
                    }

                    contentItem: Rectangle {
                        width: parent.visualPosition * parent.width
                        height: parent.height
                        radius: 4
                        color: Theme.weightColor
                    }
                }
            }
        }
    }

    // Tap anywhere on chart to stop
    MouseArea {
        anchors.fill: shotGraph
        onClicked: {
            DE1Device.stopOperation()
            root.goToIdle()
        }
    }
}
