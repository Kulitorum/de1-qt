import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * RecipeSection - A styled section container for the Recipe Editor
 * Provides a title bar and content area with consistent styling
 */
Item {
    id: root

    property string title: ""
    default property alias content: contentColumn.children

    implicitHeight: contentColumn.implicitHeight + (title ? headerRect.height + Theme.scaled(8) : 0)

    // Section header
    Rectangle {
        id: headerRect
        width: parent.width
        height: title ? Theme.scaled(28) : 0
        visible: title !== ""
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.scaled(4)
            spacing: Theme.scaled(8)

            Rectangle {
                width: Theme.scaled(3)
                height: Theme.scaled(16)
                radius: Theme.scaled(1.5)
                color: Theme.primaryColor
            }

            Text {
                text: root.title
                font: Theme.captionFont
                color: Theme.textColor
                Layout.fillWidth: true
            }
        }
    }

    // Content area
    ColumnLayout {
        id: contentColumn
        anchors.top: headerRect.bottom
        anchors.topMargin: title ? Theme.scaled(8) : 0
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.scaled(10)
    }
}
