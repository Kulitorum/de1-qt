import QtQuick
import QtCharts
import DecenzaDE1

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

    // Force refresh the graph (call when frame properties change in place)
    function refresh() {
        updateCurves()
        // Force Repeater to refresh by toggling model
        var savedFrames = frames
        frameRepeater.model = []
        frameRepeater.model = savedFrames
    }

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

    // Dynamic arrays for pressure and flow series (created on demand)
    property var pressureSeriesList: []
    property var flowSeriesList: []

    // Temperature target curve (dashed) - always continuous
    LineSeries {
        id: temperatureGoalSeries
        name: "Temperature"
        color: Theme.temperatureGoalColor
        width: Math.max(2, Theme.graphLineWidth - 1)
        style: Qt.DashLine
        axisX: timeAxis
        axisYRight: tempAxis
    }

    // Create a new pressure series
    function createPressureSeries() {
        var series = chart.createSeries(ChartView.SeriesTypeLine, "Pressure", timeAxis, pressureAxis)
        series.color = Theme.pressureGoalColor
        series.width = Theme.graphLineWidth
        series.style = Qt.DashLine
        pressureSeriesList.push(series)
        return series
    }

    // Create a new flow series
    function createFlowSeries() {
        var series = chart.createSeries(ChartView.SeriesTypeLine, "Flow", timeAxis, pressureAxis)
        series.color = Theme.flowGoalColor
        series.width = Theme.graphLineWidth
        series.style = Qt.DashLine
        flowSeriesList.push(series)
        return series
    }

    // Clear all dynamic series
    function clearDynamicSeries() {
        for (var i = 0; i < pressureSeriesList.length; i++) {
            chart.removeSeries(pressureSeriesList[i])
        }
        for (var j = 0; j < flowSeriesList.length; j++) {
            chart.removeSeries(flowSeriesList[j])
        }
        pressureSeriesList = []
        flowSeriesList = []
    }

    // Frame region overlays
    Item {
        id: frameOverlays
        anchors.fill: parent

        Repeater {
            id: frameRepeater
            model: frames  // Use frames array directly

            delegate: Item {
                id: frameDelegate

                required property int index
                required property var modelData
                property var frame: modelData
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
                        if (index === selectedFrameIndex) {
                            return Qt.rgba(Theme.accentColor.r, Theme.accentColor.g, Theme.accentColor.b, 0.3)
                        }
                        // Alternate colors for visibility
                        return index % 2 === 0 ?
                            Qt.rgba(255, 255, 255, 0.05) :
                            Qt.rgba(255, 255, 255, 0.02)
                    }
                    border.width: index === selectedFrameIndex ? Theme.scaled(2) : Theme.scaled(1)
                    border.color: index === selectedFrameIndex ?
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

                // Frame label - rotated 90 degrees, centered at frame position
                // Clickable to select frame (especially useful for zero-duration frames)
                Item {
                    id: labelContainer
                    // For rotated text: visual width = text height, visual height = text width
                    property real visualWidth: labelText.implicitHeight + Theme.scaled(8)
                    property real visualHeight: labelText.implicitWidth + Theme.scaled(8)

                    // Center horizontally at frame midpoint (or left edge for zero-width frames)
                    x: parent.width / 2 - visualWidth / 2
                    y: Theme.scaled(4)
                    width: visualWidth
                    height: visualHeight

                    Text {
                        id: labelText
                        anchors.centerIn: parent
                        text: frame ? (frame.name || ("Frame " + (index + 1))) : ""
                        color: Theme.textColor
                        font.pixelSize: Theme.scaled(14)
                        font.bold: index === selectedFrameIndex
                        rotation: -90
                        transformOrigin: Item.Center
                        opacity: 0.9
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            selectedFrameIndex = index
                            frameSelected(index)
                        }
                        onDoubleClicked: {
                            frameDoubleClicked(index)
                        }
                    }
                }

                // Click handler for frame area
                MouseArea {
                    anchors.fill: parent
                    // Don't block label clicks
                    z: -1
                    onClicked: {
                        selectedFrameIndex = index
                        frameSelected(index)
                    }
                    onDoubleClicked: {
                        frameDoubleClicked(index)
                    }
                }
            }
        }
    }

    // Generate target curves from frames
    function updateCurves() {
        // Clear all dynamic series and temperature
        clearDynamicSeries()
        temperatureGoalSeries.clear()

        if (frames.length === 0) return

        var time = 0
        var currentPressureSeries = null
        var currentFlowSeries = null

        for (var i = 0; i < frames.length; i++) {
            var frame = frames[i]
            var startTime = time
            var endTime = time + (frame.seconds || 0)
            var isSmooth = frame.transition === "smooth"

            // Check previous frame for pump mode continuity
            var prevFrame = i > 0 ? frames[i-1] : null
            var prevSamePump = prevFrame && prevFrame.pump === frame.pump

            // Get previous values for smooth transitions (only if same pump mode)
            var prevPressure = prevSamePump ? prevFrame.pressure : frame.pressure
            var prevFlow = prevSamePump ? prevFrame.flow : frame.flow
            var prevTemp = i > 0 ? frames[i-1].temperature : frame.temperature

            // Pressure curve (only for pressure-control frames)
            if (frame.pump === "pressure") {
                // Create new series if this is first pressure frame or coming from flow
                if (!currentPressureSeries || (prevFrame && prevFrame.pump !== "pressure")) {
                    currentPressureSeries = createPressureSeries()
                }

                if (isSmooth && prevSamePump) {
                    // Smooth transition from previous pressure frame
                    currentPressureSeries.append(startTime, prevPressure)
                } else {
                    // Fast transition or first in pressure segment
                    currentPressureSeries.append(startTime, frame.pressure)
                }
                currentPressureSeries.append(endTime, frame.pressure)
            }

            // Flow curve (only for flow-control frames)
            if (frame.pump === "flow") {
                // Create new series if this is first flow frame or coming from pressure
                if (!currentFlowSeries || (prevFrame && prevFrame.pump !== "flow")) {
                    currentFlowSeries = createFlowSeries()
                }

                if (isSmooth && prevSamePump) {
                    // Smooth transition from previous flow frame
                    currentFlowSeries.append(startTime, prevFlow)
                } else {
                    // Fast transition or first in flow segment
                    currentFlowSeries.append(startTime, frame.flow)
                }
                currentFlowSeries.append(endTime, frame.flow)
            }

            // Temperature curve (always shown, continuous across all frames)
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
        anchors.bottomMargin: Theme.scaled(12)
        spacing: Theme.scaled(30)

        // Pressure
        Row {
            spacing: Theme.scaled(8)
            Rectangle {
                width: Theme.scaled(24)
                height: Theme.scaled(3)
                radius: Theme.scaled(1)
                color: Theme.pressureGoalColor
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "Pressure"
                color: Theme.textSecondaryColor
                font: Theme.bodyFont
            }
        }

        // Flow
        Row {
            spacing: Theme.scaled(8)
            Rectangle {
                width: Theme.scaled(24)
                height: Theme.scaled(3)
                radius: Theme.scaled(1)
                color: Theme.flowGoalColor
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "Flow"
                color: Theme.textSecondaryColor
                font: Theme.bodyFont
            }
        }

        // Temperature
        Row {
            spacing: Theme.scaled(8)
            Rectangle {
                width: Theme.scaled(24)
                height: Theme.scaled(3)
                radius: Theme.scaled(1)
                color: Theme.temperatureGoalColor
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "Temp"
                color: Theme.textSecondaryColor
                font: Theme.bodyFont
            }
        }
    }
}
