import QtQuick
import QtQuick.Controls
import DecenzaDE1

// Styled button - uses AbstractButton to avoid Material style interference
AbstractButton {
    id: root

    // Style variants (only one should be true)
    property bool primary: false   // Filled primary color background
    property bool subtle: false    // Glass-like semi-transparent (for dark backgrounds)

    implicitWidth: contentText.implicitWidth + Theme.scaled(32)
    implicitHeight: Theme.scaled(36)

    contentItem: Text {
        id: contentText
        text: root.text
        font.pixelSize: Theme.scaled(14)
        font.family: Theme.bodyFont.family
        color: {
            if (!root.enabled) return Theme.textSecondaryColor
            if (root.primary || root.subtle) return "white"
            return Theme.textColor
        }
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        color: {
            if (root.subtle) {
                return root.down ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(1, 1, 1, 0.2)
            }
            if (root.primary) {
                return root.down ? Qt.darker(Theme.primaryColor, 1.1) : Theme.primaryColor
            }
            return root.down ? Qt.darker(Theme.surfaceColor, 1.2) : Theme.surfaceColor
        }
        border.width: (root.primary || root.subtle) ? 0 : 1
        border.color: (root.primary || root.subtle) ? "transparent" : (root.enabled ? Theme.borderColor : Qt.darker(Theme.borderColor, 1.2))
        radius: Theme.scaled(6)

        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }

}
