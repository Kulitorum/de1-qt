import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DecenzaDE1
import "../components"

Page {
    id: shotMetadataPage
    objectName: "shotMetadataPage"
    background: Rectangle { color: Theme.backgroundColor }

    Component.onCompleted: root.currentPageTitle = "Shot Info"
    StackView.onActivated: root.currentPageTitle = "Shot Info"

    property bool hasPendingShot: true  // TODO: set to false for production
    property real keyboardOffset: 0

    function updateKeyboardOffset(field) {
        if (!field) return
        let fieldY = field.mapToItem(shotMetadataPage, 0, field.height).y
        let visibleHeight = shotMetadataPage.height - Qt.inputMethod.keyboardRectangle.height / Screen.devicePixelRatio
        if (fieldY > visibleHeight - 50) {
            keyboardOffset = fieldY - visibleHeight + 100
        }
    }

    // Announce upload status changes
    Connections {
        target: MainController.visualizer
        function onUploadingChanged() {
            if (AccessibilityManager.enabled) {
                if (MainController.visualizer.uploading) {
                    AccessibilityManager.announce("Uploading to Visualizer", true)
                }
            }
        }
        function onLastUploadStatusChanged() {
            if (AccessibilityManager.enabled && MainController.visualizer.lastUploadStatus.length > 0) {
                AccessibilityManager.announce(MainController.visualizer.lastUploadStatus, true)
            }
        }
    }

    Connections {
        target: Qt.inputMethod
        function onKeyboardRectangleChanged() {
            if (!Qt.inputMethod.visible) keyboardOffset = 0
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: Theme.pageTopMargin
        anchors.bottomMargin: Theme.bottomBarHeight
        anchors.leftMargin: Theme.standardMargin
        anchors.rightMargin: Theme.standardMargin
        contentHeight: mainColumn.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainColumn
            width: parent.width
            spacing: 6

            // 3-column grid for all fields
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: 8
                rowSpacing: 6

                // === ROW 1: Bean info ===
                LabeledField {
                    Layout.fillWidth: true
                    label: "Roaster"
                    text: Settings.dyeBeanBrand
                    onTextEdited: function(t) { Settings.dyeBeanBrand = t }
                }

                LabeledField {
                    Layout.fillWidth: true
                    label: "Coffee"
                    text: Settings.dyeBeanType
                    onTextEdited: function(t) { Settings.dyeBeanType = t }
                }

                LabeledField {
                    Layout.fillWidth: true
                    label: "Roast date"
                    text: Settings.dyeRoastDate
                    inputHints: Qt.ImhDate
                    onTextEdited: function(t) { Settings.dyeRoastDate = t }
                }

                // === ROW 2: Roast level, Grinder ===
                LabeledComboBox {
                    Layout.fillWidth: true
                    label: "Roast level"
                    model: ["", "Light", "Medium-Light", "Medium", "Medium-Dark", "Dark"]
                    currentValue: Settings.dyeRoastLevel
                    onValueChanged: function(v) { Settings.dyeRoastLevel = v }
                }

                LabeledField {
                    Layout.fillWidth: true
                    label: "Grinder"
                    text: Settings.dyeGrinderModel
                    onTextEdited: function(t) { Settings.dyeGrinderModel = t }
                }

                LabeledField {
                    Layout.fillWidth: true
                    label: "Setting"
                    text: Settings.dyeGrinderSetting
                    onTextEdited: function(t) { Settings.dyeGrinderSetting = t }
                }

                // === ROW 3: Measurements + Barista ===
                LabeledField {
                    Layout.fillWidth: true
                    label: "TDS %"
                    text: Settings.dyeDrinkTds > 0 ? Settings.dyeDrinkTds.toFixed(2) : ""
                    inputHints: Qt.ImhFormattedNumbersOnly
                    onTextEdited: function(t) {
                        let val = parseFloat(t)
                        Settings.dyeDrinkTds = isNaN(val) ? 0 : val
                    }
                }

                LabeledField {
                    Layout.fillWidth: true
                    label: "EY %"
                    text: Settings.dyeDrinkEy > 0 ? Settings.dyeDrinkEy.toFixed(1) : ""
                    inputHints: Qt.ImhFormattedNumbersOnly
                    onTextEdited: function(t) {
                        let val = parseFloat(t)
                        Settings.dyeDrinkEy = isNaN(val) ? 0 : val
                    }
                }

                LabeledField {
                    Layout.fillWidth: true
                    label: "Barista"
                    text: Settings.dyeBarista
                    onTextEdited: function(t) { Settings.dyeBarista = t }
                }

                // === ROW 4: Rating (spans 3 columns) ===
                Item {
                    Layout.columnSpan: 3
                    Layout.fillWidth: true
                    Layout.preferredHeight: ratingLabel.height + 40 + 2

                    Text {
                        id: ratingLabel
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: "Rating"
                        color: Theme.textColor
                        font.pixelSize: 11
                    }

                    ValueInput {
                        id: ratingInput
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 5
                        anchors.top: ratingLabel.bottom
                        anchors.topMargin: 2
                        height: 40
                        from: 0
                        to: 100
                        stepSize: 1
                        decimals: 0
                        suffix: " %"
                        value: Settings.dyeEspressoEnjoyment
                        accessibleName: "Rating " + value + " percent"
                        onValueModified: function(newValue) {
                            ratingInput.value = newValue
                            Settings.dyeEspressoEnjoyment = newValue
                        }
                    }
                }

                // === ROW 5: Notes (spans 3 columns) ===
                Item {
                    Layout.columnSpan: 3
                    Layout.fillWidth: true
                    Layout.preferredHeight: notesLabel.height + 100 + 2

                    Text {
                        id: notesLabel
                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: "Notes"
                        color: Theme.textColor
                        font.pixelSize: 11
                    }

                    TextArea {
                        id: notesField
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: notesLabel.bottom
                        anchors.topMargin: 2
                        height: 100
                        text: Settings.dyeEspressoNotes
                        font: Theme.bodyFont
                        color: Theme.textColor
                        placeholderTextColor: Theme.textSecondaryColor
                        wrapMode: TextEdit.Wrap
                        leftPadding: 8; rightPadding: 8; topPadding: 6; bottomPadding: 6
                        background: Rectangle {
                            color: Theme.backgroundColor
                            radius: 4
                            border.color: notesField.activeFocus ? Theme.primaryColor : Theme.borderColor
                            border.width: 1
                        }
                        onTextChanged: Settings.dyeEspressoNotes = text

                        Accessible.role: Accessible.EditableText
                        Accessible.name: "Notes"
                        Accessible.description: text.length > 0 ? text : "Empty"

                        onActiveFocusChanged: {
                            if (activeFocus && AccessibilityManager.enabled) {
                                let announcement = "Notes. " + (text.length > 0 ? text : "Empty")
                                AccessibilityManager.announce(announcement)
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 10 }
        }
    }

    // Bottom bar
    BottomBar {
        onBackClicked: root.goBack()

        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: Theme.standardMargin
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingMedium

            Text {
                visible: MainController.visualizer.uploading
                text: "Uploading..."
                color: Theme.textSecondaryColor
                font: Theme.labelFont
            }

            Rectangle {
                id: uploadButton
                visible: hasPendingShot && !MainController.visualizer.uploading
                width: uploadText.width + 40
                height: 44
                radius: 8
                color: Theme.surfaceColor

                Accessible.role: Accessible.Button
                Accessible.name: "Upload to Visualizer"
                Accessible.onPressAction: uploadArea.clicked(null)

                Text {
                    id: uploadText
                    anchors.centerIn: parent
                    text: "Upload to Visualizer"
                    color: Theme.textColor
                    font: Theme.bodyFont
                }

                MouseArea {
                    id: uploadArea
                    anchors.fill: parent
                    onClicked: {
                        MainController.uploadPendingShot()
                        hasPendingShot = false
                    }
                }
            }
        }
    }

    // === Inline Components ===

    component LabeledField: Item {
        property string label: ""
        property string text: ""
        property int inputHints: Qt.ImhNone
        signal textEdited(string text)

        implicitHeight: fieldLabel.height + fieldInput.height + 2

        Text {
            id: fieldLabel
            anchors.left: parent.left
            anchors.top: parent.top
            text: parent.label
            color: Theme.textColor
            font.pixelSize: 11
        }

        StyledTextField {
            id: fieldInput
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: fieldLabel.bottom
            anchors.topMargin: 2
            text: parent.text
            inputMethodHints: parent.inputHints
            onTextChanged: parent.textEdited(text)
            onActiveFocusChanged: {
                if (activeFocus && Qt.inputMethod.visible) updateKeyboardOffset(this)
                if (activeFocus && AccessibilityManager.enabled) {
                    let announcement = parent.label + ". " + (text.length > 0 ? text : "Empty")
                    AccessibilityManager.announce(announcement)
                }
            }

            Accessible.role: Accessible.EditableText
            Accessible.name: parent.label
            Accessible.description: text.length > 0 ? text : "Empty"
        }
    }

    component LabeledComboBox: Item {
        property string label: ""
        property var model: []
        property string currentValue: ""
        signal valueChanged(string value)

        implicitHeight: comboLabel.height + 48 + 2

        Text {
            id: comboLabel
            anchors.left: parent.left
            anchors.top: parent.top
            text: parent.label
            color: Theme.textColor
            font.pixelSize: 11
        }

        ComboBox {
            id: combo
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: comboLabel.bottom
            anchors.topMargin: 2
            height: 48
            model: parent.model
            currentIndex: Math.max(0, model.indexOf(parent.currentValue))
            font.pixelSize: 14

            Accessible.role: Accessible.ComboBox
            Accessible.name: parent.label
            Accessible.description: currentIndex > 0 ? currentText : "Not set"

            onActiveFocusChanged: {
                if (activeFocus && AccessibilityManager.enabled) {
                    let value = currentIndex > 0 ? currentText : "Not set"
                    AccessibilityManager.announce(parent.label + ". " + value)
                }
            }

            background: Rectangle {
                color: Theme.backgroundColor
                radius: 4
                border.color: combo.activeFocus ? Theme.primaryColor : Theme.textSecondaryColor
                border.width: 1
            }

            contentItem: Text {
                text: combo.currentIndex === 0 && combo.model[0] === "" ? parent.parent.label : combo.displayText
                color: Theme.textColor
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
                leftPadding: 12
            }

            indicator: Text {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "▼"
                color: Theme.textColor
                font.pixelSize: 10
            }

            delegate: ItemDelegate {
                width: combo.width
                height: 32
                contentItem: Text {
                    text: modelData || "(None)"
                    color: Theme.textColor
                    font.pixelSize: 14
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: highlighted ? Theme.primaryColor : Theme.surfaceColor
                }
                highlighted: combo.highlightedIndex === index

                Accessible.role: Accessible.ListItem
                Accessible.name: modelData || "None"
            }

            popup: Popup {
                y: combo.height
                width: combo.width
                implicitHeight: Math.min(contentItem.implicitHeight, 200)
                padding: 1
                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: combo.popup.visible ? combo.delegateModel : null
                }
                background: Rectangle {
                    color: Theme.surfaceColor
                    border.color: Theme.borderColor
                    radius: 4
                }
            }

            onCurrentTextChanged: parent.valueChanged(currentText)
        }
    }
}
