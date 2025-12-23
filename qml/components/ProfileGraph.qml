import QtQuick
import QtCharts
import DE1App

ChartView {
    id: chart
    antialiasing: true
    backgroundColor: "transparent"
    plotAreaColor: Qt.darker(Theme.surfaceColor, 1.3)
    legend.visible: false

    margins.top: Theme.scaled(10)
    margins.bottom: Theme.scaled(40)
    margins.left: Theme.scaled(10)
    margins.right: Theme.scaled(10)

    // Properties
    property var frames: []
    property int selectedFrameIndex: -1

    // Signals
    signal frameSelected(int index)
    signal frameDoubleClicked(int index)

    // Calculate total duration from frames
    property double totalDuration: {
        var total = 0
        for (var i = 0; i < frames.length; i++) {
            total += frames[i].seconds || 0
        }
        return Math.max(total, 5)  // Minimum 5 seconds
    }

    // Time axis (X)
    ValueAxis {
        id: timeAxis
        min: 0
        max: totalDuration * 1.1  // 10% padding
        tickCount: Math.min(10, Math.max(3, Math.floor(totalDuration / 5) + 1))
        labelFormat: "%.0f"
        labelsColor: Theme.textSecondaryColor
        labelsFont.pixelSize: Theme.scaled(12)
        gridLineColor: Qt.rgba(255, 255, 255, 0.1)
        titleText: "Time (s)"
        titleBrush: Theme.textSecondaryColor
        titleFont.pixelSize: Theme.scaled(12)
    }

    // Pressure/Flow axis (left Y)
    ValueAxis {
        id: pressureAxis
        min: 0
        max: 12
        tickCount: 5
        labelFormat: "%.0f"
        labelsColor: Theme.textSecondaryColor
        labelsFont.pixelSize: Theme.scaled(12)
        gridLineColor: Qt.rgba(255, 255, 255, 0.1)
        titleText: "bar / mL/s"
        titleBrush: Theme.textSecondaryColor
        titleFont.pixelSize: Theme.scaled(12)
    }

    // Temperature axis (right Y)
    ValueAxis {
        id: tempAxis
        min: 80
        max: 100
        tickCount: 5
        labelFormat: "%.0f"
        labelsColor: Theme.temperatureColor
        labelsFont.pixelSize: Theme.scaled(12)
        gridLineColor: "transparent"
        titleText: "°C"
        titleBrush: Theme.temperatureColor
        titleFont.pixelSize: Theme.scaled(12)
    }

    // Pressure target curve (dashed)
    LineSeries {
        id: pressureGoalSeries
        name: "Pressure"
        color: Theme.pressureGoalColor
        width: Theme.graphLineWidth
        style: Qt.DashLine
        axisX: timeAxis
        axisY: pressureAxis
    }

    // Flow target curve (dashed)
    LineSeries {
        id: flowGoalSeries
        name: "Flow"
        color: Theme.flowGoalColor
        width: Theme.graphLineWidth
        style: Qt.DashLine
        axisX: timeAxis
        axisY: pressureAxis
    }

    // Temperature target curve (dashed)
    LineSeries {
        id: temperatureGoalSeries
        name: "Temperature"
        color: Theme.temperatureGoalColor
        width: Math.max(2, Theme.graphLineWidth - 1)
        style: Qt.DashLine
        axisX: timeAxis
        axisYRight: tempAxis
    }

    // Frame region overlays
    Item {
        id: frameOverlays
        anchors.fill: parent

        Repeater {
            id: frameRepeater
            model: frames.length

            delegate: Item {
                id: frameDelegate

                property int frameIndex: index
                property var frame: frames[index]
                property double frameStart: {
                    var start = 0
                    for (var i = 0; i < index; i++) {
                        start += frames[i].seconds || 0
                    }
                    return start
                }
                property double frameDuration: frame ? frame.seconds || 0 : 0

                // Calculate position based on chart plot area
                x: chart.plotArea.x + (frameStart / (totalDuration * 1.1)) * chart.plotArea.width
                y: chart.plotArea.y
                width: (frameDuration / (totalDuration * 1.1)) * chart.plotArea.width
                height: chart.plotArea.height

                // Frame background
                Rectangle {
                    anchors.fill: parent
                    color: {
                        if (frameIndex === selectedFrameIndex) {
                            return Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.3)
                        }
                        // Alternate colors for visibility
                        return frameIndex % 2 === 0 ?
                            Qt.rgba(255, 255, 255, 0.05) :
                            Qt.rgba(255, 255, 255, 0.02)
                    }
                    border.width: frameIndex === selectedFrameIndex ? Theme.scaled(2) : Theme.scaled(1)
                    border.color: frameIndex === selectedFrameIndex ?
                        Theme.accentColor : Qt.rgba(255, 255, 255, 0.2)

                    // Pump mode indicator at bottom
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Theme.scaled(4)
                        color: frame && frame.pump === "flow" ? Theme.flowColor : Theme.pressureColor
                        opacity: 0.8
                    }
                }

                // Frame label - rotated 90 degrees, centered horizontally, end of text at top
                Text {
                    id: labelText
                    x: (parent.width - height) / 2  // Center based on rotated dimensions
                    y: Theme.scaled(4)  // Small margin from top edge
                    text: frame ? (frame.name || ("Frame " + (frameIndex + 1))) : ""
                    color: Theme.textColor
                    font.pixelSize: Theme.scaled(14)
                    font.bold: frameIndex === selectedFrameIndex
                    rotation: -90
                    transformOrigin: Item.TopRight  // End of text stays at top
                    opacity: 0.9
                }

                // Click handler
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        selectedFrameIndex = frameIndex
                        frameSelected(frameIndex)
                    }
                    onDoubleClicked: {
                        frameDoubleClicked(frameIndex)
                    }
                }
            }
        }
    }

    // Generate target curves from frames
    function updateCurves() {
        pressureGoalSeries.clear()
        flowGoalSeries.clear()
        temperatureGoalSeries.clear()

        if (frames.length === 0) return

        var time = 0

        for (var i = 0; i < frames.length; i++) {
            var frame = frames[i]
            var startTime = time
            var endTime = time + (frame.seconds || 0)
            var isSmooth = frame.transition === "smooth"

            // Get previous values for smooth transitions
            var prevPressure = i > 0 ? frames[i-1].pressure : frame.pressure
            var prevFlow = i > 0 ? frames[i-1].flow : frame.flow
            var prevTemp = i > 0 ? frames[i-1].temperature : frame.temperature

            // Pressure curve (only for pressure-control frames)
            if (frame.pump === "pressure") {
                if (isSmooth && i > 0) {
                    // Interpolate from previous
                    pressureGoalSeries.append(startTime, prevPressure)
                }
                pressureGoalSeries.append(endTime, frame.pressure)
            } else if (i === 0 || frames[i-1].pump !== "pressure") {
                // No pressure goal in flow mode - clear the line
            }

            // Flow curve (only for flow-control frames)
            if (frame.pump === "flow") {
                if (isSmooth && i > 0) {
                    flowGoalSeries.append(startTime, prevFlow)
                }
                flowGoalSeries.append(endTime, frame.flow)
            }

            // Temperature curve (always shown)
            if (isSmooth && i > 0) {
                temperatureGoalSeries.append(startTime, prevTemp)
            } else {
                temperatureGoalSeries.append(startTime, frame.temperature)
            }
            temperatureGoalSeries.append(endTime, frame.temperature)

            time = endTime
        }
    }

    // Re-generate curves when frames change
    onFramesChanged: {
        updateCurves()
    }

    Component.onCompleted: {
        updateCurves()
    }

    // Legend at bottom
    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: Theme.scaled(8)
        spacing: Theme.scaled(24)

        // Pressure
        Row {
            spacing: Theme.scaled(6)
            Rectangle {
                width: Theme.scaled(20)
                height: Theme.scaled(3)
                radius: Theme.scaled(1)
                color: Theme.pressureGoalColor
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "Pressure"
                color: Theme.textSecondaryColor
                font.pixelSize: Theme.scaled(12)
            }
        }

        // Flow
        Row {
            spacing: Theme.scaled(6)
            Rectangle {
                width: Theme.scaled(20)
                height: Theme.scaled(3)
                radius: Theme.scaled(1)
                color: Theme.flowGoalColor
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "Flow"
                color: Theme.textSecondaryColor
                font.pixelSize: Theme.scaled(12)
            }
        }

        // Temperature
        Row {
            spacing: Theme.scaled(6)
            Rectangle {
                width: Theme.scaled(20)
                height: Theme.scaled(3)
                radius: Theme.scaled(1)
                color: Theme.temperatureGoalColor
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "Temp"
                color: Theme.textSecondaryColor
                font.pixelSize: Theme.scaled(12)
            }
        }
    }
}
