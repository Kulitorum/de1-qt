import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DecenzaDE1

// Translatable text component
// Usage: Tr { key: "settings.title"; fallback: "Settings" }
Item {
    id: control

    // Required properties
    required property string key
    required property string fallback

    // Forward common Text properties
    property alias font: textItem.font
    property alias color: textItem.color
    property alias horizontalAlignment: textItem.horizontalAlignment
    property alias verticalAlignment: textItem.verticalAlignment
    property alias wrapMode: textItem.wrapMode
    property alias elide: textItem.elide
    property alias lineHeight: textItem.lineHeight
    property alias lineHeightMode: textItem.lineHeightMode
    property alias maximumLineCount: textItem.maximumLineCount

    // Computed text property (read-only, for binding)
    // Using translationVersion creates a dependency that forces re-evaluation when translations change
    readonly property string text: {
        var _ = TranslationManager.translationVersion  // Trigger re-evaluation
        return TranslationManager.translate(key, fallback)
    }

    // Expose content dimensions
    readonly property real contentWidth: textItem.contentWidth
    readonly property real contentHeight: textItem.contentHeight

    // Default size follows text content
    implicitWidth: textItem.implicitWidth + (showHighlight ? 4 : 0)
    implicitHeight: textItem.implicitHeight + (showHighlight ? 4 : 0)

    // Internal state - also depends on translationVersion for reactivity
    readonly property bool isTranslated: {
        var _ = TranslationManager.translationVersion
        return TranslationManager.hasTranslation(key)
    }
    readonly property bool showHighlight: TranslationManager.editModeEnabled && !isTranslated && TranslationManager.currentLanguage !== "en"

    // Register this string with TranslationManager
    Component.onCompleted: {
        TranslationManager.registerString(key, fallback)
    }

    // Public method to open the translation editor (called by global overlay)
    function openEditor() {
        translationEditor.open()
    }

    // Highlight background for untranslated strings in edit mode
    Rectangle {
        id: highlightRect
        anchors.fill: parent
        anchors.margins: -2
        z: -1
        visible: control.showHighlight
        color: Qt.rgba(Theme.warningColor.r, Theme.warningColor.g, Theme.warningColor.b, 0.15)
        radius: 2
        border.width: 1
        border.color: Qt.rgba(Theme.warningColor.r, Theme.warningColor.g, Theme.warningColor.b, 0.5)
    }

    // The actual text display
    Text {
        id: textItem
        anchors.centerIn: parent
        text: control.text
        font: Theme.bodyFont
        color: Theme.textColor
    }

    // Long-press handler for edit mode (allows normal navigation with single clicks)
    MouseArea {
        anchors.fill: parent
        enabled: TranslationManager.editModeEnabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressAndHold: {
            translationEditor.open()
        }
    }

    // Inline translation editor popup
    Popup {
        id: translationEditor
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        dim: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        width: Math.min(450, (control.Window.window ? control.Window.window.width : 450) - 40)
        padding: Theme.spacingMedium

        background: Rectangle {
            color: Theme.surfaceColor
            radius: Theme.cardRadius
            border.width: 1
            border.color: Theme.borderColor

            // Shadow effect
            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                z: -1
                color: "transparent"
                radius: parent.radius + 1
                border.width: 4
                border.color: Qt.rgba(0, 0, 0, 0.3)
            }
        }

        onOpened: {
            translationInput.text = TranslationManager.translate(control.key, "")
            translationInput.forceActiveFocus()
        }

        contentItem: ColumnLayout {
            spacing: Theme.spacingMedium

            // Header
            Text {
                text: "Edit Translation"
                font: Theme.titleFont
                color: Theme.textColor
            }

            // Key display
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSmall

                Text {
                    text: "Key:"
                    font: Theme.labelFont
                    color: Theme.textSecondaryColor
                }

                Text {
                    Layout.fillWidth: true
                    text: control.key
                    font: Theme.labelFont
                    color: Theme.textColor
                    elide: Text.ElideMiddle
                }
            }

            // English (fallback) - the source text
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSmall

                Text {
                    text: "English (original):"
                    font: Theme.labelFont
                    color: Theme.textSecondaryColor
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: englishText.height + 16
                    color: Theme.backgroundColor
                    radius: 4

                    Text {
                        id: englishText
                        anchors.fill: parent
                        anchors.margins: 8
                        text: control.fallback
                        font: Theme.bodyFont
                        color: Theme.textColor
                        wrapMode: Text.Wrap
                    }
                }
            }

            // Translation input
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSmall

                Text {
                    text: "Translation (" + TranslationManager.getLanguageDisplayName(TranslationManager.currentLanguage) + "):"
                    font: Theme.labelFont
                    color: Theme.textSecondaryColor
                }

                StyledTextField {
                    id: translationInput
                    Layout.fillWidth: true
                    placeholderText: "Enter translation..."

                    // Submit on Enter
                    Keys.onReturnPressed: saveButton.clicked()
                    Keys.onEnterPressed: saveButton.clicked()
                }
            }

            // Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium

                Item { Layout.fillWidth: true }

                Button {
                    text: "Cancel"
                    onClicked: translationEditor.close()

                    background: Rectangle {
                        implicitWidth: 80
                        implicitHeight: Theme.touchTargetMin
                        color: parent.down ? Qt.darker(Theme.surfaceColor, 1.2) : Theme.surfaceColor
                        radius: Theme.buttonRadius
                        border.width: 1
                        border.color: Theme.borderColor
                    }

                    contentItem: Text {
                        text: parent.text
                        font: Theme.bodyFont
                        color: Theme.textColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: "Clear"
                    visible: control.isTranslated
                    onClicked: {
                        TranslationManager.deleteTranslation(control.key)
                        translationEditor.close()
                    }

                    background: Rectangle {
                        implicitWidth: 80
                        implicitHeight: Theme.touchTargetMin
                        color: parent.down ? Qt.darker(Theme.warningColor, 1.2) : Theme.warningColor
                        radius: Theme.buttonRadius
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
                    id: saveButton
                    text: "Save"
                    onClicked: {
                        if (translationInput.text.trim() !== "") {
                            TranslationManager.setTranslation(control.key, translationInput.text.trim())
                        } else {
                            TranslationManager.deleteTranslation(control.key)
                        }
                        translationEditor.close()
                    }

                    background: Rectangle {
                        implicitWidth: 80
                        implicitHeight: Theme.touchTargetMin
                        color: parent.down ? Qt.darker(Theme.primaryColor, 1.2) : Theme.primaryColor
                        radius: Theme.buttonRadius
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
    }
}
