import QtQuick
import QtQuick.Layouts
import DecenzaDE1

ColumnLayout {
    property bool machineConnected: false
    property bool scaleConnected: false
    property bool isFlowScale: false

    spacing: 5

    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        Rectangle {
            width: 12
            height: 12
            radius: 6
            color: machineConnected ? Theme.successColor : Theme.errorColor
        }

        Text {
            text: machineConnected ? "Connected" : "Disconnected"
            color: machineConnected ? Theme.successColor : Theme.errorColor
            font: Theme.bodyFont
        }
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: {
            if (!machineConnected) return "Machine"
            if (scaleConnected && !isFlowScale) return "Machine + Scale"
            if (isFlowScale) return "Machine + Simulated Scale"
            return "Machine"
        }
        color: Theme.textSecondaryColor
        font: Theme.labelFont
    }
}
