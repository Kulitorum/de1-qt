import QtQuick
import QtQuick.Controls
import DE1App

Slider {
    id: control

    property color trackColor: Theme.surfaceColor
    property color progressColor: Theme.primaryColor
    property color handleColor: Theme.primaryColor

    implicitWidth: 200
    implicitHeight: Theme.scaled(60)  // Large touch area

    background: Item {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: Theme.scaled(60)  // Full touch height

        // Visual track (smaller than touch area)
        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: Theme.scaled(8)
            radius: height / 2
            color: control.trackColor

            // Progress fill
            Rectangle {
                width: control.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: control.progressColor
            }
        }
    }

    handle: Item {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: Theme.scaled(60)   // Large touch target
        height: Theme.scaled(60)  // Large touch target

        // Visual handle (smaller, centered)
        Rectangle {
            anchors.centerIn: parent
            width: Theme.scaled(24)
            height: Theme.scaled(24)
            radius: width / 2
            color: control.pressed ? Qt.darker(control.handleColor, 1.2) : control.handleColor

            // Inner highlight
            Rectangle {
                anchors.centerIn: parent
                width: Theme.scaled(10)
                height: Theme.scaled(10)
                radius: width / 2
                color: "white"
                opacity: 0.3
            }
        }
    }
}
