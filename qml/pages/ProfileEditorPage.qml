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
    property bool profileModified: false
    property string originalProfileName: ""
    property int stepVersion: 0  // Increment to force step editor refresh

    function updatePageTitle() {
        root.currentPageTitle = profile ? profile.title : "Profile Editor"
    }

    // Auto-upload profile to machine on any change
    function uploadProfile() {
        if (profile) {
            MainController.uploadProfile(profile)
            profileModified = true
            // Force step editor bindings to re-evaluate
            stepVersion++
            // Force graph to update by creating a new array reference
            // (assigning same reference doesn't trigger onFramesChanged)
            profileGraph.frames = profile.steps.slice()
        }
    }

    // Save profile to file
    function saveProfile() {
        if (profile && originalProfileName) {
            MainController.saveProfile(originalProfileName)
            profileModified = false
        }
    }

    // Save profile with new name
    function saveProfileAs(filename, title) {
        if (profile) {
            MainController.saveProfileAs(filename, title)
            originalProfileName = filename
            profileModified = false
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

                        Button {
                            text: "+ Add"
                            onClicked: addStep()
                            background: Rectangle {
                                implicitWidth: Theme.scaled(80)
                                implicitHeight: Theme.scaled(32)
                                radius: Theme.scaled(6)
                                color: parent.down ? Qt.darker(Theme.accentColor, 1.2) : Theme.accentColor
                            }
                            contentItem: Text {
                                text: parent.text
                                font: Theme.bodyFont
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Button {
                            text: "Delete"
                            enabled: selectedStepIndex >= 0
                            onClicked: deleteStep(selectedStepIndex)
                            background: Rectangle {
                                implicitWidth: Theme.scaled(80)
                                implicitHeight: Theme.scaled(32)
                                radius: Theme.scaled(6)
                                color: parent.down ? Qt.darker(Theme.errorColor, 1.2) : Theme.errorColor
                                opacity: parent.enabled ? 1.0 : 0.4
                            }
                            contentItem: Text {
                                text: parent.text
                                font: Theme.bodyFont
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                opacity: parent.enabled ? 1.0 : 0.5
                            }
                        }

                        Button {
                            text: "\u2190"
                            enabled: selectedStepIndex > 0
                            onClicked: moveStep(selectedStepIndex, selectedStepIndex - 1)
                            background: Rectangle {
                                implicitWidth: Theme.scaled(36)
                                implicitHeight: Theme.scaled(32)
                                radius: Theme.scaled(6)
                                color: parent.down ? Qt.darker(Theme.primaryColor, 1.2) : Theme.primaryColor
                                opacity: parent.enabled ? 1.0 : 0.4
                            }
                            contentItem: Text {
                                text: parent.text
                                font.pixelSize: Theme.scaled(18)
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                opacity: parent.enabled ? 1.0 : 0.5
                            }
                        }

                        Button {
                            text: "\u2192"
                            enabled: selectedStepIndex >= 0 && selectedStepIndex < (profile ? profile.steps.length - 1 : 0)
                            onClicked: moveStep(selectedStepIndex, selectedStepIndex + 1)
                            background: Rectangle {
                                implicitWidth: Theme.scaled(36)
                                implicitHeight: Theme.scaled(32)
                                radius: Theme.scaled(6)
                                color: parent.down ? Qt.darker(Theme.primaryColor, 1.2) : Theme.primaryColor
                                opacity: parent.enabled ? 1.0 : 0.4
                            }
                            contentItem: Text {
                                text: parent.text
                                font.pixelSize: Theme.scaled(18)
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                opacity: parent.enabled ? 1.0 : 0.5
                            }
                        }
                    }

                    // Profile graph
                    ProfileGraph {
                        id: profileGraph
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.bottomMargin: Theme.scaled(30)  // Space for legend
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
                    text: "Target weight:"
                    color: Theme.textSecondaryColor
                    font: Theme.bodyFont
                }

                TouchSlider {
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

            // Modified indicator
            Text {
                text: profileModified ? "Modified" : ""
                color: Theme.warningColor
                font: Theme.captionFont
                visible: profileModified
            }

            // Info text
            Text {
                text: profile ? profile.steps.length + " frames" : ""
                color: Theme.textSecondaryColor
                font: Theme.captionFont
            }

            // Save button
            Button {
                text: "Save"
                enabled: profileModified && originalProfileName !== ""
                onClicked: saveProfile()
                background: Rectangle {
                    implicitWidth: Theme.scaled(80)
                    implicitHeight: Theme.scaled(40)
                    radius: Theme.scaled(8)
                    color: parent.down ? Qt.darker(Theme.primaryColor, 1.2) : Theme.primaryColor
                    opacity: parent.enabled ? 1.0 : 0.4
                }
                contentItem: Text {
                    text: parent.text
                    font: Theme.bodyFont
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Save As button
            Button {
                text: "Save As..."
                onClicked: saveAsDialog.open()
                background: Rectangle {
                    implicitWidth: Theme.scaled(100)
                    implicitHeight: Theme.scaled(40)
                    radius: Theme.scaled(8)
                    color: parent.down ? Qt.darker(Theme.accentColor, 1.2) : Theme.accentColor
                }
                contentItem: Text {
                    text: parent.text
                    font: Theme.bodyFont
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // Save As dialog
    Dialog {
        id: saveAsDialog
        title: "Save Profile As"
        anchors.centerIn: parent
        width: Theme.scaled(400)
        modal: true
        standardButtons: Dialog.Save | Dialog.Cancel

        ColumnLayout {
            width: parent.width
            spacing: Theme.scaled(15)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.scaled(5)

                Text {
                    text: "Profile Title"
                    font: Theme.captionFont
                    color: Theme.textSecondaryColor
                }

                TextField {
                    id: saveAsTitleField
                    Layout.fillWidth: true
                    text: profile ? profile.title : ""
                    font: Theme.bodyFont
                    placeholderText: "Enter profile title"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.scaled(5)

                Text {
                    text: "Filename"
                    font: Theme.captionFont
                    color: Theme.textSecondaryColor
                }

                TextField {
                    id: saveAsFilenameField
                    Layout.fillWidth: true
                    text: originalProfileName || "my_profile"
                    font: Theme.bodyFont
                    placeholderText: "Enter filename (without .json)"
                    validator: RegularExpressionValidator { regularExpression: /[a-zA-Z0-9_-]+/ }
                }
            }
        }

        onAccepted: {
            if (saveAsFilenameField.text.length > 0 && saveAsTitleField.text.length > 0) {
                saveProfileAs(saveAsFilenameField.text, saveAsTitleField.text)
            }
        }

        onOpened: {
            saveAsTitleField.text = profile ? profile.title : ""
            saveAsFilenameField.text = originalProfileName || "my_profile"
            saveAsTitleField.forceActiveFocus()
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

            // Reference stepVersion to force re-evaluation when it changes
            property var step: {
                stepVersion  // Dependency trigger
                return profile && selectedStepIndex >= 0 && selectedStepIndex < profile.steps.length ?
                       profile.steps[selectedStepIndex] : null
            }

            ColumnLayout {
                width: stepEditorScroll.width - Theme.scaled(10)
                spacing: Theme.scaled(15)

                // Frame name
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.scaled(4)

                    Text {
                        text: "Frame Name"
                        font: Theme.captionFont
                        color: Theme.textSecondaryColor
                    }

                    TextField {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.scaled(45)
                        text: step ? step.name : ""
                        font: Theme.titleFont
                        color: Theme.textColor
                        placeholderTextColor: Theme.textSecondaryColor
                        background: Rectangle {
                            color: Qt.rgba(255, 255, 255, 0.1)
                            radius: Theme.scaled(4)
                        }
                        onTextChanged: {
                            if (profile && selectedStepIndex >= 0 && profile.steps[selectedStepIndex].name !== text) {
                                profile.steps[selectedStepIndex].name = text
                                uploadProfile()
                            }
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
                            contentItem: Text {
                                text: parent.text
                                font: Theme.bodyFont
                                color: Theme.textColor
                                leftPadding: parent.indicator.width + parent.spacing
                                verticalAlignment: Text.AlignVCenter
                            }
                            onCheckedChanged: {
                                if (checked && profile && selectedStepIndex >= 0 && profile.steps[selectedStepIndex].pump !== "pressure") {
                                    profile.steps[selectedStepIndex].pump = "pressure"
                                    uploadProfile()
                                }
                            }
                        }

                        RadioButton {
                            text: "Flow"
                            checked: step && step.pump === "flow"
                            contentItem: Text {
                                text: parent.text
                                font: Theme.bodyFont
                                color: Theme.textColor
                                leftPadding: parent.indicator.width + parent.spacing
                                verticalAlignment: Text.AlignVCenter
                            }
                            onCheckedChanged: {
                                if (checked && profile && selectedStepIndex >= 0 && profile.steps[selectedStepIndex].pump !== "flow") {
                                    profile.steps[selectedStepIndex].pump = "flow"
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

                        TouchSlider {
                            id: setpointSlider
                            Layout.fillWidth: true
                            from: 0
                            to: step && step.pump === "flow" ? 8 : 12
                            value: step ? (step.pump === "flow" ? step.flow : step.pressure) : 0
                            stepSize: 0.1
                            handleColor: step && step.pump === "flow" ? Theme.flowGoalColor : Theme.pressureGoalColor
                            progressColor: step && step.pump === "flow" ? Theme.flowGoalColor : Theme.pressureGoalColor
                            onMoved: {
                                if (profile && selectedStepIndex >= 0) {
                                    if (profile.steps[selectedStepIndex].pump === "flow") {
                                        profile.steps[selectedStepIndex].flow = value
                                    } else {
                                        profile.steps[selectedStepIndex].pressure = value
                                    }
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

                        TouchSlider {
                            id: tempSlider
                            Layout.fillWidth: true
                            from: 70
                            to: 100
                            value: step ? step.temperature : 93
                            stepSize: 0.5
                            handleColor: Theme.temperatureGoalColor
                            progressColor: Theme.temperatureGoalColor
                            onMoved: {
                                if (profile && selectedStepIndex >= 0) {
                                    profile.steps[selectedStepIndex].temperature = value
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

                        TouchSlider {
                            id: durationSlider
                            Layout.fillWidth: true
                            from: 0
                            to: 120
                            value: step ? step.seconds : 30
                            stepSize: 1
                            handleColor: Theme.accentColor
                            progressColor: Theme.accentColor
                            onMoved: {
                                if (profile && selectedStepIndex >= 0) {
                                    profile.steps[selectedStepIndex].seconds = value
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
                            contentItem: Text {
                                text: parent.text
                                font: Theme.bodyFont
                                color: Theme.textColor
                                leftPadding: parent.indicator.width + parent.spacing
                                verticalAlignment: Text.AlignVCenter
                            }
                            onCheckedChanged: {
                                if (checked && profile && selectedStepIndex >= 0 && profile.steps[selectedStepIndex].transition !== "fast") {
                                    profile.steps[selectedStepIndex].transition = "fast"
                                    uploadProfile()
                                }
                            }
                        }

                        RadioButton {
                            text: "Smooth"
                            checked: step && step.transition === "smooth"
                            contentItem: Text {
                                text: parent.text
                                font: Theme.bodyFont
                                color: Theme.textColor
                                leftPadding: parent.indicator.width + parent.spacing
                                verticalAlignment: Text.AlignVCenter
                            }
                            onCheckedChanged: {
                                if (checked && profile && selectedStepIndex >= 0 && profile.steps[selectedStepIndex].transition !== "smooth") {
                                    profile.steps[selectedStepIndex].transition = "smooth"
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
                            contentItem: Text {
                                text: parent.text
                                font: Theme.bodyFont
                                color: Theme.textColor
                                leftPadding: parent.indicator.width + parent.spacing
                                verticalAlignment: Text.AlignVCenter
                            }
                            onCheckedChanged: {
                                if (profile && selectedStepIndex >= 0 && profile.steps[selectedStepIndex].exit_if !== checked) {
                                    profile.steps[selectedStepIndex].exit_if = checked
                                    uploadProfile()
                                }
                            }
                        }

                        ComboBox {
                            id: exitTypeCombo
                            Layout.fillWidth: true
                            enabled: exitIfCheck.checked
                            model: ["Pressure Over", "Pressure Under", "Flow Over", "Flow Under"]
                            contentItem: Text {
                                text: exitTypeCombo.displayText
                                font: Theme.bodyFont
                                color: Theme.textColor
                                leftPadding: Theme.scaled(10)
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                implicitHeight: Theme.scaled(36)
                                color: Qt.rgba(255, 255, 255, 0.1)
                                radius: Theme.scaled(6)
                            }
                            popup: Popup {
                                y: exitTypeCombo.height
                                width: exitTypeCombo.width
                                padding: 1
                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: contentHeight
                                    model: exitTypeCombo.popup.visible ? exitTypeCombo.delegateModel : null
                                    ScrollIndicator.vertical: ScrollIndicator {}
                                }
                                background: Rectangle {
                                    color: Theme.surfaceColor
                                    radius: Theme.scaled(6)
                                }
                            }
                            delegate: ItemDelegate {
                                width: exitTypeCombo.width
                                contentItem: Text {
                                    text: modelData
                                    font: Theme.bodyFont
                                    color: Theme.textColor
                                }
                                background: Rectangle {
                                    color: highlighted ? Theme.primaryColor : "transparent"
                                }
                                highlighted: exitTypeCombo.highlightedIndex === index
                            }
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
                                if (!profile || selectedStepIndex < 0) return
                                var types = ["pressure_over", "pressure_under", "flow_over", "flow_under"]
                                if (profile.steps[selectedStepIndex].exit_type !== types[currentIndex]) {
                                    profile.steps[selectedStepIndex].exit_type = types[currentIndex]
                                    uploadProfile()
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            enabled: exitIfCheck.checked
                            spacing: Theme.scaled(10)

                            TouchSlider {
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
                                    if (!profile || selectedStepIndex < 0) return
                                    var s = profile.steps[selectedStepIndex]
                                    switch (s.exit_type) {
                                        case "pressure_over": profile.steps[selectedStepIndex].exit_pressure_over = value; break
                                        case "pressure_under": profile.steps[selectedStepIndex].exit_pressure_under = value; break
                                        case "flow_over": profile.steps[selectedStepIndex].exit_flow_over = value; break
                                        case "flow_under": profile.steps[selectedStepIndex].exit_flow_under = value; break
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

                        TouchSlider {
                            id: limiterSlider
                            Layout.fillWidth: true
                            from: 0
                            to: step && step.pump === "flow" ? 12 : 8
                            value: step ? step.max_flow_or_pressure : 0
                            stepSize: 0.1
                            onMoved: {
                                if (profile && selectedStepIndex >= 0) {
                                    profile.steps[selectedStepIndex].max_flow_or_pressure = value
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
        // Force graph update by reassigning frames array
        profileGraph.frames = []
        profileGraph.frames = profile.steps
        uploadProfile()
    }

    function deleteStep(index) {
        if (!profile || index < 0 || index >= profile.steps.length) return

        profile.steps.splice(index, 1)

        if (selectedStepIndex >= profile.steps.length) {
            selectedStepIndex = profile.steps.length - 1
        }

        // Force graph update by reassigning frames array
        profileGraph.frames = []
        profileGraph.frames = profile.steps
        uploadProfile()
    }

    function moveStep(fromIndex, toIndex) {
        if (!profile || fromIndex < 0 || fromIndex >= profile.steps.length) return
        if (toIndex < 0 || toIndex >= profile.steps.length) return

        var step = profile.steps.splice(fromIndex, 1)[0]
        profile.steps.splice(toIndex, 0, step)
        // Force graph update by reassigning frames array
        profileGraph.frames = []
        profileGraph.frames = profile.steps
        // Update selection after frames are reassigned
        selectedStepIndex = toIndex
        profileGraph.selectedFrameIndex = toIndex
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
        // Track the original profile name for saving
        originalProfileName = MainController.currentProfileName || ""
        profileModified = false
        updatePageTitle()
    }
}
