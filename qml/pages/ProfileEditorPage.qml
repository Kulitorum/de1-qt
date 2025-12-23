import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DE1App
import "../components"

Page {
    id: profileEditorPage
    objectName: "profileEditorPage"
    background: Rectangle { color: Theme.backgroundColor }

    property var profile: null
    property int selectedStepIndex: -1

    function updatePageTitle() {
        root.currentPageTitle = profile ? profile.title : "Profile Editor"
    }

    // Auto-upload profile to machine on any change
    function uploadProfile() {
        if (profile) {
            MainController.uploadProfile(profile)
        }
    }

    // Main content area
    Item {
        anchors.top: parent.top
        anchors.topMargin: Theme.scaled(60)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomBar.top
        anchors.leftMargin: Theme.standardMargin
        anchors.rightMargin: Theme.standardMargin

        RowLayout {
            anchors.fill: parent
            spacing: Theme.scaled(15)

            // Left side: Profile graph with frame visualization
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Theme.surfaceColor
                radius: Theme.cardRadius

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.scaled(10)
                    spacing: Theme.scaled(10)

                    // Frame toolbar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.scaled(10)

                        Text {
                            text: "Frames"
                            font: Theme.subtitleFont
                            color: Theme.textColor
                        }

                        Item { Layout.fillWidth: true }

                        ActionButton {
                            Layout.preferredWidth: Theme.scaled(100)
                            Layout.preferredHeight: Theme.scaled(36)
                            text: "+ Add"
                            backgroundColor: Theme.accentColor
                            onClicked: addStep()
                        }

                        ActionButton {
                            Layout.preferredWidth: Theme.scaled(100)
                            Layout.preferredHeight: Theme.scaled(36)
                            text: "Delete"
                            backgroundColor: Theme.errorColor
                            enabled: selectedStepIndex >= 0
                            opacity: enabled ? 1.0 : 0.5
                            onClicked: deleteStep(selectedStepIndex)
                        }

                        ActionButton {
                            Layout.preferredWidth: Theme.scaled(36)
                            Layout.preferredHeight: Theme.scaled(36)
                            text: "\u2191"
                            backgroundColor: Theme.primaryColor
                            enabled: selectedStepIndex > 0
                            opacity: enabled ? 1.0 : 0.5
                            onClicked: moveStep(selectedStepIndex, selectedStepIndex - 1)
                        }

                        ActionButton {
                            Layout.preferredWidth: Theme.scaled(36)
                            Layout.preferredHeight: Theme.scaled(36)
                            text: "\u2193"
                            backgroundColor: Theme.primaryColor
                            enabled: selectedStepIndex >= 0 && selectedStepIndex < (profile ? profile.steps.length - 1 : 0)
                            opacity: enabled ? 1.0 : 0.5
                            onClicked: moveStep(selectedStepIndex, selectedStepIndex + 1)
                        }
                    }

                    // Profile graph
                    ProfileGraph {
                        id: profileGraph
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        frames: profile ? profile.steps : []
                        selectedFrameIndex: selectedStepIndex

                        onFrameSelected: function(index) {
                            selectedStepIndex = index
                        }
                    }
                }
            }

            // Right side: Frame editor panel
            Rectangle {
                Layout.preferredWidth: Theme.scaled(320)
                Layout.fillHeight: true
                color: Theme.surfaceColor
                radius: Theme.cardRadius

                Loader {
                    anchors.fill: parent
                    anchors.margins: Theme.scaled(15)
                    sourceComponent: selectedStepIndex >= 0 ? stepEditorComponent : noSelectionComponent
                }
            }
        }
    }

    // Bottom bar
    Rectangle {
        id: bottomBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.scaled(70)
        color: Theme.surfaceColor

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.scaled(10)
            anchors.rightMargin: Theme.scaled(20)
            spacing: Theme.scaled(15)

            // Back button
            RoundButton {
                Layout.preferredWidth: Theme.scaled(50)
                Layout.preferredHeight: Theme.scaled(50)
                icon.source: "qrc:/icons/back.svg"
                icon.width: Theme.scaled(28)
                icon.height: Theme.scaled(28)
                flat: true
                icon.color: Theme.textColor
                onClicked: root.goToIdle()
            }

            // Target weight
            RowLayout {
                spacing: Theme.scaled(10)

                Text {
                    text: "Target:"
                    color: Theme.textSecondaryColor
                    font: Theme.bodyFont
                }

                Slider {
                    id: targetWeightSlider
                    Layout.preferredWidth: Theme.scaled(200)
                    from: 20
                    to: 60
                    stepSize: 1
                    value: profile ? profile.target_weight : 36
                    onMoved: {
                        if (profile) {
                            profile.target_weight = value
                            MainController.targetWeight = value
                            uploadProfile()
                        }
                    }
                }

                Text {
                    text: targetWeightSlider.value.toFixed(0) + "g"
                    color: Theme.weightColor
                    font: Theme.bodyFont
                    Layout.preferredWidth: Theme.scaled(40)
                }
            }

            Item { Layout.fillWidth: true }

            // Info text
            Text {
                text: profile ? profile.steps.length + " frames" : ""
                color: Theme.textSecondaryColor
                font: Theme.captionFont
            }
        }
    }

    // No selection placeholder
    Component {
        id: noSelectionComponent

        Item {
            Column {
                anchors.centerIn: parent
                spacing: Theme.scaled(15)

                Text {
                    text: "Select a frame"
                    font: Theme.titleFont
                    color: Theme.textSecondaryColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Click on the graph to select\na frame for editing"
                    font: Theme.bodyFont
                    color: Theme.textSecondaryColor
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    // Frame editor component
    Component {
        id: stepEditorComponent

        ScrollView {
            id: stepEditorScroll
            clip: true

            property var step: profile && selectedStepIndex >= 0 && selectedStepIndex < profile.steps.length ?
                              profile.steps[selectedStepIndex] : null

            ColumnLayout {
                width: stepEditorScroll.width - Theme.scaled(10)
                spacing: Theme.scaled(15)

                // Frame name
                TextField {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.scaled(45)
                    text: step ? step.name : ""
                    placeholderText: "Frame name"
                    font: Theme.titleFont
                    color: Theme.textColor
                    background: Rectangle {
                        color: Qt.rgba(255, 255, 255, 0.1)
                        radius: Theme.scaled(4)
                    }
                    onTextChanged: {
                        if (step && step.name !== text) {
                            step.name = text
                            profileGraph.framesChanged()
                            uploadProfile()
                        }
                    }
                }

                // Pump mode
                GroupBox {
                    Layout.fillWidth: true
                    title: "Pump Mode"
                    background: Rectangle {
                        color: Qt.rgba(255, 255, 255, 0.05)
                        radius: Theme.scaled(8)
                        y: parent.topPadding - parent.padding
                        width: parent.width
                        height: parent.height - parent.topPadding + parent.padding
                    }
                    label: Text {
                        text: parent.title
                        font: Theme.captionFont
                        color: Theme.textSecondaryColor
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: Theme.scaled(20)

                        RadioButton {
                            text: "Pressure"
                            checked: step && step.pump === "pressure"
                            onCheckedChanged: {
                                if (checked && step && step.pump !== "pressure") {
                                    step.pump = "pressure"
                                    profileGraph.framesChanged()
                                    uploadProfile()
                                }
                            }
                        }

                        RadioButton {
                            text: "Flow"
                            checked: step && step.pump === "flow"
                            onCheckedChanged: {
                                if (checked && step && step.pump !== "flow") {
                                    step.pump = "flow"
                                    profileGraph.framesChanged()
                                    uploadProfile()
                                }
                            }
                        }
                    }
                }

                // Setpoint value (pressure or flow)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.scaled(8)

                    Text {
                        text: step && step.pump === "flow" ? "Flow (mL/s)" : "Pressure (bar)"
                        font: Theme.captionFont
                        color: Theme.textSecondaryColor
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.scaled(15)

                        Slider {
                            id: setpointSlider
                            Layout.fillWidth: true
                            from: 0
                            to: step && step.pump === "flow" ? 8 : 12
                            value: step ? (step.pump === "flow" ? step.flow : step.pressure) : 0
                            stepSize: 0.1
                            onMoved: {
                                if (step) {
                                    if (step.pump === "flow") {
                                        step.flow = value
                                    } else {
                                        step.pressure = value
                                    }
                                    profileGraph.framesChanged()
                                    uploadProfile()
                                }
                            }
                        }

                        Text {
                            text: setpointSlider.value.toFixed(1)
                            font: Theme.bodyFont
                            color: step && step.pump === "flow" ? Theme.flowColor : Theme.pressureColor
                            Layout.preferredWidth: Theme.scaled(40)
                        }
                    }
                }

                // Temperature
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.scaled(8)

                    Text {
                        text: "Temperature (\u00B0C)"
                        font: Theme.captionFont
                        color: Theme.textSecondaryColor
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.scaled(15)

                        Slider {
                            id: tempSlider
                            Layout.fillWidth: true
                            from: 70
                            to: 100
                            value: step ? step.temperature : 93
                            stepSize: 0.5
                            onMoved: {
                                if (step) {
                                    step.temperature = value
                                    profileGraph.framesChanged()
                                    uploadProfile()
                                }
                            }
                        }

                        Text {
                            text: tempSlider.value.toFixed(1)
                            font: Theme.bodyFont
                            color: Theme.temperatureColor
                            Layout.preferredWidth: Theme.scaled(40)
                        }
                    }
                }

                // Duration
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.scaled(8)

                    Text {
                        text: "Duration (seconds)"
                        font: Theme.captionFont
                        color: Theme.textSecondaryColor
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.scaled(15)

                        Slider {
                            id: durationSlider
                            Layout.fillWidth: true
                            from: 1
                            to: 120
                            value: step ? step.seconds : 30
                            stepSize: 1
                            onMoved: {
                                if (step) {
                                    step.seconds = value
                                    profileGraph.framesChanged()
                                    uploadProfile()
                                }
                            }
                        }

                        Text {
                            text: durationSlider.value.toFixed(0) + "s"
                            font: Theme.bodyFont
                            color: Theme.textColor
                            Layout.preferredWidth: Theme.scaled(40)
                        }
                    }
                }

                // Transition
                GroupBox {
                    Layout.fillWidth: true
                    title: "Transition"
                    background: Rectangle {
                        color: Qt.rgba(255, 255, 255, 0.05)
                        radius: Theme.scaled(8)
                        y: parent.topPadding - parent.padding
                        width: parent.width
                        height: parent.height - parent.topPadding + parent.padding
                    }
                    label: Text {
                        text: parent.title
                        font: Theme.captionFont
                        color: Theme.textSecondaryColor
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: Theme.scaled(20)

                        RadioButton {
                            text: "Fast"
                            checked: step && step.transition === "fast"
                            onCheckedChanged: {
                                if (checked && step && step.transition !== "fast") {
                                    step.transition = "fast"
                                    profileGraph.framesChanged()
                                    uploadProfile()
                                }
                            }
                        }

                        RadioButton {
                            text: "Smooth"
                            checked: step && step.transition === "smooth"
                            onCheckedChanged: {
                                if (checked && step && step.transition !== "smooth") {
                                    step.transition = "smooth"
                                    profileGraph.framesChanged()
                                    uploadProfile()
                                }
                            }
                        }
                    }
                }

                // Exit conditions (collapsible)
                GroupBox {
                    Layout.fillWidth: true
                    title: "Exit Condition"
                    background: Rectangle {
                        color: Qt.rgba(255, 255, 255, 0.05)
                        radius: Theme.scaled(8)
                        y: parent.topPadding - parent.padding
                        width: parent.width
                        height: parent.height - parent.topPadding + parent.padding
                    }
                    label: Text {
                        text: parent.title
                        font: Theme.captionFont
                        color: Theme.textSecondaryColor
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Theme.scaled(10)

                        CheckBox {
                            id: exitIfCheck
                            text: "Enable early exit"
                            checked: step ? step.exit_if : false
                            onCheckedChanged: {
                                if (step && step.exit_if !== checked) {
                                    step.exit_if = checked
                                    uploadProfile()
                                }
                            }
                        }

                        ComboBox {
                            Layout.fillWidth: true
                            enabled: exitIfCheck.checked
                            model: ["Pressure Over", "Pressure Under", "Flow Over", "Flow Under"]
                            currentIndex: {
                                if (!step) return 0
                                switch (step.exit_type) {
                                    case "pressure_over": return 0
                                    case "pressure_under": return 1
                                    case "flow_over": return 2
                                    case "flow_under": return 3
                                    default: return 0
                                }
                            }
                            onCurrentIndexChanged: {
                                if (!step) return
                                var types = ["pressure_over", "pressure_under", "flow_over", "flow_under"]
                                if (step.exit_type !== types[currentIndex]) {
                                    step.exit_type = types[currentIndex]
                                    uploadProfile()
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            enabled: exitIfCheck.checked
                            spacing: Theme.scaled(10)

                            Slider {
                                id: exitValueSlider
                                Layout.fillWidth: true
                                from: 0
                                to: step && (step.exit_type === "flow_over" || step.exit_type === "flow_under") ? 8 : 12
                                value: {
                                    if (!step) return 0
                                    switch (step.exit_type) {
                                        case "pressure_over": return step.exit_pressure_over || 0
                                        case "pressure_under": return step.exit_pressure_under || 0
                                        case "flow_over": return step.exit_flow_over || 0
                                        case "flow_under": return step.exit_flow_under || 0
                                        default: return 0
                                    }
                                }
                                stepSize: 0.1
                                onMoved: {
                                    if (!step) return
                                    switch (step.exit_type) {
                                        case "pressure_over": step.exit_pressure_over = value; break
                                        case "pressure_under": step.exit_pressure_under = value; break
                                        case "flow_over": step.exit_flow_over = value; break
                                        case "flow_under": step.exit_flow_under = value; break
                                    }
                                    uploadProfile()
                                }
                            }

                            Text {
                                text: exitValueSlider.value.toFixed(1)
                                font: Theme.bodyFont
                                color: Theme.textColor
                                Layout.preferredWidth: Theme.scaled(40)
                            }
                        }
                    }
                }

                // Limiter (max pressure when flow-controlled, or max flow when pressure-controlled)
                GroupBox {
                    Layout.fillWidth: true
                    title: step && step.pump === "flow" ? "Max Pressure Limiter" : "Max Flow Limiter"
                    background: Rectangle {
                        color: Qt.rgba(255, 255, 255, 0.05)
                        radius: Theme.scaled(8)
                        y: parent.topPadding - parent.padding
                        width: parent.width
                        height: parent.height - parent.topPadding + parent.padding
                    }
                    label: Text {
                        text: parent.title
                        font: Theme.captionFont
                        color: Theme.textSecondaryColor
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: Theme.scaled(10)

                        Slider {
                            id: limiterSlider
                            Layout.fillWidth: true
                            from: 0
                            to: step && step.pump === "flow" ? 12 : 8
                            value: step ? step.max_flow_or_pressure : 0
                            stepSize: 0.1
                            onMoved: {
                                if (step) {
                                    step.max_flow_or_pressure = value
                                    uploadProfile()
                                }
                            }
                        }

                        Text {
                            text: limiterSlider.value > 0 ?
                                  limiterSlider.value.toFixed(1) + (step && step.pump === "flow" ? " bar" : " mL/s") :
                                  "Off"
                            font: Theme.bodyFont
                            color: limiterSlider.value > 0 ? Theme.warningColor : Theme.textSecondaryColor
                            Layout.preferredWidth: Theme.scaled(60)
                        }
                    }
                }

                // Spacer
                Item { Layout.fillHeight: true }
            }
        }
    }

    // Profile name edit dialog
    Dialog {
        id: profileNameDialog
        title: "Edit Profile Name"
        anchors.centerIn: parent
        width: Theme.scaled(400)
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel

        TextField {
            id: nameField
            width: parent.width
            text: profile ? profile.title : ""
            font: Theme.bodyFont
        }

        onAccepted: {
            if (profile && nameField.text.length > 0) {
                profile.title = nameField.text
                updatePageTitle()
                uploadProfile()
            }
        }

        onOpened: {
            nameField.text = profile ? profile.title : ""
            nameField.selectAll()
            nameField.forceActiveFocus()
        }
    }

    // Helper functions
    function addStep() {
        if (!profile) return

        var newStep = {
            name: "Frame " + (profile.steps.length + 1),
            temperature: 93.0,
            sensor: "coffee",
            pump: "pressure",
            transition: "fast",
            pressure: 9.0,
            flow: 2.0,
            seconds: 30.0,
            volume: 0,
            exit_if: false,
            exit_type: "pressure_over",
            exit_pressure_over: 0,
            exit_pressure_under: 0,
            exit_flow_over: 0,
            exit_flow_under: 0,
            max_flow_or_pressure: 0,
            max_flow_or_pressure_range: 0.6
        }

        // Insert after selected frame, or at end
        var insertIndex = selectedStepIndex >= 0 ? selectedStepIndex + 1 : profile.steps.length
        profile.steps.splice(insertIndex, 0, newStep)
        selectedStepIndex = insertIndex
        profileGraph.framesChanged()
        uploadProfile()
    }

    function deleteStep(index) {
        if (!profile || index < 0 || index >= profile.steps.length) return

        profile.steps.splice(index, 1)

        if (selectedStepIndex >= profile.steps.length) {
            selectedStepIndex = profile.steps.length - 1
        }

        profileGraph.framesChanged()
        uploadProfile()
    }

    function moveStep(fromIndex, toIndex) {
        if (!profile || fromIndex < 0 || fromIndex >= profile.steps.length) return
        if (toIndex < 0 || toIndex >= profile.steps.length) return

        var step = profile.steps.splice(fromIndex, 1)[0]
        profile.steps.splice(toIndex, 0, step)
        selectedStepIndex = toIndex
        profileGraph.framesChanged()
        uploadProfile()
    }

    Component.onCompleted: {
        // Load current profile if not set
        if (!profile) {
            profile = {
                title: MainController.currentProfileName || "New Profile",
                steps: [],
                target_weight: MainController.targetWeight || 36,
                espresso_temperature: 93,
                mode: "frame_based"
            }
            // Try to load actual profile data
            var loadedProfile = MainController.getCurrentProfile()
            if (loadedProfile) {
                profile = loadedProfile
            }
        }
        updatePageTitle()
    }
}
