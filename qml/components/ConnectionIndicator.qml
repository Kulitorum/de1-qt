import QtQuick
import QtQuick.Layouts
import DecenzaDE1

ColumnLayout {
    property bool machineConnected: false
    property bool scaleConnected: false
    property bool isFlowScale: false

    spacing: Theme.spacingSmall

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: machineConnected ? "Online" : "Offline"
        color: machineConnected ? Theme.successColor : Theme.errorColor
        font: Theme.valueFont
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
