import QtQuick
import QtQuick.Controls
import DecenzaDE1

Button {
    id: control

    property string iconSource: ""
    property color backgroundColor: Theme.primaryColor
    property int iconSize: Theme.scaled(48)

    // Note: pressAndHold() and doubleClicked() are inherited from Button/AbstractButton

    // Track if long-press fired (to prevent click after hold)
    property bool _longPressTriggered: false
    property bool _isPressed: false

    // Enable keyboard focus
    focusPolicy: Qt.StrongFocus
    activeFocusOnTab: true

    // Accessibility
    Accessible.role: Accessible.Button
    Accessible.name: control.text
    Accessible.description: "Double-tap to select profile. Long-press for settings."
    Accessible.focusable: true

    implicitWidth: Theme.scaled(150)
    implicitHeight: Theme.scaled(120)

    contentItem: Column {
        spacing: Theme.scaled(10)
        anchors.centerIn: parent

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.scaled(48)
            height: Theme.scaled(48)
            visible: control.iconSource !== ""

            Image {
                anchors.centerIn: parent
                source: control.iconSource
                width: control.iconSize
                height: control.iconSize
                fillMode: Image.PreserveAspectFit
                opacity: control.enabled ? 1.0 : 0.5
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: control.text
            color: control.enabled ? Theme.textColor : Theme.textSecondaryColor
            font: Theme.bodyFont
        }
    }

    background: Rectangle {
        radius: Theme.buttonRadius
        color: {
            if (!control.enabled) return Theme.buttonDisabled
            if (control._isPressed) return Qt.darker(control.backgroundColor, 1.2)
            if (control.hovered || control.activeFocus) return Qt.lighter(control.backgroundColor, 1.1)
            return control.backgroundColor
        }

        // Focus indicator
        Rectangle {
            anchors.fill: parent
            anchors.margins: -Theme.focusMargin
            visible: control.activeFocus
            color: "transparent"
            border.width: Theme.focusBorderWidth
            border.color: Theme.focusColor
            radius: parent.radius + Theme.focusMargin
        }

        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }

    // Custom interaction handling using AccessibleMouseArea
    AccessibleMouseArea {
        anchors.fill: parent
        enabled: control.enabled

        accessibleName: control.text
        accessibleItem: control
        supportLongPress: true
        supportDoubleClick: true

        // Track pressed state for visual feedback
        onIsPressedChanged: control._isPressed = isPressed

        onAccessibleClicked: control.clicked()
        onAccessibleDoubleClicked: control.doubleClicked()
        onAccessibleLongPressed: {
            control._longPressTriggered = true
            control.pressAndHold()
        }
    }

    // Keyboard handling
    Keys.onReturnPressed: {
        control._longPressTriggered = false
        control.clicked()
    }

    Keys.onEnterPressed: {
        control._longPressTriggered = false
        control.clicked()
    }

    Keys.onSpacePressed: {
        control._longPressTriggered = false
        control.clicked()
    }

    // Shift+Enter for long-press action
    Keys.onPressed: function(event) {
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) &&
            (event.modifiers & Qt.ShiftModifier)) {
            control.pressAndHold()
            event.accepted = true
        }
    }

    // Announce button name when focused (for accessibility)
    onActiveFocusChanged: {
        if (activeFocus && typeof AccessibilityManager !== "undefined" && AccessibilityManager.enabled) {
            AccessibilityManager.announce(control.text)
        }
    }
}
