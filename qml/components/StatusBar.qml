import QtQuick
import QtQuick.Layouts
import DE1App

Rectangle {
    color: Theme.surfaceColor

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.standardMargin
        anchors.rightMargin: Theme.standardMargin
        spacing: Theme.scaled(10)

        // Page title (from root.currentPageTitle)
        Text {
            text: root.currentPageTitle
            color: Theme.textColor
            font.pixelSize: Theme.scaled(16)
            font.bold: true
            Layout.preferredWidth: implicitWidth
            elide: Text.ElideRight
        }

        // Separator after title (if title exists)
        Rectangle {
            width: Theme.scaled(1)
            height: parent.height * 0.5
            color: Theme.textSecondaryColor
            opacity: 0.3
            visible: root.currentPageTitle !== ""
        }

        // Machine state
        Text {
            text: DE1Device.stateString
            color: Theme.textColor
            font.pixelSize: Theme.scaled(14)
        }

        Text {
            text: " - " + DE1Device.subStateString
            color: Theme.textSecondaryColor
            font.pixelSize: Theme.scaled(14)
            visible: MachineState.isFlowing
        }

        Item { Layout.fillWidth: true }

        // Temperature
        Text {
            text: DE1Device.temperature.toFixed(1) + "°C"
            color: Theme.temperatureColor
            font.pixelSize: Theme.scaled(14)
        }

        // Separator
        Rectangle {
            width: Theme.scaled(1)
            height: parent.height * 0.5
            color: Theme.textSecondaryColor
            opacity: 0.3
        }

        // Water level
        Text {
            text: DE1Device.waterLevel.toFixed(0) + "%"
            color: DE1Device.waterLevel > 20 ? Theme.primaryColor : Theme.warningColor
            font.pixelSize: Theme.scaled(14)
        }

        // Separator
        Rectangle {
            width: Theme.scaled(1)
            height: parent.height * 0.5
            color: Theme.textSecondaryColor
            opacity: 0.3
        }

        // Connection indicator
        Row {
            spacing: Theme.scaled(5)

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
                font.pixelSize: Theme.scaled(14)
            }
        }
    }
}
