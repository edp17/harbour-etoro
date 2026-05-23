/*
    Copyright (C) 2026 edp17 and chatGPT

    This file is part of harbour-etoro.

    The harbour-etoro is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    The harbour-etoro is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with the harbour-etoro. If not, see <http://www.gnu.org/licenses/>.
*/
import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    id: root

    anchors.fill: parent
    visible: false
    z: 10000

    property var instrumentData: ({})
    property string errorText: ""
    property int selectedWatchlistIndex: 0
    property bool createWatchlistMode: false
    property string newWatchlistName: ""
    property bool addAfterCreateWatchlist: false
    property bool duplicateInstrument: false
    property string pendingAddedWatchlistId: ""
    property string pendingAddedWatchlistName: ""

    signal added(string watchlistId, string watchlistName)

    function selectedWatchlistName() {
        if (!etoroClient.watchlists || etoroClient.watchlists.length === 0)
            return ""

        var item = etoroClient.watchlists[root.selectedWatchlistIndex]
        return item ? String(item.name || "") : ""
    }

    function selectedWatchlistId() {
        if (!etoroClient.watchlists || etoroClient.watchlists.length === 0)
            return ""

        var item = etoroClient.watchlists[root.selectedWatchlistIndex]
        return item ? String(item.watchlistId) : ""
    }

    function refreshDuplicateState() {
        root.duplicateInstrument =
                etoroClient.currentWatchlistContainsInstrument(root.instrumentData.instrumentId)
    }

    function open() {
        root.errorText = ""
        root.selectedWatchlistIndex = 0
        root.createWatchlistMode = false
        createWatchlistSwitch.checked = false
        root.newWatchlistName = ""
        root.addAfterCreateWatchlist = false
        root.duplicateInstrument = false
        root.visible = true
        root.pendingAddedWatchlistId = ""
        root.pendingAddedWatchlistName = ""

        if (etoroClient.watchlists.length === 0)
            etoroClient.refreshWatchlists()

        var wlId = root.selectedWatchlistId()
        if (wlId !== "")
            etoroClient.loadWatchlist(wlId)
    }

    function close() {
        if (!etoroClient.busy) {
            root.visible = false
            root.errorText = ""
            etoroClient.clearLastError()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.rgba("black", 0.65)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        width: parent.width - 2 * Theme.horizontalPageMargin
        x: Theme.horizontalPageMargin
        anchors.verticalCenter: parent.verticalCenter
        height: addColumn.height + Theme.paddingLarge * 2
        radius: Theme.paddingMedium
        color: Theme.highlightDimmerColor
        border.width: 1
        border.color: Theme.rgba(Theme.highlightColor, 0.35)

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Column {
            id: addColumn
            x: Theme.paddingLarge
            y: Theme.paddingLarge
            width: parent.width - 2 * Theme.paddingLarge
            spacing: Theme.paddingMedium

            Label {
                width: parent.width
                text: qsTr("Add to watchlist")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeMedium
            }

            Label {
                width: parent.width
                text: (root.instrumentData.symbol || "") + " — " + (root.instrumentData.displayName || "")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            ComboBox {
                width: parent.width
                label: qsTr("Watchlist")
                currentIndex: root.selectedWatchlistIndex
                visible: !root.createWatchlistMode && etoroClient.watchlists.length > 0

                menu: ContextMenu {
                    Repeater {
                        model: etoroClient.watchlists

                        MenuItem {
                            text: modelData.name || modelData.watchlistId
                        }
                    }
                }

                onCurrentIndexChanged: {
                    root.selectedWatchlistIndex = currentIndex
                    root.duplicateInstrument = false

                    var wlId = root.selectedWatchlistId()
                    if (wlId !== "")
                        etoroClient.loadWatchlist(wlId)
                }
            }

            Label {
                width: parent.width
                visible: !root.createWatchlistMode && etoroClient.watchlists.length === 0
                text: qsTr("No watchlists available.")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            TextSwitch {
                id: createWatchlistSwitch
                width: parent.width
                text: qsTr("Create new watchlist")
                checked: root.createWatchlistMode
                onCheckedChanged: {
                    root.createWatchlistMode = checked
                    if (checked)
                        root.duplicateInstrument = false
                    else
                        root.refreshDuplicateState()
                }
            }

            TextField {
                width: parent.width
                visible: root.createWatchlistMode
                label: qsTr("New watchlist name")
                placeholderText: qsTr("Name")
                text: root.newWatchlistName
                onTextChanged: root.newWatchlistName = text
            }

            Label {
                width: parent.width
                visible: root.duplicateInstrument && !root.createWatchlistMode
                text: qsTr("Already in this watchlist")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                visible: root.errorText !== ""
                text: root.errorText
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            Row {
                width: parent.width
                spacing: Theme.paddingMedium

                Button {
                    width: (parent.width - Theme.paddingMedium) / 2
                    text: qsTr("Cancel")
                    enabled: !etoroClient.busy
                    onClicked: root.close()
                }

                Button {
                    width: (parent.width - Theme.paddingMedium) / 2
                    text: etoroClient.busy ? qsTr("Adding…") : qsTr("Add")
                    enabled: !etoroClient.busy
                             && (root.createWatchlistMode || etoroClient.watchlists.length > 0)
                             && (root.createWatchlistMode || !root.duplicateInstrument)

                    onClicked: {
                        root.errorText = ""

                        if (root.createWatchlistMode) {
                            if (root.newWatchlistName.trim() === "") {
                                root.errorText = qsTr("Enter a watchlist name")
                                return
                            }

                            root.addAfterCreateWatchlist = true

                            if (!etoroClient.createWatchlist(root.newWatchlistName))
                                root.errorText = etoroClient.lastError

                            return
                        }

                        var wlId = root.selectedWatchlistId()
                        if (wlId === "") {
                            root.errorText = qsTr("Select a watchlist")
                            return
                        }

                        root.pendingAddedWatchlistId = wlId
                        root.pendingAddedWatchlistName = root.selectedWatchlistName()

                        if (!etoroClient.addInstrumentToWatchlist(wlId, root.instrumentData))
                            root.errorText = etoroClient.lastError
                    }
                }
            }
        }
    }

    Connections {
        target: etoroClient

        onCurrentWatchlistItemsChanged: {
            if (root.visible)
                root.refreshDuplicateState()
        }

        onWatchlistCreated: {
            if (!root.addAfterCreateWatchlist)
                return

            root.addAfterCreateWatchlist = false
            root.pendingAddedWatchlistId = watchlistId
            root.pendingAddedWatchlistName = name

            if (watchlistId === "") {
                root.errorText = qsTr("Watchlist created, but its ID was not returned. Refresh watchlists and try adding again.")
                return
            }

            if (!etoroClient.addInstrumentToWatchlist(watchlistId, root.instrumentData))
                root.errorText = etoroClient.lastError
        }

        onWatchlistItemAdded: {
            root.visible = false
            root.errorText = ""
            etoroClient.clearLastError()
            root.added(root.pendingAddedWatchlistId, root.pendingAddedWatchlistName)
        }

        onLastErrorChanged: {
            if (!root.visible)
                return

            if (root.addAfterCreateWatchlist
                    && (etoroClient.lastError === ""
                        || etoroClient.lastError === "Watchlist created."))
                return

            if (root.addAfterCreateWatchlist)
                root.addAfterCreateWatchlist = false

            if (etoroClient.lastError !== ""
                    && etoroClient.lastError !== "Instrument added to watchlist."
                    && etoroClient.lastError !== "Watchlist created.")
                root.errorText = etoroClient.lastError
        }
    }
}
