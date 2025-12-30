import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DecenzaDE1
import "../components"

Page {
    id: dialingPage
    objectName: "dialingAssistantPage"
    background: Rectangle { color: Theme.backgroundColor }

    Component.onCompleted: root.currentPageTitle = "AI Recommendation"
    StackView.onActivated: root.currentPageTitle = "AI Recommendation"

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Theme.pageTopMargin
        anchors.bottomMargin: Theme.bottomBarHeight
        anchors.leftMargin: Theme.standardMargin
        anchors.rightMargin: Theme.standardMargin
        spacing: Theme.spacingMedium

        // Loading state
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: MainController.aiManager && MainController.aiManager.isAnalyzing

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.spacingMedium

                BusyIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    running: true
                    palette.dark: Theme.primaryColor
                }

                Text {
                    text: "Analyzing your shot..."
                    color: Theme.textSecondaryColor
                    font: Theme.bodyFont
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "This may take a few seconds"
                    color: Theme.textSecondaryColor
                    font.pixelSize: 12
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // Error state
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: MainController.aiManager && !MainController.aiManager.isAnalyzing &&
                     MainController.aiManager.lastError.length > 0 &&
                     MainController.aiManager.lastRecommendation.length === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.spacingMedium
                width: parent.width * 0.8

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 64
                    height: 64
                    radius: 32
                    color: Theme.errorColor
                    opacity: 0.2

                    Text {
                        anchors.centerIn: parent
                        text: "!"
                        color: Theme.errorColor
                        font.pixelSize: 32
                        font.bold: true
                    }
                }

                Text {
                    text: "Analysis Failed"
                    color: Theme.textColor
                    font: Theme.subtitleFont
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: MainController.aiManager ? MainController.aiManager.lastError : ""
                    color: Theme.textSecondaryColor
                    font: Theme.bodyFont
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                AccessibleButton {
                    text: "Go Back"
                    accessibleName: "Go back to previous screen"
                    Layout.alignment: Qt.AlignHCenter
                    onClicked: pageStack.pop()
                    background: Rectangle {
                        implicitWidth: 120
                        implicitHeight: 44
                        radius: 6
                        color: Theme.surfaceColor
                        border.color: Theme.borderColor
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text
                        color: Theme.textColor
                        font: Theme.bodyFont
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // Success state - recommendation content (scrollable, selectable text)
        Flickable {
            id: recommendationFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: recommendationText.contentHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            visible: MainController.aiManager && !MainController.aiManager.isAnalyzing &&
                     MainController.aiManager.lastRecommendation.length > 0

            // Reset scroll position when visible
            onVisibleChanged: if (visible) contentY = 0

            TextArea {
                id: recommendationText
                width: parent.width
                text: {
                    if (!MainController.aiManager) return ""
                    var recommendation = MainController.aiManager.lastRecommendation
                    if (recommendation.length === 0) return ""

                    // Format provider name nicely
                    var provider = MainController.aiManager.selectedProvider
                    var providerName = {
                        "openai": "OpenAI GPT-4o",
                        "anthropic": "Anthropic Claude",
                        "gemini": "Google Gemini",
                        "ollama": "Ollama"
                    }[provider] || provider

                    return recommendation + "\n\n---\n*Advice by " + providerName + "*"
                }
                textFormat: Text.MarkdownText
                wrapMode: TextEdit.WordWrap
                readOnly: true
                selectByMouse: true
                font: Theme.bodyFont
                color: Theme.textColor
                background: null
                padding: 0
            }
        }

        // Action buttons (visible when we have a recommendation)
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMedium
            visible: MainController.aiManager && !MainController.aiManager.isAnalyzing &&
                     MainController.aiManager.lastRecommendation.length > 0

            AccessibleButton {
                text: "Copy"
                accessibleName: "Copy recommendation to clipboard"
                Layout.fillWidth: true
                onClicked: {
                    // Copy edited text to clipboard
                    recommendationText.selectAll()
                    recommendationText.copy()
                    recommendationText.deselect()
                    copyFeedback.visible = true
                    copyTimer.start()
                }
                background: Rectangle {
                    implicitHeight: 48
                    radius: 6
                    color: Theme.surfaceColor
                    border.color: Theme.borderColor
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: Theme.textColor
                    font: Theme.bodyFont
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            AccessibleButton {
                text: "Done"
                accessibleName: "Close recommendation"
                Layout.fillWidth: true
                onClicked: pageStack.pop()
                background: Rectangle {
                    implicitHeight: 48
                    radius: 6
                    color: Theme.primaryColor
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font: Theme.bodyFont
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // Copy feedback toast
    Rectangle {
        id: copyFeedback
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 100
        width: copyText.width + 32
        height: 40
        radius: 20
        color: Theme.successColor
        visible: false
        opacity: visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        Text {
            id: copyText
            anchors.centerIn: parent
            text: "Copied to clipboard"
            color: "white"
            font: Theme.bodyFont
        }

        Timer {
            id: copyTimer
            interval: 2000
            onTriggered: copyFeedback.visible = false
        }
    }

    // Navigate to this page when analysis completes
    Connections {
        target: MainController.aiManager
        function onRecommendationReceived(recommendation) {
            // Reset scroll to top when new recommendation arrives
            recommendationFlickable.contentY = 0
        }
        function onErrorOccurred(error) {
            // Stay on this page to show the error
        }
    }
}
