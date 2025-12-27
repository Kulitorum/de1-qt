import QtQuick
import QtQuick.Layouts
import DecenzaDE1

Rectangle {
    color: Theme.surfaceColor

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.chartMarginSmall
        anchors.rightMargin: Theme.spacingLarge
        spacing: Theme.spacingMedium

        // Page title (from root.currentPageTitle)
        Text {
            text: root.currentPageTitle
            color: Theme.textColor
            font.pixelSize: Theme.scaled(20)
            font.bold: true
            Layout.preferredWidth: implicitWidth
            elide: Text.ElideRight
        }

        // Separator after title (if title exists)
        Rectangle {
            width: 1
            height: Theme.scaled(30)
            color: Theme.textSecondaryColor
            opacity: 0.3
            visible: root.currentPageTitle !== ""
        }

        // Machine state
        Text {
            text: DE1Device.stateString
            color: Theme.textColor
            font: Theme.bodyFont
        }

        Text {
            text: " - " + DE1Device.subStateString
            color: Theme.textSecondaryColor
            font: Theme.bodyFont
            visible: MachineState.isFlowing
        }

        Item { Layout.fillWidth: true }

        // Temperature
        Text {
            text: DE1Device.temperature.toFixed(1) + "°C"
            color: Theme.temperatureColor
            font: Theme.bodyFont
        }

        // Separator
        Rectangle {
            width: 1
            height: Theme.scaled(30)
            color: Theme.textSecondaryColor
            opacity: 0.3
        }

        // Water level
        Text {
            text: DE1Device.waterLevel.toFixed(0) + "%"
            color: DE1Device.waterLevel > 20 ? Theme.primaryColor : Theme.warningColor
            font: Theme.bodyFont
        }

        // Separator
        Rectangle {
            width: 1
            height: Theme.scaled(30)
            color: Theme.textSecondaryColor
            opacity: 0.3
        }

        // Scale warning (clickable to scan)
        Rectangle {
            visible: BLEManager.scaleConnectionFailed || (BLEManager.hasSavedScale && (!ScaleDevice || !ScaleDevice.connected))
            color: BLEManager.scaleConnectionFailed ? Theme.errorColor : "transparent"
            radius: 4
            Layout.preferredHeight: Theme.touchTargetMin
            Layout.preferredWidth: scaleWarningRow.implicitWidth + Theme.spacingMedium

            Row {
                id: scaleWarningRow
                anchors.centerIn: parent
                spacing: Theme.spacingSmall

                Text {
                    text: BLEManager.scaleConnectionFailed ? "Scale not found" :
                          (ScaleDevice && ScaleDevice.connected ? "" : "Scale...")
                    color: BLEManager.scaleConnectionFailed ? "white" : Theme.textSecondaryColor
                    font: Theme.bodyFont
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "[Scan]"
                    color: Theme.accentColor
                    font.pixelSize: Theme.bodyFont.pixelSize
                    font.underline: true
                    visible: BLEManager.scaleConnectionFailed
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: BLEManager.scanForScales()
                    }
                }
            }
        }

        // Scale connected indicator
        Row {
            spacing: Theme.spacingSmall
            visible: ScaleDevice && ScaleDevice.connected

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.scaled(8)
                height: Theme.scaled(8)
                radius: Theme.scaled(4)
                color: Theme.weightColor
            }

            Text {
                text: MachineState.scaleWeight.toFixed(1) + "g"
                color: Theme.weightColor
                font: Theme.bodyFont
            }
        }

        // Separator
        Rectangle {
            width: 1
            height: Theme.scaled(30)
            color: Theme.textSecondaryColor
            opacity: 0.3
        }

        // Connection indicator
        Row {
            spacing: Theme.spacingSmall

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.scaled(10)
                height: Theme.scaled(10)
                radius: Theme.scaled(5)
                color: DE1Device.connected ? Theme.successColor : Theme.errorColor
            }

            Text {
                text: DE1Device.connected ? "Online" : "Offline"
                color: DE1Device.connected ? Theme.successColor : Theme.textSecondaryColor
                font: Theme.bodyFont
            }
        }
    }
}
