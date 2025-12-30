import QtQuick
import QtQuick.Controls
import DecenzaDE1

TextField {
    id: control

    font: Theme.bodyFont
    color: Theme.textColor
    placeholderTextColor: Theme.textSecondaryColor

    // Explicit padding prevents Material theme's floating label animation
    leftPadding: 12
    rightPadding: 12
    topPadding: 12
    bottomPadding: 12

    background: Rectangle {
        color: Theme.backgroundColor
        radius: 4
        border.color: control.activeFocus ? Theme.primaryColor : Theme.textSecondaryColor
        border.width: 1
    }
}
