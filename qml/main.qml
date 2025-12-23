import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DE1App

ApplicationWindow {
    id: root
    visible: true
    width: 1280
    height: 800
    title: "DE1 Controller"
    color: Theme.backgroundColor

    // Current page title - set by each page
    property string currentPageTitle: ""

    // Update scale factor when window resizes
    onWidthChanged: updateScale()
    onHeightChanged: updateScale()
    Component.onCompleted: updateScale()

    function updateScale() {
        // Scale based on the smaller ratio to maintain aspect ratio
        var scaleX = width / Theme.refWidth
        var scaleY = height / Theme.refHeight
        Theme.scale = Math.min(scaleX, scaleY)
    }

    // Page stack for navigation
    StackView {
        id: pageStack
        anchors.fill: parent
        initialItem: idlePage

        Component {
            id: idlePage
            IdlePage {}
        }

        Component {
            id: espressoPage
            EspressoPage {}
        }

        Component {
            id: steamPage
            SteamPage {}
        }

        Component {
            id: hotWaterPage
            HotWaterPage {}
        }

        Component {
            id: settingsPage
            SettingsPage {}
        }

        Component {
            id: profileEditorPage
            ProfileEditorPage {}
        }
    }

    // Status bar overlay
    StatusBar {
        id: statusBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        z: 100
    }

    // Connection state handler - auto navigate based on machine state
    Connections {
        target: MachineState

        function onPhaseChanged() {
            // Don't navigate while a transition is in progress
            if (pageStack.busy) return

            let phase = MachineState.phase
            let currentPage = pageStack.currentItem ? pageStack.currentItem.objectName : ""

            // Only auto-navigate during active operations
            if (phase === MachineStateType.Phase.EspressoPreheating ||
                phase === MachineStateType.Phase.Preinfusion ||
                phase === MachineStateType.Phase.Pouring ||
                phase === MachineStateType.Phase.Ending) {
                if (currentPage !== "espressoPage") {
                    pageStack.replace(espressoPage)
                }
            } else if (phase === MachineStateType.Phase.Steaming) {
                if (currentPage !== "steamPage") {
                    pageStack.replace(steamPage)
                }
            } else if (phase === MachineStateType.Phase.HotWater ||
                       phase === MachineStateType.Phase.Flushing) {
                if (currentPage !== "hotWaterPage") {
                    pageStack.replace(hotWaterPage)
                }
            }
        }
    }

    // Helper functions for navigation
    function goToIdle() {
        pageStack.replace(idlePage)
    }

    function goToEspresso() {
        pageStack.replace(espressoPage)
    }

    function goToSteam() {
        pageStack.replace(steamPage)
    }

    function goToHotWater() {
        pageStack.replace(hotWaterPage)
    }

    function goToSettings() {
        pageStack.push(settingsPage)
    }

    function goBack() {
        if (pageStack.depth > 1) {
            pageStack.pop()
        }
    }

    function goToProfileEditor() {
        pageStack.push(profileEditorPage)
    }
}
