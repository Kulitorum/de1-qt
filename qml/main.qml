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

    // Put machine and scale to sleep when closing the app
    onClosing: function(close) {
        // Send scale sleep first (it's faster/simpler)
        if (ScaleDevice && ScaleDevice.connected) {
            console.log("Sending scale to sleep on app close")
            ScaleDevice.sleep()
        }

        // Small delay before sending DE1 sleep to let scale command go through
        close.accepted = false
        scaleSleepTimer.start()
    }

    Timer {
        id: scaleSleepTimer
        interval: 150  // Give scale sleep command time to send
        onTriggered: {
            // Now send DE1 to sleep
            if (DE1Device && DE1Device.connected) {
                console.log("Sending DE1 to sleep on app close")
                DE1Device.goToSleep()
            }
            // Wait for DE1 command to complete
            closeTimer.start()
        }
    }

    Timer {
        id: closeTimer
        interval: 300  // 300ms to allow BLE commands to complete
        onTriggered: Qt.quit()
    }

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

        Component {
            id: screensaverPage
            ScreensaverPage {}
        }
    }

    // Global error dialog for BLE issues
    Dialog {
        id: bleErrorDialog
        title: "Enable Location"
        modal: true
        anchors.centerIn: parent

        property string errorMessage: ""
        property bool isLocationError: false

        Column {
            spacing: 16
            width: 320

            Label {
                text: bleErrorDialog.errorMessage
                wrapMode: Text.Wrap
                width: parent.width
            }

            Button {
                text: "Open Location Settings"
                visible: bleErrorDialog.isLocationError
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    BLEManager.openLocationSettings()
                    bleErrorDialog.close()
                }
            }

            Button {
                text: "OK"
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: bleErrorDialog.close()
            }
        }
    }

    Connections {
        target: BLEManager
        function onErrorOccurred(error) {
            if (error.indexOf("Location") !== -1) {
                bleErrorDialog.isLocationError = true
                bleErrorDialog.errorMessage = "Please enable Location services.\nAndroid requires Location for Bluetooth scanning."
            } else {
                bleErrorDialog.isLocationError = false
                bleErrorDialog.errorMessage = error
            }
            bleErrorDialog.open()
        }
    }

    // Status bar overlay (hidden during screensaver)
    StatusBar {
        id: statusBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 50
        z: 100
        visible: !pageStack.currentItem || pageStack.currentItem.objectName !== "screensaverPage"
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

    function goToScreensaver() {
        pageStack.replace(screensaverPage)
    }
}
