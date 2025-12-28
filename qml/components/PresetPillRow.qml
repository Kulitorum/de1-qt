import QtQuick
import QtQuick.Layouts
import DecenzaDE1

FocusScope {
    id: root

    property var presets: []
    property int selectedIndex: -1
    property int focusedIndex: 0  // Currently focused pill for keyboard nav
    property real maxWidth: Theme.scaled(900)  // Max width before wrapping

    signal presetSelected(int index)

    implicitHeight: contentColumn.implicitHeight
    implicitWidth: maxWidth

    // Keyboard navigation
    activeFocusOnTab: true

    Keys.onLeftPressed: {
        if (focusedIndex > 0) focusedIndex--
        announceCurrentPill()
    }
    Keys.onRightPressed: {
        if (focusedIndex < presets.length - 1) focusedIndex++
        announceCurrentPill()
    }
    Keys.onReturnPressed: presetSelected(focusedIndex)
    Keys.onEnterPressed: presetSelected(focusedIndex)
    Keys.onSpacePressed: presetSelected(focusedIndex)

    // Announce pill when focused
    onActiveFocusChanged: {
        if (activeFocus) announceCurrentPill()
    }

    function announceCurrentPill() {
        if (typeof AccessibilityManager !== "undefined" && AccessibilityManager.enabled && presets.length > 0) {
            var name = presets[focusedIndex].name || ""
            var status = focusedIndex === selectedIndex ? ", selected" : ""
            AccessibilityManager.announce(name + status)
        }
    }

    // Calculate how many pills fit per row
    readonly property real pillSpacing: Theme.scaled(12)
    readonly property real pillPadding: Theme.scaled(40)  // Horizontal padding inside pill

    // Cached rows model to avoid binding loops
    property var rowsModel: calculateRows()

    // Hidden TextMetrics for measuring pill text widths
    TextMetrics {
        id: textMetrics
        font.pixelSize: Theme.scaled(16)
        font.bold: true
    }

    function measureTextWidth(text) {
        textMetrics.text = text
        return textMetrics.width
    }

    // Recalculate when presets change
    onPresetsChanged: rowsModel = calculateRows()
    onMaxWidthChanged: rowsModel = calculateRows()

    // Group presets into rows, distributing evenly for aesthetics (3/2 instead of 4/1)
    function calculateRows() {
        if (presets.length === 0) return []

        // First pass: calculate pill widths based on actual text width
        var pillWidths = []
        for (var i = 0; i < presets.length; i++) {
            var textWidth = measureTextWidth(presets[i].name || "")
            pillWidths.push(textWidth + pillPadding)
        }

        // Count how many rows we need with greedy packing
        var numRows = 1
        var rowWidth = 0
        for (i = 0; i < presets.length; i++) {
            var neededWidth = rowWidth > 0 ? pillWidths[i] + pillSpacing : pillWidths[i]
            if (rowWidth + neededWidth > maxWidth) {
                numRows++
                rowWidth = pillWidths[i]
            } else {
                rowWidth += neededWidth
            }
        }

        // If only one row needed, just return all in one row
        if (numRows === 1) {
            var singleRow = []
            for (i = 0; i < presets.length; i++) {
                singleRow.push({index: i, preset: presets[i], width: pillWidths[i]})
            }
            return [singleRow]
        }

        // Distribute pills evenly across rows
        var pillsPerRow = Math.ceil(presets.length / numRows)
        var rows = []
        var currentRow = []

        for (i = 0; i < presets.length; i++) {
            currentRow.push({index: i, preset: presets[i], width: pillWidths[i]})

            if (currentRow.length >= pillsPerRow) {
                rows.push(currentRow)
                currentRow = []
                // Recalculate for remaining pills to keep distribution even
                var remaining = presets.length - i - 1
                var remainingRows = numRows - rows.length
                if (remainingRows > 0) {
                    pillsPerRow = Math.ceil(remaining / remainingRows)
                }
            }
        }

        if (currentRow.length > 0) {
            rows.push(currentRow)
        }

        return rows
    }

    Column {
        id: contentColumn
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.scaled(8)

        Repeater {
            model: root.rowsModel

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.pillSpacing

                Repeater {
                    model: modelData

                    Rectangle {
                        id: pill

                        property bool isSelected: modelData.index === root.selectedIndex
                        property bool isFocused: root.activeFocus && modelData.index === root.focusedIndex

                        width: pillText.implicitWidth + root.pillPadding
                        height: Theme.scaled(50)
                        radius: Theme.scaled(10)

                        color: isSelected ? Theme.primaryColor : Theme.backgroundColor
                        border.color: isSelected ? Theme.primaryColor : Theme.textSecondaryColor
                        border.width: 1

                        Accessible.role: Accessible.Button
                        Accessible.name: (modelData.preset.name || "") + (isSelected ? ", selected" : "")
                        Accessible.description: "Double-tap to select."
                        Accessible.focusable: true

                        Behavior on color { ColorAnimation { duration: 150 } }

                        // Focus indicator
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -Theme.focusMargin
                            visible: pill.isFocused
                            color: "transparent"
                            border.width: Theme.focusBorderWidth
                            border.color: Theme.focusColor
                            radius: parent.radius + Theme.focusMargin
                        }

                        Text {
                            id: pillText
                            anchors.centerIn: parent
                            text: modelData.preset.name || ""
                            color: pill.isSelected ? "white" : Theme.textColor
                            font.pixelSize: Theme.scaled(16)
                            font.bold: true
                        }

                        AccessibleMouseArea {
                            anchors.fill: parent

                            accessibleName: {
                                if (!modelData || !modelData.preset) return ""
                                var name = modelData.preset.name || ""
                                var status = modelData.index === root.selectedIndex ? ", selected" : ""
                                return name + status
                            }
                            accessibleItem: pill

                            onAccessibleClicked: {
                                if (!modelData || !modelData.preset) return
                                // Announce selection
                                if (typeof AccessibilityManager !== "undefined" && AccessibilityManager.enabled) {
                                    AccessibilityManager.announce(modelData.preset.name + " selected")
                                }
                                root.presetSelected(modelData.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
