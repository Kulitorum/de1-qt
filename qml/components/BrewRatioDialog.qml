import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DecenzaDE1

Dialog {
    id: root
    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Theme.scaled(400)
    modal: true
    padding: 0

    // Dose value (editable, default 18g)
    property double doseValue: 18.0
    property double ratio: Settings.lastUsedRatio

    // Target (yield) value and tracking
    property double targetValue: doseValue * ratio
    property bool targetManuallySet: false

    // Grind setting
    property string grindSetting: ""

    // Low dose warning - shown when dose is low OR when scale read failed
    property bool showScaleWarning: false
    property bool lowDoseWarning: doseValue < 3 || showScaleWarning

    // Recalculate target when dose or ratio changes (unless manually overridden)
    onDoseValueChanged: {
        if (!targetManuallySet) {
            targetValue = doseValue * ratio
        }
    }

    onRatioChanged: {
        if (!targetManuallySet) {
            targetValue = doseValue * ratio
        }
    }

    onAboutToShow: {
        // Reset to defaults when dialog opens
        doseValue = 18.0
        ratio = Settings.lastUsedRatio
        targetManuallySet = false
        targetValue = doseValue * ratio
        grindSetting = Settings.dyeGrinderSetting
        showScaleWarning = false
    }

    background: Rectangle {
        color: Theme.surfaceColor
        radius: Theme.cardRadius
        border.width: 1
        border.color: "white"
    }

    contentItem: ColumnLayout {
        spacing: 0

        // Header
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.scaled(50)
            Layout.topMargin: Theme.scaled(10)

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Theme.scaled(20)
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Brew by Ratio")
                font: Theme.titleFont
                color: Theme.textColor
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.borderColor
            }
        }

        // Content
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.scaled(20)
            spacing: Theme.scaled(16)

            // Low dose warning
            Rectangle {
                Layout.fillWidth: true
                visible: root.lowDoseWarning
                color: Theme.surfaceColor
                border.width: 1
                border.color: Theme.warningColor
                radius: Theme.scaled(8)
                implicitHeight: warningText.implicitHeight + Theme.scaled(24)

                Text {
                    id: warningText
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Theme.scaled(12)
                    text: qsTr("Please put the portafilter with coffee on the scale")
                    font: Theme.bodyFont
                    color: Theme.warningColor
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // Dose input
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.scaled(8)

                Text {
                    text: qsTr("Dose:")
                    font: Theme.bodyFont
                    color: Theme.textSecondaryColor
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Theme.scaled(55)
                }

                ValueInput {
                    id: doseInput
                    Layout.fillWidth: true
                    value: root.doseValue
                    from: 1
                    to: 50
                    stepSize: 0.1
                    decimals: 1
                    suffix: "g"
                    valueColor: Theme.weightColor
                    accentColor: Theme.weightColor
                    accessibleName: qsTr("Dose weight")
                    onValueModified: function(newValue) {
                        root.targetManuallySet = false  // Reset manual flag when dose changes
                        root.doseValue = newValue
                        if (newValue >= 3) {
                            root.showScaleWarning = false
                        }
                    }
                }

                AccessibleButton {
                    Layout.preferredHeight: Theme.scaled(56)
                    text: qsTr("Get from scale")
                    accessibleName: qsTr("Get dose from scale")
                    primary: true
                    onClicked: {
                        var scaleWeight = MachineState.scaleWeight
                        if (scaleWeight >= 3) {
                            root.showScaleWarning = false
                            root.targetManuallySet = false  // Reset manual flag
                            root.doseValue = scaleWeight
                        } else {
                            // Show warning but don't change dose
                            root.showScaleWarning = true
                        }
                    }
                }
            }

            // Ratio input
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.scaled(8)

                Text {
                    text: qsTr("Ratio: 1:")
                    font: Theme.bodyFont
                    color: Theme.textSecondaryColor
                    Layout.preferredWidth: Theme.scaled(55)
                }

                ValueInput {
                    id: ratioInput
                    Layout.fillWidth: true
                    value: root.ratio
                    from: 0.5
                    to: 20.0
                    stepSize: 0.1
                    decimals: 1
                    valueColor: Theme.primaryColor
                    accentColor: Theme.primaryColor
                    accessibleName: qsTr("Brew ratio")
                    onValueModified: function(newValue) {
                        root.targetManuallySet = false  // Reset manual flag when ratio changes
                        root.ratio = newValue
                    }
                }
            }

            // Yield input
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.scaled(8)

                Text {
                    text: qsTr("Yield:")
                    font: Theme.bodyFont
                    color: Theme.textSecondaryColor
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Theme.scaled(55)
                }

                ValueInput {
                    id: targetInput
                    Layout.fillWidth: true
                    value: root.targetValue
                    from: 1
                    to: 200
                    stepSize: 1
                    decimals: 0
                    suffix: "g"
                    // Color changes based on whether value is auto-calculated or manually set
                    valueColor: root.targetManuallySet ? Theme.primaryColor : Theme.weightColor
                    accentColor: root.targetManuallySet ? Theme.primaryColor : Theme.weightColor
                    accessibleName: qsTr("Yield weight") + (root.targetManuallySet ? qsTr(" (manual)") : qsTr(" (calculated)"))
                    onValueModified: function(newValue) {
                        root.targetManuallySet = true  // Mark as manually set
                        root.targetValue = newValue
                    }
                }

                // Visual indicator for auto vs manual
                Text {
                    text: root.targetManuallySet ? qsTr("(manual)") : qsTr("(auto)")
                    font.family: Theme.bodyFont.family
                    font.pixelSize: Theme.scaled(11)
                    font.italic: true
                    color: root.targetManuallySet ? Theme.primaryColor : Theme.textSecondaryColor
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // Grind setting input
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.scaled(8)

                Text {
                    text: qsTr("Grind:")
                    font: Theme.bodyFont
                    color: Theme.textSecondaryColor
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Theme.scaled(55)
                }

                StyledTextField {
                    id: grindInput
                    Layout.fillWidth: true
                    text: root.grindSetting
                    onTextChanged: root.grindSetting = text
                    Accessible.name: qsTr("Grind setting")
                }
            }
        }

        // Buttons
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.scaled(20)
            Layout.rightMargin: Theme.scaled(20)
            Layout.bottomMargin: Theme.scaled(20)
            spacing: Theme.scaled(10)

            AccessibleButton {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.scaled(50)
                text: qsTr("Cancel")
                accessibleName: qsTr("Cancel brew by ratio")
                onClicked: root.reject()
                background: Rectangle {
                    implicitHeight: Theme.scaled(50)
                    radius: Theme.buttonRadius
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.textSecondaryColor
                }
                contentItem: Text {
                    text: parent.text
                    font: Theme.bodyFont
                    color: Theme.textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            AccessibleButton {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.scaled(50)
                text: qsTr("OK")
                accessibleName: qsTr("Confirm brew by ratio")
                onClicked: {
                    Settings.lastUsedRatio = root.ratio
                    // Set grind setting and make it a guest bean (golden color)
                    Settings.dyeGrinderSetting = root.grindSetting
                    Settings.selectedBeanPreset = -1  // Guest bean mode
                    // Use the configured dose and target values
                    // Calculate the effective ratio from dose and target for the controller
                    var effectiveRatio = root.targetValue / root.doseValue
                    MainController.activateBrewByRatio(root.doseValue, effectiveRatio)
                    root.accept()
                }
                background: Rectangle {
                    implicitHeight: Theme.scaled(50)
                    radius: Theme.buttonRadius
                    color: parent.down ? Qt.darker(Theme.primaryColor, 1.2) : Theme.primaryColor
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
