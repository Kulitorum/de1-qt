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
    AccessibleMouseArea {
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
