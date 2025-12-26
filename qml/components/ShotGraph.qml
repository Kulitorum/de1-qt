import QtQuick
import QtCharts
import DecenzaDE1

ChartView {
    id: chart
    antialiasing: true
    backgroundColor: "transparent"
    plotAreaColor: Qt.darker(Theme.surfaceColor, 1.3)
    legend.visible: false

    margins.top: 10
    margins.bottom: 60
    margins.left: 10
    margins.right: 10

    // Register series with C++ model on completion
    Component.onCompleted: {
        ShotDataModel.registerSeries(
            pressureSeries, flowSeries, temperatureSeries,
            pressureGoalSeries, flowGoalSeries, temperatureGoalSeries,
            weightSeries, extractionStartMarker,
            [frameMarker1, frameMarker2, frameMarker3, frameMarker4, frameMarker5,
             frameMarker6, frameMarker7, frameMarker8, frameMarker9, frameMarker10]
        )
    }

    // Time axis - bound to C++ maxTime property
    ValueAxis {
        id: timeAxis
        min: 0
        max: ShotDataModel.maxTime
        tickCount: Math.min(7, Math.max(3, Math.floor(ShotDataModel.maxTime / 10) + 2))
        labelFormat: "%.0f"
        labelsColor: Theme.textSecondaryColor
        gridLineColor: Qt.rgba(255, 255, 255, 0.1)
        titleText: "Time (s)"
        titleBrush: Theme.textSecondaryColor

        Behavior on max {
            NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
        }
    }

    // Pressure/Flow axis (left Y)
    ValueAxis {
        id: pressureAxis
        min: 0
        max: 12
        tickCount: 5
        labelFormat: "%.0f"
        labelsColor: Theme.textSecondaryColor
        gridLineColor: Qt.rgba(255, 255, 255, 0.1)
        titleText: "bar / mL/s"
        titleBrush: Theme.textSecondaryColor
    }

    // Temperature axis (right Y)
    ValueAxis {
        id: tempAxis
        min: 80
        max: 100
        tickCount: 5
        labelFormat: "%.0f"
        labelsColor: Theme.temperatureColor
        gridLineColor: "transparent"
        titleText: "°C"
        titleBrush: Theme.temperatureColor
    }

    // === PHASE MARKER LINES ===

    LineSeries {
        id: extractionStartMarker
        name: ""
        color: Theme.accentColor
        width: 2
        style: Qt.DashDotLine
        axisX: timeAxis
        axisY: pressureAxis
    }

    LineSeries { id: frameMarker1; name: ""; color: Qt.rgba(255,255,255,0.4); width: 1; style: Qt.DotLine; axisX: timeAxis; axisY: pressureAxis }
    LineSeries { id: frameMarker2; name: ""; color: Qt.rgba(255,255,255,0.4); width: 1; style: Qt.DotLine; axisX: timeAxis; axisY: pressureAxis }
    LineSeries { id: frameMarker3; name: ""; color: Qt.rgba(255,255,255,0.4); width: 1; style: Qt.DotLine; axisX: timeAxis; axisY: pressureAxis }
    LineSeries { id: frameMarker4; name: ""; color: Qt.rgba(255,255,255,0.4); width: 1; style: Qt.DotLine; axisX: timeAxis; axisY: pressureAxis }
    LineSeries { id: frameMarker5; name: ""; color: Qt.rgba(255,255,255,0.4); width: 1; style: Qt.DotLine; axisX: timeAxis; axisY: pressureAxis }
    LineSeries { id: frameMarker6; name: ""; color: Qt.rgba(255,255,255,0.4); width: 1; style: Qt.DotLine; axisX: timeAxis; axisY: pressureAxis }
    LineSeries { id: frameMarker7; name: ""; color: Qt.rgba(255,255,255,0.4); width: 1; style: Qt.DotLine; axisX: timeAxis; axisY: pressureAxis }
    LineSeries { id: frameMarker8; name: ""; color: Qt.rgba(255,255,255,0.4); width: 1; style: Qt.DotLine; axisX: timeAxis; axisY: pressureAxis }
    LineSeries { id: frameMarker9; name: ""; color: Qt.rgba(255,255,255,0.4); width: 1; style: Qt.DotLine; axisX: timeAxis; axisY: pressureAxis }
    LineSeries { id: frameMarker10; name: ""; color: Qt.rgba(255,255,255,0.4); width: 1; style: Qt.DotLine; axisX: timeAxis; axisY: pressureAxis }

    // === GOAL LINES (dashed) ===

    LineSeries {
        id: pressureGoalSeries
        name: "P Goal"
        color: Theme.pressureGoalColor
        width: 2
        style: Qt.DashLine
        axisX: timeAxis
        axisY: pressureAxis
    }

    LineSeries {
        id: flowGoalSeries
        name: "F Goal"
        color: Theme.flowGoalColor
        width: 2
        style: Qt.DashLine
        axisX: timeAxis
        axisY: pressureAxis
    }

    LineSeries {
        id: temperatureGoalSeries
        name: "T Goal"
        color: Theme.temperatureGoalColor
        width: 2
        style: Qt.DashLine
        axisX: timeAxis
        axisYRight: tempAxis
    }

    // === ACTUAL LINES (solid) ===

    LineSeries {
        id: pressureSeries
        name: "Pressure"
        color: Theme.pressureColor
        width: 3
        axisX: timeAxis
        axisY: pressureAxis
    }

    LineSeries {
        id: flowSeries
        name: "Flow"
        color: Theme.flowColor
        width: 3
        axisX: timeAxis
        axisY: pressureAxis
    }

    LineSeries {
        id: temperatureSeries
        name: "Temp"
        color: Theme.temperatureColor
        width: 3
        axisX: timeAxis
        axisYRight: tempAxis
    }

    LineSeries {
        id: weightSeries
        name: "Weight"
        color: Theme.weightColor
        width: 3
        axisX: timeAxis
        axisY: pressureAxis
    }

    // Frame marker labels
    Repeater {
        id: markerLabels
        model: ShotDataModel.phaseMarkers

        delegate: Item {
            property double markerTime: modelData.time
            property string markerLabel: modelData.label
            property bool isStart: modelData.label === "Start"

            x: chart.plotArea.x + (markerTime / ShotDataModel.maxTime) * chart.plotArea.width
            y: chart.plotArea.y
            height: chart.plotArea.height
            visible: markerTime <= ShotDataModel.maxTime && markerTime >= 0

            Text {
                text: markerLabel
                font.pixelSize: 18
                font.bold: isStart
                color: isStart ? Theme.accentColor : Qt.rgba(255, 255, 255, 0.8)
                rotation: -90
                transformOrigin: Item.TopLeft
                x: 4
                y: 8 + width

                Rectangle {
                    z: -1
                    anchors.fill: parent
                    anchors.margins: -2
                    color: Qt.darker(Theme.surfaceColor, 1.5)
                    radius: 2
                }
            }
        }
    }

    // Custom legend
    Column {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8
        spacing: 4

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 24

            Row {
                spacing: 6
                Rectangle { width: 24; height: 4; radius: 2; color: Theme.pressureColor; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Pressure"; color: Theme.textSecondaryColor; font.pixelSize: 13 }
            }
            Row {
                spacing: 6
                Rectangle { width: 24; height: 4; radius: 2; color: Theme.flowColor; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Flow"; color: Theme.textSecondaryColor; font.pixelSize: 13 }
            }
            Row {
                spacing: 6
                Rectangle { width: 24; height: 4; radius: 2; color: Theme.temperatureColor; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Temp"; color: Theme.textSecondaryColor; font.pixelSize: 13 }
            }
            Row {
                spacing: 6
                Rectangle { width: 24; height: 4; radius: 2; color: Theme.weightColor; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Weight"; color: Theme.textSecondaryColor; font.pixelSize: 13 }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Solid = actual  · · · Dashed = target"
            color: Qt.rgba(255, 255, 255, 0.5)
            font.pixelSize: 11
        }
    }
}
