import QtQuick
import QtQuick.Controls
import DecenzaDE1

// Button with required accessibility - enforces accessibleName at compile time
Button {
    id: root

    // Required property - will cause compile error if not provided
    required property string accessibleName

    // Optional description for additional context
    property string accessibleDescription: ""

    // For AccessibleMouseArea to reference
    property Item accessibleItem: root

    implicitHeight: Theme.scaled(36)
    leftPadding: Theme.scaled(16)
    rightPadding: Theme.scaled(16)

    contentItem: Text {
        text: root.text
        font.pixelSize: Theme.scaled(14)
        font.family: Theme.bodyFont.family
        color: root.enabled ? Theme.textColor : Theme.textSecondaryColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        implicitHeight: Theme.scaled(36)
        color: root.down ? Qt.darker(Theme.surfaceColor, 1.2) : Theme.surfaceColor
        border.color: root.enabled ? Theme.borderColor : Qt.darker(Theme.borderColor, 1.2)
        border.width: 1
        radius: Theme.scaled(6)
    }

    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.description: accessibleDescription
    Accessible.focusable: true

    // Focus indicator
    FocusIndicator {
        targetItem: root
        visible: root.activeFocus
    }

    // Tap-to-announce, tap-again-to-activate for accessibility mode
    // Using TapHandler for better touch responsiveness
    AccessibleTapHandler {
        anchors.fill: parent
        accessibleName: root.accessibleName
        accessibleItem: root.accessibleItem

        onAccessibleClicked: {
            if (root.enabled) {
                root.clicked()
            }
        }
    }
}
