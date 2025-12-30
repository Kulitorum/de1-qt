import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DecenzaDE1
import "../components"

Page {
    id: visualizerPage
    objectName: "visualizerBrowserPage"
    background: Rectangle { color: Theme.backgroundColor }

    Component.onCompleted: root.currentPageTitle = "Import from Visualizer"
    StackView.onActivated: root.currentPageTitle = "Import from Visualizer"

    // Import success/failure handling
    Connections {
        target: MainController.visualizerImporter

        function onImportSuccess(profileTitle) {
            importStatus.statusMessage = "Imported: " + profileTitle
            importStatus.statusColor = Theme.successColor
            importStatus.visible = true
            statusTimer.restart()
            shareCodeInput.text = ""
        }

        function onImportFailed(error) {
            importStatus.statusMessage = "Error: " + error
            importStatus.statusColor = Theme.errorColor
            importStatus.visible = true
            statusTimer.restart()
        }

        function onDuplicateFound(profileTitle, existingPath) {
            showDuplicateDialog(profileTitle)
        }
    }

    // Track if we're showing the duplicate choice
    property bool showingDuplicateChoice: false
    property bool showingNameInput: false
    property string duplicateProfileTitle: ""

    function showDuplicateDialog(title) {
        duplicateProfileTitle = title
        showingDuplicateChoice = true
        showingNameInput = false
    }

    function hideDuplicateDialog() {
        showingDuplicateChoice = false
        showingNameInput = false
    }

    Timer {
        id: statusTimer
        interval: 5000
        onTriggered: importStatus.visible = false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Theme.pageTopMargin
        anchors.bottomMargin: Theme.bottomBarHeight
        spacing: 0

        // Status message
        Rectangle {
            id: importStatus
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Theme.scaled(40) : 0
            visible: false
            color: Theme.surfaceColor

            property string statusMessage: ""
            property color statusColor: Theme.textColor

            Text {
                anchors.centerIn: parent
                text: importStatus.statusMessage
                color: importStatus.statusColor
                font: Theme.bodyFont
            }

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 200 }
            }
        }

        // Main content area
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Share code input (main view)
            Rectangle {
                anchors.fill: parent
                visible: !showingDuplicateChoice
                color: Theme.backgroundColor

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingLarge
                    width: Math.min(parent.width - Theme.scaled(40), Theme.scaled(500))

                    Text {
                        text: "Import Profile from Visualizer"
                        color: Theme.textColor
                        font: Theme.headingFont
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "Enter the 4-character share code from visualizer.coffee"
                        wrapMode: Text.Wrap
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.textSecondaryColor
                        font: Theme.bodyFont
                    }

                    // Share code input field
                    TextField {
                        id: shareCodeInput
                        width: parent.width
                        height: Theme.scaled(60)
                        color: Theme.textColor
                        font.pixelSize: Theme.scaled(24)
                        font.family: Theme.bodyFont.family
                        horizontalAlignment: Text.AlignHCenter
                        maximumLength: 4
                        placeholderTextColor: Theme.textSecondaryColor
                        inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                        leftPadding: 12
                        rightPadding: 12
                        topPadding: 12
                        bottomPadding: 12

                        background: Rectangle {
                            color: Theme.surfaceColor
                            border.color: shareCodeInput.activeFocus ? Theme.primaryColor : Theme.textSecondaryColor
                            border.width: 2
                            radius: Theme.scaled(8)
                        }

                        // Auto-uppercase
                        onTextChanged: {
                            var upper = text.toUpperCase()
                            if (text !== upper) {
                                text = upper
                            }
                        }

                        Keys.onReturnPressed: {
                            if (text.length === 4) {
                                MainController.visualizerImporter.importFromShareCode(text)
                            }
                            focus = false
                            Qt.inputMethod.hide()
                        }
                        Keys.onEnterPressed: Keys.onReturnPressed(event)
                    }

                    // Import button
                    Button {
                        text: MainController.visualizerImporter.importing ? "Importing..." : "Import Profile"
                        enabled: shareCodeInput.text.length === 4 && !MainController.visualizerImporter.importing
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Theme.scaled(200)
                        height: Theme.scaled(50)

                        onClicked: {
                            MainController.visualizerImporter.importFromShareCode(shareCodeInput.text)
                        }

                        background: Rectangle {
                            radius: Theme.scaled(8)
                            color: parent.enabled ? Theme.primaryColor : Theme.surfaceColor
                        }
                        contentItem: Text {
                            text: parent.text
                            color: parent.enabled ? "white" : Theme.textSecondaryColor
                            font: Theme.bodyFont
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // Loading indicator
                    BusyIndicator {
                        running: MainController.visualizerImporter.importing
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Theme.scaled(40)
                        height: Theme.scaled(40)
                        visible: running
                    }

                    // Instructions
                    Rectangle {
                        width: parent.width
                        height: instructionsColumn.height + Theme.scaled(20)
                        color: Theme.surfaceColor
                        radius: Theme.scaled(8)

                        Column {
                            id: instructionsColumn
                            anchors.centerIn: parent
                            width: parent.width - Theme.scaled(20)
                            spacing: Theme.scaled(8)

                            Text {
                                text: "How to get a share code:"
                                color: Theme.textColor
                                font.bold: true
                                font.pixelSize: Theme.bodyFont.pixelSize
                            }

                            Text {
                                text: "1. Open visualizer.coffee on your phone or computer"
                                color: Theme.textSecondaryColor
                                font: Theme.captionFont
                                wrapMode: Text.Wrap
                                width: parent.width
                            }

                            Text {
                                text: "2. Find a shot with a profile you want"
                                color: Theme.textSecondaryColor
                                font: Theme.captionFont
                                wrapMode: Text.Wrap
                                width: parent.width
                            }

                            Text {
                                text: "3. Tap 'Share' and copy the 4-character code"
                                color: Theme.textSecondaryColor
                                font: Theme.captionFont
                                wrapMode: Text.Wrap
                                width: parent.width
                            }

                            Text {
                                text: "4. Enter the code above and tap Import"
                                color: Theme.textSecondaryColor
                                font: Theme.captionFont
                                wrapMode: Text.Wrap
                                width: parent.width
                            }
                        }
                    }
                }
            }

            // Duplicate profile choice
            Rectangle {
                anchors.fill: parent
                visible: showingDuplicateChoice && !showingNameInput
                color: Theme.backgroundColor

                Column {
                    anchors.centerIn: parent
                    spacing: Theme.spacingLarge
                    width: Math.min(parent.width - Theme.scaled(40), Theme.scaled(400))

                    Text {
                        text: "Profile Already Exists"
                        color: Theme.textColor
                        font: Theme.headingFont
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "A profile named \"" + duplicateProfileTitle + "\" already exists.\n\nWhat would you like to do?"
                        wrapMode: Text.Wrap
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.textColor
                        font: Theme.bodyFont
                    }

                    Row {
                        spacing: Theme.spacingMedium
                        anchors.horizontalCenter: parent.horizontalCenter

                        Button {
                            text: "Overwrite"
                            onClicked: {
                                MainController.visualizerImporter.saveOverwrite()
                                hideDuplicateDialog()
                            }
                            background: Rectangle {
                                radius: Theme.scaled(4)
                                color: Theme.errorColor
                            }
                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                font: Theme.bodyFont
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: Theme.scaled(16)
                                rightPadding: Theme.scaled(16)
                            }
                        }

                        Button {
                            text: "Save as New"
                            onClicked: {
                                newNameInput.text = duplicateProfileTitle + " (copy)"
                                showingNameInput = true
                            }
                            background: Rectangle {
                                radius: Theme.scaled(4)
                                color: Theme.primaryColor
                            }
                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                font: Theme.bodyFont
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: Theme.scaled(16)
                                rightPadding: Theme.scaled(16)
                            }
                        }

                        Button {
                            text: "Cancel"
                            onClicked: hideDuplicateDialog()
                            background: Rectangle {
                                radius: Theme.scaled(4)
                                color: Theme.surfaceColor
                                border.color: Theme.textSecondaryColor
                                border.width: 1
                            }
                            contentItem: Text {
                                text: parent.text
                                color: Theme.textColor
                                font: Theme.bodyFont
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: Theme.scaled(16)
                                rightPadding: Theme.scaled(16)
                            }
                        }
                    }
                }
            }

            // Name input for Save as New
            FocusScope {
                id: nameInputPanel
                anchors.fill: parent
                visible: showingDuplicateChoice && showingNameInput
                focus: visible

                property real keyboardOffset: 0

                Timer {
                    id: keyboardResetTimer
                    interval: 100
                    onTriggered: {
                        if (!Qt.inputMethod.visible) {
                            nameInputPanel.keyboardOffset = 0
                        }
                    }
                }

                Connections {
                    target: Qt.inputMethod
                    function onVisibleChanged() {
                        if (Qt.inputMethod.visible) {
                            keyboardResetTimer.stop()
                            nameInputPanel.keyboardOffset = nameInputPanel.height * 0.3
                        } else {
                            keyboardResetTimer.restart()
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.backgroundColor
                }

                Column {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -nameInputPanel.keyboardOffset
                    spacing: Theme.spacingLarge
                    width: Math.min(parent.width - Theme.scaled(40), Theme.scaled(400))

                    Text {
                        text: "Enter New Name"
                        color: Theme.textColor
                        font: Theme.headingFont
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    TextField {
                        id: newNameInput
                        width: parent.width
                        height: Theme.scaled(50)
                        color: Theme.textColor
                        font: Theme.bodyFont
                        selectByMouse: true
                        focus: true
                        inputMethodHints: Qt.ImhNoAutoUppercase
                        leftPadding: 12
                        rightPadding: 12
                        topPadding: 12
                        bottomPadding: 12
                        background: Rectangle {
                            color: Theme.surfaceColor
                            border.color: newNameInput.activeFocus ? Theme.primaryColor : Theme.textSecondaryColor
                            border.width: 2
                            radius: Theme.scaled(4)
                        }

                        Keys.onReturnPressed: { focus = false; Qt.inputMethod.hide() }
                        Keys.onEnterPressed: { focus = false; Qt.inputMethod.hide() }
                    }

                    Row {
                        spacing: Theme.spacingMedium
                        anchors.horizontalCenter: parent.horizontalCenter

                        Button {
                            text: "Save"
                            enabled: newNameInput.text.trim().length > 0
                            onClicked: {
                                MainController.visualizerImporter.saveWithNewName(newNameInput.text.trim())
                                hideDuplicateDialog()
                            }
                            background: Rectangle {
                                radius: Theme.scaled(4)
                                color: parent.enabled ? Theme.primaryColor : Theme.surfaceColor
                            }
                            contentItem: Text {
                                text: parent.text
                                color: parent.enabled ? "white" : Theme.textSecondaryColor
                                font: Theme.bodyFont
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: Theme.scaled(16)
                                rightPadding: Theme.scaled(16)
                            }
                        }

                        Button {
                            text: "Back"
                            onClicked: showingNameInput = false
                            background: Rectangle {
                                radius: Theme.scaled(4)
                                color: Theme.surfaceColor
                                border.color: Theme.textSecondaryColor
                                border.width: 1
                            }
                            contentItem: Text {
                                text: parent.text
                                color: Theme.textColor
                                font: Theme.bodyFont
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: Theme.scaled(16)
                                rightPadding: Theme.scaled(16)
                            }
                        }
                    }
                }
            }
        }
    }

    // Bottom bar
    BottomBar {
        title: "Visualizer"
        rightText: "Enter share code to import"
        onBackClicked: root.goBack()
    }
}
