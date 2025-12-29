import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import DecenzaDE1
import "../components"

Page {
    id: profileSelectorPage
    objectName: "profileSelectorPage"
    background: Rectangle { color: Theme.backgroundColor }

    Component.onCompleted: root.currentPageTitle = "Profiles"
    StackView.onActivated: root.currentPageTitle = "Profiles"

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.standardMargin
        anchors.topMargin: Theme.pageTopMargin
        anchors.bottomMargin: Theme.pageTopMargin
        spacing: Theme.scaled(20)

        // LEFT SIDE: All available profiles
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surfaceColor
            radius: Theme.cardRadius

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.scaled(15)
                spacing: Theme.scaled(10)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.scaled(10)

                    Text {
                        text: "All Profiles"
                        font: Theme.subtitleFont
                        color: Theme.textColor
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Import from Visualizer"
                        Layout.preferredHeight: Theme.scaled(36)
                        onClicked: root.goToVisualizerBrowser()

                        background: Rectangle {
                            radius: Theme.scaled(4)
                            color: Theme.primaryColor
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            font: Theme.captionFont
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: Theme.scaled(12)
                            rightPadding: Theme.scaled(12)
                        }
                    }
                }

                ListView {
                    id: allProfilesList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: MainController.availableProfiles
                    spacing: Theme.scaled(4)

                    delegate: Rectangle {
                        width: allProfilesList.width
                        height: Theme.scaled(60)
                        radius: Theme.scaled(6)
                        color: modelData.name === MainController.currentProfile ?
                               Qt.rgba(Theme.primaryColor.r, Theme.primaryColor.g, Theme.primaryColor.b, 0.2) :
                               (index % 2 === 0 ? "#1a1a1a" : "#2a2a2a")

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.scaled(10)
                            spacing: Theme.scaled(10)

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: modelData.title
                                color: Theme.textColor
                                font: Theme.bodyFont
                                elide: Text.ElideRight
                            }

                            // Add to favorites button (show when not already a favorite)
                            // Note: Reference favoriteProfiles.length to create binding dependency for refresh
                            RoundButton {
                                id: addFavoriteButton
                                visible: Settings.favoriteProfiles.length >= 0 && !Settings.isFavoriteProfile(modelData.name)
                                enabled: Settings.favoriteProfiles.length < 5
                                Layout.preferredWidth: Theme.scaled(40)
                                Layout.preferredHeight: Theme.scaled(40)
                                Layout.alignment: Qt.AlignVCenter
                                flat: true
                                text: "+"
                                font.pixelSize: Theme.scaled(24)
                                font.bold: true

                                property bool favoritesFull: Settings.favoriteProfiles.length >= 5

                                function doAddFavorite() {
                                    if (!modelData) return
                                    if (favoritesFull) {
                                        if (typeof AccessibilityManager !== "undefined" && AccessibilityManager.enabled) {
                                            AccessibilityManager.announce("Favorites full. Remove one to add more.")
                                        }
                                        return
                                    }
                                    Settings.addFavoriteProfile(modelData.title, modelData.name)
                                    if (typeof AccessibilityManager !== "undefined" && AccessibilityManager.enabled) {
                                        AccessibilityManager.announce(root.cleanForSpeech(modelData.title || modelData.name) + " added to favorites")
                                    }
                                }

                                onClicked: doAddFavorite()

                                contentItem: Text {
                                    text: parent.text
                                    font: parent.font
                                    color: addFavoriteButton.favoritesFull ? Theme.textSecondaryColor : Theme.primaryColor
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: addFavoriteButton.favoritesFull ? Theme.textSecondaryColor : Theme.primaryColor
                                    border.width: 1
                                }

                                AccessibleMouseArea {
                                    anchors.fill: parent
                                    accessibleName: {
                                        if (!modelData) return ""
                                        if (addFavoriteButton.favoritesFull) {
                                            return "Favorites full, cannot add " + root.cleanForSpeech(modelData.title || modelData.name)
                                        }
                                        return "Add " + root.cleanForSpeech(modelData.title || modelData.name) + " to favorites"
                                    }
                                    accessibleItem: addFavoriteButton
                                    onAccessibleClicked: addFavoriteButton.doAddFavorite()
                                }
                            }

                            // Already favorite indicator (star)
                            // Note: Reference favoriteProfiles.length to create binding dependency for refresh
                            Item {
                                visible: Settings.favoriteProfiles.length >= 0 && Settings.isFavoriteProfile(modelData.name)
                                Layout.preferredWidth: Theme.scaled(40)
                                Layout.preferredHeight: Theme.scaled(40)
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "\u2605"  // Star
                                    color: Theme.primaryColor
                                    font.pixelSize: Theme.scaled(20)
                                }

                                AccessibleMouseArea {
                                    anchors.fill: parent
                                    accessibleName: modelData ? (root.cleanForSpeech(modelData.title || modelData.name) + " is already a favorite") : ""
                                    accessibleItem: parent
                                    onAccessibleClicked: {
                                        // Just announce, no action needed
                                        if (typeof AccessibilityManager !== "undefined" && AccessibilityManager.enabled) {
                                            AccessibilityManager.announce("Already in favorites")
                                        }
                                    }
                                }
                            }
                        }

                        AccessibleMouseArea {
                            anchors.fill: parent
                            z: -1
                            accessibleName: modelData ? (root.cleanForSpeech(modelData.name) + " profile") : ""
                            accessibleItem: parent
                            onAccessibleClicked: {
                                if (!modelData) return
                                if (typeof AccessibilityManager !== "undefined" && AccessibilityManager.enabled) {
                                    AccessibilityManager.announce(root.cleanForSpeech(modelData.name) + " loaded")
                                }
                                MainController.loadProfile(modelData.name)
                            }
                        }
                    }
                }
            }
        }

        // RIGHT SIDE: Favorite profiles (max 5)
        Rectangle {
            Layout.preferredWidth: Theme.scaled(380)
            Layout.fillHeight: true
            color: Theme.surfaceColor
            radius: Theme.cardRadius

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.scaled(15)
                spacing: Theme.scaled(10)

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Favorites (" + Settings.favoriteProfiles.length + "/5)"
                        font: Theme.subtitleFont
                        color: Theme.textColor
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        visible: Settings.favoriteProfiles.length > 1
                        text: "Drag to reorder"
                        font: Theme.captionFont
                        color: Theme.textSecondaryColor
                    }
                }

                // Empty state
                Text {
                    visible: Settings.favoriteProfiles.length === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: "No favorites yet.\nTap + on a profile to add it."
                    color: Theme.textSecondaryColor
                    font: Theme.bodyFont
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.Wrap
                }

                ListView {
                    id: favoritesList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    visible: Settings.favoriteProfiles.length > 0
                    model: Settings.favoriteProfiles
                    spacing: Theme.scaled(8)

                    delegate: Item {
                        id: favoriteDelegate
                        width: favoritesList.width
                        height: Theme.scaled(60)

                        property int favoriteIndex: index

                        Rectangle {
                            id: favoritePill
                            anchors.fill: parent
                            radius: Theme.scaled(8)
                            color: index === Settings.selectedFavoriteProfile ?
                                   Theme.primaryColor : Theme.backgroundColor
                            border.color: Theme.textSecondaryColor
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.scaled(10)
                                spacing: Theme.scaled(8)

                                // Drag handle
                                Text {
                                    text: "\u2261"  // Hamburger menu icon
                                    font.pixelSize: Theme.scaled(24)
                                    color: index === Settings.selectedFavoriteProfile ?
                                           "white" : Theme.textSecondaryColor

                                    MouseArea {
                                        id: dragArea
                                        anchors.fill: parent
                                        drag.target: favoritePill
                                        drag.axis: Drag.YAxis

                                        property int startIndex: -1

                                        onPressed: {
                                            startIndex = favoriteDelegate.favoriteIndex
                                            favoritePill.anchors.fill = undefined
                                        }

                                        onReleased: {
                                            favoritePill.anchors.fill = parent
                                            // Calculate new position based on Y
                                            var newIndex = Math.floor((favoritePill.y + favoritePill.height/2) / (Theme.scaled(60) + Theme.scaled(8)))
                                            newIndex = Math.max(0, Math.min(newIndex, Settings.favoriteProfiles.length - 1))
                                            if (newIndex !== startIndex && startIndex >= 0) {
                                                Settings.moveFavoriteProfile(startIndex, newIndex)
                                            }
                                        }
                                    }
                                }

                                // Profile name
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: index === Settings.selectedFavoriteProfile ?
                                           "white" : Theme.textColor
                                    font: Theme.bodyFont
                                    elide: Text.ElideRight
                                }

                                // Edit button
                                RoundButton {
                                    id: editFavoriteButton
                                    Layout.preferredWidth: Theme.scaled(36)
                                    Layout.preferredHeight: Theme.scaled(36)
                                    flat: true
                                    icon.source: "qrc:/icons/edit.svg"
                                    icon.width: Theme.scaled(18)
                                    icon.height: Theme.scaled(18)
                                    icon.color: index === Settings.selectedFavoriteProfile ?
                                               "white" : Theme.textColor

                                    function doEdit() {
                                        if (!modelData) return
                                        Settings.selectedFavoriteProfile = index
                                        MainController.loadProfile(modelData.filename)
                                        root.goToProfileEditor()
                                    }

                                    onClicked: doEdit()

                                    AccessibleMouseArea {
                                        anchors.fill: parent
                                        accessibleName: modelData ? ("Edit " + root.cleanForSpeech(modelData.name)) : ""
                                        accessibleItem: editFavoriteButton
                                        onAccessibleClicked: editFavoriteButton.doEdit()
                                    }
                                }

                                // Remove button
                                RoundButton {
                                    id: removeFavoriteButton
                                    Layout.preferredWidth: Theme.scaled(36)
                                    Layout.preferredHeight: Theme.scaled(36)
                                    flat: true
                                    text: "\u00D7"  // × multiplication sign
                                    font.pixelSize: Theme.scaled(20)

                                    function doRemove() {
                                        if (!modelData) return
                                        var name = root.cleanForSpeech(modelData.name)
                                        Settings.removeFavoriteProfile(index)
                                        if (typeof AccessibilityManager !== "undefined" && AccessibilityManager.enabled) {
                                            AccessibilityManager.announce(name + " removed from favorites")
                                        }
                                    }

                                    onClicked: doRemove()

                                    contentItem: Text {
                                        text: parent.text
                                        font: parent.font
                                        color: Theme.errorColor
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        radius: width / 2
                                        color: "transparent"
                                    }

                                    AccessibleMouseArea {
                                        anchors.fill: parent
                                        accessibleName: modelData ? ("Remove " + root.cleanForSpeech(modelData.name) + " from favorites") : ""
                                        accessibleItem: removeFavoriteButton
                                        onAccessibleClicked: removeFavoriteButton.doRemove()
                                    }
                                }
                            }

                            AccessibleMouseArea {
                                anchors.fill: parent
                                z: -1
                                accessibleName: modelData ? (root.cleanForSpeech(modelData.name) + (index === Settings.selectedFavoriteProfile ? ", selected favorite" : ", favorite")) : ""
                                accessibleItem: favoritePill
                                onAccessibleClicked: {
                                    if (!modelData) return
                                    // Always load the profile when clicking
                                    MainController.loadProfile(modelData.filename)
                                    if (index === Settings.selectedFavoriteProfile) {
                                        // Already selected - open editor
                                        root.goToProfileEditor()
                                    } else {
                                        // Select it (first click)
                                        if (typeof AccessibilityManager !== "undefined" && AccessibilityManager.enabled) {
                                            AccessibilityManager.announce(root.cleanForSpeech(modelData.name) + " selected")
                                        }
                                        Settings.selectedFavoriteProfile = index
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Bottom bar
    BottomBar {
        title: "Profiles"
        rightText: "Current: " + MainController.currentProfileName
        onBackClicked: root.goBack()
    }
}
