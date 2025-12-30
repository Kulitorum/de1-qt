import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DecenzaDE1
import "../components"

Page {
    id: aiSettingsPage
    objectName: "aiSettingsPage"
    background: Rectangle { color: Theme.backgroundColor }

    Component.onCompleted: root.currentPageTitle = "AI Dialing Assistant"
    StackView.onActivated: root.currentPageTitle = "AI Dialing Assistant"

    property string testResultMessage: ""
    property bool testResultSuccess: false

    Flickable {
        anchors.fill: parent
        anchors.margins: Theme.standardMargin
        contentHeight: contentColumn.height
        clip: true

        ColumnLayout {
            id: contentColumn
            width: parent.width
            spacing: Theme.spacingMedium

            // Header description
            Text {
                text: "Get AI-powered recommendations to dial in your espresso. Follows James Hoffmann's methodology: one variable at a time."
                color: Theme.textSecondaryColor
                font: Theme.bodyFont
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Item { height: Theme.spacingSmall }

            // Provider Selection
            Text {
                text: "AI Provider"
                color: Theme.textColor
                font: Theme.subtitleFont
            }

            // Provider cards
            Repeater {
                model: [
                    { id: "openai", name: "OpenAI", desc: "GPT-4o - excellent reasoning" },
                    { id: "anthropic", name: "Anthropic", desc: "Claude Sonnet - nuanced analysis" },
                    { id: "gemini", name: "Google Gemini", desc: "Gemini Pro - fast & capable" },
                    { id: "ollama", name: "Ollama (Local)", desc: "Free, private, runs on your computer" }
                ]

                delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 60
                    radius: Theme.buttonRadius
                    color: Settings.aiProvider === modelData.id ? Theme.primaryColor : Theme.surfaceColor
                    border.color: Settings.aiProvider === modelData.id ? Theme.primaryColor : Theme.borderColor
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingSmall
                        spacing: Theme.spacingSmall

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: modelData.name
                                font: Theme.bodyFont
                                color: Theme.textColor
                            }
                            Text {
                                text: modelData.desc
                                font.pixelSize: 12
                                color: Theme.textSecondaryColor
                            }
                        }

                        // Checkmark if selected
                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            visible: Settings.aiProvider === modelData.id
                            color: "transparent"
                            border.color: Theme.textColor
                            border.width: 2

                            Rectangle {
                                anchors.centerIn: parent
                                width: 12
                                height: 12
                                radius: 6
                                color: Theme.textColor
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Settings.aiProvider = modelData.id
                    }
                }
            }

            Item { height: Theme.spacingMedium }

            // API Key section (for cloud providers)
            ColumnLayout {
                visible: Settings.aiProvider !== "ollama"
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "API Key"
                    color: Theme.textSecondaryColor
                    font.pixelSize: 12
                }

                StyledTextField {
                    id: apiKeyField
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholderText: "Paste your API key here"
                    text: {
                        switch(Settings.aiProvider) {
                            case "openai": return Settings.openaiApiKey
                            case "anthropic": return Settings.anthropicApiKey
                            case "gemini": return Settings.geminiApiKey
                            default: return ""
                        }
                    }
                    onTextChanged: {
                        switch(Settings.aiProvider) {
                            case "openai": Settings.openaiApiKey = text; break
                            case "anthropic": Settings.anthropicApiKey = text; break
                            case "gemini": Settings.geminiApiKey = text; break
                        }
                    }
                }
            }

            // Ollama settings
            ColumnLayout {
                visible: Settings.aiProvider === "ollama"
                Layout.fillWidth: true
                spacing: Theme.spacingSmall

                Text {
                    text: "Ollama Endpoint"
                    color: Theme.textSecondaryColor
                    font.pixelSize: 12
                }

                StyledTextField {
                    id: ollamaEndpointField
                    Layout.fillWidth: true
                    placeholderText: "http://localhost:11434"
                    text: Settings.ollamaEndpoint
                    onTextChanged: Settings.ollamaEndpoint = text
                }

                Item { height: Theme.spacingSmall }

                Text {
                    text: "Model"
                    color: Theme.textSecondaryColor
                    font.pixelSize: 12
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingSmall

                    ComboBox {
                        id: ollamaModelCombo
                        Layout.fillWidth: true
                        model: MainController.aiManager ? MainController.aiManager.ollamaModels : []
                        currentIndex: model.indexOf(Settings.ollamaModel)
                        onCurrentTextChanged: if (currentText) Settings.ollamaModel = currentText

                        background: Rectangle {
                            color: Theme.backgroundColor
                            radius: 4
                            border.color: ollamaModelCombo.activeFocus ? Theme.primaryColor : Theme.borderColor
                            border.width: 1
                        }

                        contentItem: Text {
                            text: ollamaModelCombo.displayText || "Select a model"
                            color: Theme.textColor
                            font: Theme.bodyFont
                            leftPadding: 12
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    AccessibleButton {
                        text: "Refresh"
                        accessibleName: "Refresh Ollama models"
                        onClicked: {
                            if (MainController.aiManager) {
                                MainController.aiManager.refreshOllamaModels()
                            }
                        }
                        background: Rectangle {
                            implicitWidth: 80
                            implicitHeight: 40
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

            Item { height: Theme.spacingMedium }

            // Test Connection
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSmall

                AccessibleButton {
                    text: "Test Connection"
                    accessibleName: "Test AI provider connection"
                    enabled: MainController.aiManager && MainController.aiManager.isConfigured
                    onClicked: {
                        aiSettingsPage.testResultMessage = "Testing..."
                        MainController.aiManager.testConnection()
                    }
                    background: Rectangle {
                        implicitWidth: 140
                        implicitHeight: 44
                        radius: 6
                        color: parent.enabled ? Theme.primaryColor : Theme.surfaceColor
                        border.color: parent.enabled ? Theme.primaryColor : Theme.borderColor
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.enabled ? "white" : Theme.textSecondaryColor
                        font: Theme.bodyFont
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    text: aiSettingsPage.testResultMessage
                    color: aiSettingsPage.testResultSuccess ? Theme.successColor : Theme.errorColor
                    font.pixelSize: 14
                    visible: aiSettingsPage.testResultMessage.length > 0
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }

            Item { height: Theme.spacingLarge }

            // Help text
            Text {
                text: "How to get an API key:"
                color: Theme.textColor
                font: Theme.subtitleFont
            }

            Text {
                text: {
                    switch(Settings.aiProvider) {
                        case "openai": return "1. Visit platform.openai.com\n2. Create an account or sign in\n3. Go to API Keys section\n4. Create a new key and paste it above"
                        case "anthropic": return "1. Visit console.anthropic.com\n2. Create an account or sign in\n3. Go to API Keys section\n4. Create a new key and paste it above"
                        case "gemini": return "1. Visit aistudio.google.com\n2. Sign in with your Google account\n3. Click 'Get API Key'\n4. Create a key and paste it above"
                        case "ollama": return "1. Install Ollama from ollama.ai\n2. Open a terminal and run:\n   ollama pull llama3.2\n3. Ensure Ollama is running\n4. Click Refresh above to see models"
                        default: return ""
                    }
                }
                color: Theme.textSecondaryColor
                font: Theme.bodyFont
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Item { height: Theme.spacingLarge }

            // Cost info
            Rectangle {
                Layout.fillWidth: true
                height: costColumn.height + Theme.spacingMedium * 2
                radius: Theme.buttonRadius
                color: Theme.surfaceColor

                ColumnLayout {
                    id: costColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingMedium
                    spacing: 4

                    Text {
                        text: "Estimated Cost"
                        color: Theme.textColor
                        font: Theme.subtitleFont
                    }

                    Text {
                        text: {
                            switch(Settings.aiProvider) {
                                case "openai": return "~$0.01 per analysis (GPT-4o)"
                                case "anthropic": return "~$0.003 per analysis (Claude Sonnet)"
                                case "gemini": return "~$0.002 per analysis (Gemini Pro)"
                                case "ollama": return "Free (runs locally on your computer)"
                                default: return ""
                            }
                        }
                        color: Theme.textSecondaryColor
                        font: Theme.bodyFont
                    }

                    Text {
                        visible: Settings.aiProvider !== "ollama"
                        text: "About $0.30/month at 3 shots per day - less than one cafe espresso!"
                        color: Theme.textSecondaryColor
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            Item { height: Theme.spacingLarge }
        }
    }

    // Connection to AIManager for test results
    Connections {
        target: MainController.aiManager
        function onTestResultChanged() {
            aiSettingsPage.testResultSuccess = MainController.aiManager.lastTestSuccess
            aiSettingsPage.testResultMessage = MainController.aiManager.lastTestResult
        }
    }
}
