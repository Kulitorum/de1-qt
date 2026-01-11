import QtQuick
import QtQuick.Controls
import DecenzaDE1

// Round icon button with consistent styling
// Use text property for text/emoji icons, or icon.source for image icons
RoundButton {
    id: root

    // For toggle states (starred, selected, etc.)
    property bool active: false
    property color activeColor: Theme.primaryColor
    property color inactiveColor: Theme.textSecondaryColor

    // Required for accessibility
    required property string accessibleName

    implicitWidth: Theme.scaled(40)
    implicitHeight: Theme.scaled(40)
    flat: true

    // Default icon styling - override with icon.width/height/color as needed
    icon.width: Theme.scaled(18)
    icon.height: Theme.scaled(18)
    icon.color: root.active ? root.activeColor : root.inactiveColor

    // Text styling for text/emoji icons
    font.pixelSize: Theme.scaled(20)

    // Custom contentItem handles both text icons and image icons
    contentItem: Item {
        implicitWidth: root.implicitWidth
        implicitHeight: root.implicitHeight

        // Text icon (emoji/symbol) - shown when text is set
        Text {
            anchors.centerIn: parent
            visible: root.text !== ""
            text: root.text
            font: root.font
            color: root.active ? root.activeColor : root.inactiveColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: root.enabled ? 1.0 : 0.5
        }

        // Image icon - shown when icon.source is set
        Image {
            anchors.centerIn: parent
            visible: root.text === "" && root.icon.source.toString() !== ""
            source: root.icon.source
            sourceSize.width: root.icon.width
            sourceSize.height: root.icon.height
            width: root.icon.width
            height: root.icon.height
            fillMode: Image.PreserveAspectFit
            opacity: root.enabled ? 1.0 : 0.5
        }
    }

    background: Rectangle {
        radius: width / 2
        color: {
            if (!root.enabled) return "transparent"
            if (root.pressed) return Qt.rgba(1, 1, 1, 0.15)
            if (root.hovered) return Qt.rgba(1, 1, 1, 0.08)
            return "transparent"
        }

        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: root.accessibleName
    Accessible.focusable: true

    // Focus indicator
    FocusIndicator {
        targetItem: root
        visible: root.activeFocus
    }
}
