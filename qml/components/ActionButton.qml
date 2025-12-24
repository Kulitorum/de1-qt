import QtQuick
import QtQuick.Controls
import DE1App

Button {
    id: control

    property string iconSource: ""
    property color backgroundColor: Theme.primaryColor

    // Note: pressAndHold() and doubleClicked() are inherited from Button/AbstractButton

    // Track if long-press fired (to prevent click after hold)
    property bool _longPressTriggered: false
    property bool _isPressed: false

    implicitWidth: 150
    implicitHeight: 120

    contentItem: Column {
        spacing: 10
        anchors.centerIn: parent

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: control.iconSource
            width: 48
            height: 48
            fillMode: Image.PreserveAspectFit
            visible: control.iconSource !== ""
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: control.text
            color: Theme.textColor
            font: Theme.bodyFont
        }
    }

    background: Rectangle {
        radius: Theme.buttonRadius
        color: {
            if (!control.enabled) return Theme.buttonDisabled
            if (control._isPressed) return Qt.darker(control.backgroundColor, 1.2)
            if (control.hovered) return Qt.lighter(control.backgroundColor, 1.1)
            return control.backgroundColor
        }

        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }

    // Custom interaction handling for long-press and double-click
    MouseArea {
        anchors.fill: parent
        enabled: control.enabled

        property int clickCount: 0

        Timer {
            id: longPressTimer
            interval: 500
            onTriggered: {
                control._longPressTriggered = true
                control.pressAndHold()
            }
        }

        Timer {
            id: doubleClickTimer
            interval: 300
            onTriggered: {
                if (parent.clickCount === 1) {
                    control.clicked()
                }
                parent.clickCount = 0
            }
        }

        onPressed: {
            control._longPressTriggered = false
            control._isPressed = true
            longPressTimer.start()
        }

        onReleased: {
            longPressTimer.stop()
            control._isPressed = false

            if (!control._longPressTriggered) {
                clickCount++
                if (clickCount === 2) {
                    doubleClickTimer.stop()
                    clickCount = 0
                    control.doubleClicked()
                } else {
                    doubleClickTimer.restart()
                }
            }
        }

        onCanceled: {
            longPressTimer.stop()
            control._isPressed = false
        }
    }
}
