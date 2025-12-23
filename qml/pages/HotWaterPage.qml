import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DE1App
import "../components"

Page {
    objectName: "hotWaterPage"
    background: Rectangle { color: Theme.backgroundColor }

    Component.onCompleted: updatePageTitle()

    function updatePageTitle() {
        root.currentPageTitle = MachineState.phase === MachineStateType.Phase.Flushing ? "Flushing" : "Hot Water"
    }

    Connections {
        target: MachineState
        function onPhaseChanged() { updatePageTitle() }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.standardMargin
        anchors.topMargin: Theme.scaled(60)
        spacing: Theme.scaled(30)

        // Timer
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: MachineState.shotTime.toFixed(1) + "s"
            color: Theme.textColor
            font: Theme.timerFont
        }

        // Temperature display
        CircularGauge {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 200
            Layout.preferredHeight: 200
            value: DE1Device.temperature
            minValue: 60
            maxValue: 100
            unit: "°C"
            color: Theme.primaryColor
            label: "Water Temp"
        }

        Item { Layout.fillHeight: true }

        // Stop button
        ActionButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 300
            Layout.preferredHeight: 100
            text: "STOP"
            backgroundColor: Theme.accentColor
            onClicked: {
                DE1Device.stopOperation()
                root.goToIdle()
            }
        }

        Item { Layout.fillHeight: true }
    }

    // Tap anywhere to stop
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            DE1Device.stopOperation()
            root.goToIdle()
        }
    }
}
