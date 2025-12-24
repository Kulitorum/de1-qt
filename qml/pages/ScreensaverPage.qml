import QtQuick
import QtQuick.Controls
import QtMultimedia
import DE1App

Page {
    id: screensaverPage
    objectName: "screensaverPage"
    background: Rectangle { color: "black" }

    property int videoFailCount: 0
    property bool videoPlaying: false
    property string lastFailedSource: ""

    Component.onCompleted: {
        playNextVideo()
    }

    // Listen for new videos becoming available (downloaded)
    Connections {
        target: ScreensaverManager
        function onVideoReady(path) {
            // A video just finished downloading - try to play if we're showing fallback
            if (!videoPlaying) {
                console.log("[Screensaver] New video ready, starting playback")
                playNextVideo()
            }
        }
        function onCatalogUpdated() {
            // Catalog loaded - try to play if we're showing fallback
            if (!videoPlaying && ScreensaverManager.itemCount > 0) {
                console.log("[Screensaver] Catalog updated, trying playback")
                playNextVideo()
            }
        }
    }

    function playNextVideo() {
        if (!ScreensaverManager.enabled) {
            return
        }

        var source = ScreensaverManager.getNextVideoSource()
        if (source && source.length > 0) {
            console.log("[Screensaver] Playing:", source)
            videoPlaying = true
            mediaPlayer.source = source
            mediaPlayer.play()
        } else {
            // No cached videos yet - show fallback, wait for downloads
            console.log("[Screensaver] No cached videos yet, showing fallback")
            videoPlaying = false
        }
    }

    function handleVideoFailure() {
        // Prevent handling the same failure twice
        var currentSource = mediaPlayer.source.toString()
        if (currentSource === lastFailedSource) return
        lastFailedSource = currentSource

        videoFailCount++
        console.log("[Screensaver] Video failed (" + videoFailCount + ")")

        if (videoFailCount >= 5) {
            console.log("[Screensaver] Too many failures, showing fallback")
            videoPlaying = false
            mediaPlayer.stop()
            videoFailCount = 0  // Reset for when new videos download
            return
        }

        // Try next cached video
        playNextVideo()
    }

    MediaPlayer {
        id: mediaPlayer
        audioOutput: AudioOutput { volume: 0 }  // Muted
        videoOutput: videoOutput

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia) {
                // Mark current video as played for LRU tracking
                ScreensaverManager.markVideoPlayed(source.toString())
                // Play next video (reset fail count on success)
                videoFailCount = 0
                lastFailedSource = ""
                playNextVideo()
            } else if (mediaStatus === MediaPlayer.InvalidMedia ||
                       mediaStatus === MediaPlayer.NoMedia) {
                handleVideoFailure()
            }
        }

        onErrorOccurred: {
            handleVideoFailure()
        }

        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.PlayingState) {
                videoFailCount = 0
                lastFailedSource = ""
            }
        }
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        visible: videoPlaying
    }

    // Fallback: show a subtle animation while no cached videos
    Rectangle {
        id: fallbackBackground
        anchors.fill: parent
        visible: !videoPlaying || mediaPlayer.playbackState !== MediaPlayer.PlayingState
        z: 1

        Rectangle {
            id: gradientRect
            anchors.fill: parent
            property real gradientHue: 0.6

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.hsla(gradientRect.gradientHue, 0.4, 0.15, 1.0)
                }
                GradientStop {
                    position: 1.0
                    color: Qt.hsla((gradientRect.gradientHue + 0.5) % 1.0, 0.4, 0.08, 1.0)
                }
            }

            NumberAnimation on gradientHue {
                from: 0
                to: 1
                duration: 30000
                loops: Animation.Infinite
            }
        }
    }

    // Credits display at bottom (one-liner for current video)
    Rectangle {
        z: 2
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 40
        color: Qt.rgba(0, 0, 0, 0.5)
        visible: ScreensaverManager.currentVideoAuthor.length > 0 &&
                 mediaPlayer.playbackState === MediaPlayer.PlayingState

        Text {
            anchors.centerIn: parent
            text: "Video by " + ScreensaverManager.currentVideoAuthor + " (Pexels)"
            color: "white"
            opacity: 0.7
            font.pixelSize: 14
        }
    }

    // Clock display
    Text {
        z: 2
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 50
        anchors.bottomMargin: 60  // Above credits bar
        text: Qt.formatTime(currentTime, "hh:mm")
        color: "white"
        opacity: 0.8
        font.pixelSize: 80
        font.weight: Font.Light

        property date currentTime: new Date()

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: parent.currentTime = new Date()
        }
    }

    // Download progress indicator (subtle)
    Rectangle {
        z: 2
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 3
        color: "transparent"
        visible: ScreensaverManager.isDownloading

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * ScreensaverManager.downloadProgress
            color: Theme.primaryColor
            opacity: 0.6

            Behavior on width {
                NumberAnimation { duration: 300 }
            }
        }
    }

    // Touch hint (fades out)
    Text {
        id: touchHint
        z: 2
        anchors.centerIn: parent
        text: "Touch to wake"
        color: "white"
        opacity: 0.5
        font.pixelSize: 24

        OpacityAnimator {
            target: touchHint
            from: 0.5
            to: 0
            duration: 3000
            running: true
        }
    }

    // Touch anywhere to wake
    MouseArea {
        z: 3
        anchors.fill: parent
        onClicked: wake()
        onPressed: wake()
    }

    // Also wake on key press
    Keys.onPressed: wake()

    function wake() {
        // Stop video
        mediaPlayer.stop()

        // Wake up the DE1
        if (DE1Device.connected) {
            DE1Device.wakeUp()
        }

        // Wake the scale (enable LCD) or try to reconnect
        if (ScaleDevice && ScaleDevice.connected) {
            ScaleDevice.wake()
        } else {
            BLEManager.tryDirectConnectToScale()
        }

        // Navigate back to idle
        root.goToIdle()
    }

    // Auto-wake when DE1 wakes up externally (button press on machine)
    Connections {
        target: DE1Device
        function onStateChanged() {
            var state = DE1Device.stateString
            if (state !== "Sleep" && state !== "GoingToSleep") {
                mediaPlayer.stop()
                if (ScaleDevice && ScaleDevice.connected) {
                    ScaleDevice.wake()
                } else {
                    BLEManager.tryDirectConnectToScale()
                }
                root.goToIdle()
            }
        }
    }
}
