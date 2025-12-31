import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DecenzaDE1

Button {
    id: control

    property string iconSource: ""
    property color backgroundColor: Theme.primaryColor
    property int iconSize: Theme.scaled(48)

    // Translation support - set these to enable edit mode clicking
    property string translationKey: ""
    property string translationFallback: ""

    // Auto-compute text from translation if translationKey is set (reactive to translation changes)
    text: translationKey !== "" ? _computedText : ""
    readonly property string _computedText: {
        var _ = TranslationManager.translationVersion  // Trigger re-evaluation
        return TranslationManager.translate(translationKey, translationFallback)
    }

    // Note: pressAndHold() and doubleClicked() are inherited from Button/AbstractButton

    // Track if long-press fired (to prevent click after hold)
    property bool _longPressTriggered: false
    property bool _isPressed: false

    // Check if in translation edit mode
    readonly property bool _inEditMode: translationKey !== "" &&
                                         typeof TranslationManager !== "undefined" &&
                                         TranslationManager.editModeEnabled

    // Enable keyboard focus
    focusPolicy: Qt.StrongFocus
    activeFocusOnTab: true

    // Accessibility
    Accessible.role: Accessible.Button
    Accessible.name: control.text
    Accessible.description: "Double-tap to select profile. Long-press for settings."
    Accessible.focusable: true

    implicitWidth: Theme.scaled(150)
    implicitHeight: Theme.scaled(120)

    contentItem: Column {
        spacing: Theme.scaled(10)
        anchors.centerIn: parent

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.scaled(48)
            height: Theme.scaled(48)
            visible: control.iconSource !== ""

            Image {
                anchors.centerIn: parent
                source: control.iconSource
                width: control.iconSize
                height: control.iconSize
                fillMode: Image.PreserveAspectFit
                opacity: control.enabled ? 1.0 : 0.5
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: control.text
            color: control.enabled ? Theme.textColor : Theme.textSecondaryColor
            font: Theme.bodyFont
        }
    }

    background: Rectangle {
        radius: Theme.buttonRadius
        color: {
            if (!control.enabled) return Theme.buttonDisabled
            if (control._isPressed) return Qt.darker(control.backgroundColor, 1.2)
            if (control.hovered || control.activeFocus) return Qt.lighter(control.backgroundColor, 1.1)
            return control.backgroundColor
        }

        // Focus indicator
        Rectangle {
            anchors.fill: parent
            anchors.margins: -Theme.focusMargin
            visible: control.activeFocus
            color: "transparent"
            border.width: Theme.focusBorderWidth
            border.color: Theme.focusColor
            radius: parent.radius + Theme.focusMargin
        }

        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }

    // Custom interaction handling using AccessibleMouseArea
    AccessibleMouseArea {
        anchors.fill: parent
        enabled: control.enabled

        accessibleName: control.text
        accessibleItem: control
        supportLongPress: true
        supportDoubleClick: true

        // Track pressed state for visual feedback
        onIsPressedChanged: control._isPressed = isPressed

        onAccessibleClicked: {
            control.clicked()
        }
        onAccessibleDoubleClicked: {
            control.doubleClicked()
        }
        onAccessibleLongPressed: {
            if (control._inEditMode) {
                // Long-press opens translation editor in edit mode
                translationEditorPopup.open()
            }
            // No other long-press action - removed as unused
        }
    }

    // Edit mode indicator overlay
    Rectangle {
        anchors.fill: parent
        visible: control._inEditMode && !TranslationManager.hasTranslation(control.translationKey)
        color: "transparent"
        radius: Theme.buttonRadius
        border.width: 2
        border.color: Theme.warningColor
        opacity: 0.7
    }

    // Translation editor popup
    Popup {
        id: translationEditorPopup
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
        }

        onOpened: {
            popupTranslationInput.text = TranslationManager.translate(control.translationKey, "")
            popupTranslationInput.forceActiveFocus()
        }

        contentItem: ColumnLayout {
            spacing: Theme.spacingMedium

            Text {
                text: "Edit Translation"
                font: Theme.titleFont
                color: Theme.textColor
            }

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
                    text: control.translationKey
                    font: Theme.labelFont
                    color: Theme.textColor
                    elide: Text.ElideMiddle
                }
            }

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
                    implicitHeight: popupEnglishText.height + 16
                    color: Theme.backgroundColor
                    radius: 4

                    Text {
                        id: popupEnglishText
                        anchors.fill: parent
                        anchors.margins: 8
                        text: control.translationFallback
                        font: Theme.bodyFont
                        color: Theme.textColor
                        wrapMode: Text.Wrap
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSmall

                Text {
                    text: "Translation (" + TranslationManager.getLanguageDisplayName(TranslationManager.currentLanguage) + "):"
                    font: Theme.labelFont
                    color: Theme.textSecondaryColor
                }

                StyledTextField {
                    id: popupTranslationInput
                    Layout.fillWidth: true
                    placeholderText: "Enter translation..."

                    Keys.onReturnPressed: popupSaveButton.clicked()
                    Keys.onEnterPressed: popupSaveButton.clicked()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium

                Item { Layout.fillWidth: true }

                Button {
                    text: "Cancel"
                    onClicked: translationEditorPopup.close()

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
                    id: popupSaveButton
                    text: "Save"
                    onClicked: {
                        if (popupTranslationInput.text.trim() !== "") {
                            TranslationManager.setTranslation(control.translationKey, popupTranslationInput.text.trim())
                        } else {
                            TranslationManager.deleteTranslation(control.translationKey)
                        }
                        translationEditorPopup.close()
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

    // Keyboard handling
    Keys.onReturnPressed: {
        control._longPressTriggered = false
        control.clicked()
    }

    Keys.onEnterPressed: {
        control._longPressTriggered = false
        control.clicked()
    }

    Keys.onSpacePressed: {
        control._longPressTriggered = false
        control.clicked()
    }

    // Shift+Enter for long-press action
    Keys.onPressed: function(event) {
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) &&
            (event.modifiers & Qt.ShiftModifier)) {
            control.pressAndHold()
            event.accepted = true
        }
    }

    // Announce button name when focused (for accessibility)
    onActiveFocusChanged: {
        if (activeFocus && typeof AccessibilityManager !== "undefined" && AccessibilityManager.enabled) {
            AccessibilityManager.announce(control.text)
        }
    }
}
