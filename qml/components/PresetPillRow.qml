import QtQuick
import QtQuick.Layouts
import DecenzaDE1

Item {
    id: root

    property var presets: []
    property int selectedIndex: -1

    signal presetSelected(int index)

    implicitHeight: Theme.scaled(70)
    implicitWidth: presetsRow.implicitWidth

    Row {
        id: presetsRow
        anchors.centerIn: parent
        spacing: Theme.scaled(16)

        Repeater {
            model: root.presets

            Rectangle {
                id: pill

                property bool isSelected: index === root.selectedIndex

                width: pillText.implicitWidth + Theme.scaled(48)
                height: Theme.scaled(60)
                radius: Theme.scaled(12)

                color: isSelected ? Theme.primaryColor : Theme.backgroundColor
                border.color: isSelected ? Theme.primaryColor : Theme.textSecondaryColor
                border.width: 1

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    id: pillText
                    anchors.centerIn: parent
                    text: modelData.name || ""
                    color: pill.isSelected ? "white" : Theme.textColor
                    font.pixelSize: Theme.scaled(18)
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.presetSelected(index)
                }
            }
        }
    }
}
