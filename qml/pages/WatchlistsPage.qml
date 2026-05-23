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
import "../components"

Page {
    id: page

    property string selectedWatchlistId: ""
    property string selectedWatchlistName: ""
    property bool showFilterControls: false
    property string filterText: etoroClient.watchlistFilterText
    property var filteredItems: []
    property bool readOnlyMode: !etoroClient.tradingEnabled
    property bool reloadSelectedAfterWatchlistsRefresh: false
    property string reloadSelectedWatchlistId: ""
    property bool renameWatchlistVisible: false
    property string renameWatchlistText: ""
    property string renameWatchlistError: ""

    function numberText(v, decimals) {
        if (v === undefined || v === null || v === "")
            return "—"
        return Number(v).toLocaleString(Qt.locale(), 'f', decimals)
    }

    function quoteFor(item) {
        return etoroClient.quoteForWatchlistInstrument(item.instrumentId)
    }

    function selectedWatchlistIndex() {
        var list = etoroClient.watchlists
        for (var i = 0; i < list.length; ++i) {
            if (String(list[i].watchlistId || "") === page.selectedWatchlistId)
                return i
        }

        for (var j = 0; j < list.length; ++j) {
            if (list[j].isDefault === true || list[j].isUserSelectedDefault === true)
                return j
        }

        return list.length > 0 ? 0 : -1
    }

    function ensureSelectedWatchlist() {
        var idx = selectedWatchlistIndex()
        if (idx < 0 || idx >= etoroClient.watchlists.length)
            return

        var wl = etoroClient.watchlists[idx]
        var id = String(wl.watchlistId || "")
        var name = String(wl.name || "")

        if (page.selectedWatchlistId !== id || etoroClient.currentWatchlistName !== name) {
            page.selectedWatchlistId = id
            page.selectedWatchlistName = name
            etoroClient.loadWatchlist(id, name)
        }

        if (watchlistCombo.currentIndex !== idx)
            watchlistCombo.currentIndex = idx
    }

    function instrumentIcon50(instrumentId) {
        if (instrumentId === undefined || instrumentId === null || instrumentId === "")
            return ""

        return "https://etoro-cdn.etorostatic.com/market-avatars/"
                + String(instrumentId)
                + "/50x50.png"
    }

    function applyFilter() {
        var source = etoroClient.currentWatchlistItems
        var q = filterText ? filterText.toLowerCase().trim() : ""
        var out = []

        for (var i = 0; i < source.length; ++i) {
            var item = source[i]
            var name = String(item.displayName || "").toLowerCase()
            var symbol = String(item.symbol || "").toLowerCase()
            var instrumentId = String(item.instrumentId || "").toLowerCase()

            if (!q
                    || name.indexOf(q) !== -1
                    || symbol.indexOf(q) !== -1
                    || instrumentId.indexOf(q) !== -1) {
                out.push(item)
            }
        }

        filteredItems = out
    }

    Timer {
        id: filterDebounceTimer
        interval: 180
        repeat: false
        onTriggered: page.applyFilter()
    }

    Timer {
        id: watchlistQuoteRefreshTimer
        repeat: true
        running: page.status === PageStatus.Active
                 && etoroClient.quoteRefreshIntervalSeconds > 0
                 && !etoroClient.locked
                 && page.filteredItems.length > 0
                 && !etoroClient.quoteRefreshCoolingDown
        interval: etoroClient.effectiveQuoteRefreshIntervalSeconds("watchlist") * 1000

        onTriggered: {
            if (!etoroClient.currentWatchlistQuotesLoading) {
                etoroClient.refreshCurrentWatchlistQuotes()
            }
        }
    }

    onFilterTextChanged: {
        filterDebounceTimer.restart()
    }

    Connections {
        target: etoroClient

        onWatchlistsChanged: {
            if (page.reloadSelectedAfterWatchlistsRefresh) {
                page.reloadSelectedAfterWatchlistsRefresh = false

                var wantedId = page.reloadSelectedWatchlistId
                page.reloadSelectedWatchlistId = ""

                for (var i = 0; i < etoroClient.watchlists.length; ++i) {
                    var wl = etoroClient.watchlists[i]
                    if (String(wl.watchlistId || "") === wantedId) {
                        page.selectedWatchlistId = String(wl.watchlistId || "")
                        page.selectedWatchlistName = String(wl.name || "")
                        watchlistCombo.currentIndex = i
                        etoroClient.loadWatchlist(page.selectedWatchlistId, page.selectedWatchlistName)
                        return
                    }
                }
            }

            page.ensureSelectedWatchlist()
        }

        onCurrentWatchlistItemsChanged: {
            page.applyFilter()
        }

        onCurrentWatchlistQuotesChanged: {
            page.applyFilter()
        }
    }

    Component.onCompleted: {
        filterField.text = etoroClient.watchlistFilterText
        page.filterText = etoroClient.watchlistFilterText
        page.ensureSelectedWatchlist()
        page.applyFilter()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh quotes")
                enabled: !etoroClient.currentWatchlistQuotesLoading && !etoroClient.locked
                onClicked: {
                    etoroClient.registerUserActivity()
                    etoroClient.refreshCurrentWatchlistQuotes()
                }
            }

            MenuItem {
                text: qsTr("Refresh watchlists")
                enabled: !etoroClient.busy && !etoroClient.locked
                onClicked: {
                    etoroClient.registerUserActivity()
                    page.reloadSelectedAfterWatchlistsRefresh = true
                    page.reloadSelectedWatchlistId = page.selectedWatchlistId
                    etoroClient.refreshWatchlists()
                }
            }
            MenuItem {
                text: qsTr("Discover")
                onClicked: pageStack.push(Qt.resolvedUrl("DiscoverPage.qml"))
            }
            MenuItem {
                text: qsTr("Rename watchlist")
                enabled: !etoroClient.busy && page.selectedWatchlistId !== ""
                onClicked: renameWatchlistOverlay.open()
            }
            MenuItem {
                text: qsTr("Delete watchlist")
                enabled: !etoroClient.busy && page.selectedWatchlistId !== ""
                onClicked: deleteWatchlistOverlay.open()
            }
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Watchlists (%1)").arg(etoroClient.accountModeLabel)
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.readOnlyMode
                height: readOnlyColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: readOnlyColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Read-only mode")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Trading is disabled. Watchlists and live quotes remain available, but trading actions are not.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: headerCard.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: headerCard
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        visible: etoroClient.quoteRefreshCoolingDown
                        text: etoroClient.quoteRateLimitMessage
                        color: Theme.errorColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        ComboBox {
                            id: watchlistCombo
                            width: parent.width - filterToggle.width - Theme.paddingMedium
                            label: qsTr("Watchlist")

                            menu: ContextMenu {
                                Repeater {
                                    model: etoroClient.watchlists

                                    delegate: MenuItem {
                                        text: modelData.name || qsTr("Unnamed watchlist")
                                    }
                                }
                            }

                            currentIndex: -1

                            onCurrentIndexChanged: {
                                if (currentIndex < 0 || currentIndex >= etoroClient.watchlists.length)
                                    return

                                var wl = etoroClient.watchlists[currentIndex]
                                var id = String(wl.watchlistId || "")
                                var name = String(wl.name || "")

                                page.selectedWatchlistId = id
                                page.selectedWatchlistName = name

                                etoroClient.registerUserActivity()
                                etoroClient.loadWatchlist(id, name)
                            }
                        }

                        IconButton {
                            id: filterToggle
                            icon.source: "image://theme/icon-m-search"
                            highlighted: page.showFilterControls
                            onClicked: {
                                page.showFilterControls = !page.showFilterControls
                                etoroClient.registerUserActivity()

                                if (!page.showFilterControls) {
                                    filterField.text = ""
                                    page.filterText = ""
                                    etoroClient.setWatchlistFilterText("")
                                }
                            }
                        }
                    }

                    SearchField {
                        id: filterField
                        width: parent.width
                        visible: page.showFilterControls
                        placeholderText: qsTr("Filter by name, symbol or ID")
                        onTextChanged: {
                            page.filterText = text
                            etoroClient.registerUserActivity()
                            etoroClient.setWatchlistFilterText(text)
                        }
                    }

                    Label {
                        width: parent.width
                        visible: etoroClient.watchlistItemsLoading
                        text: qsTr("Loading watchlist items…")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        visible: false //etoroClient.currentWatchlistQuotesLoading
                        text: qsTr("Refreshing quotes…")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        visible: !etoroClient.watchlistItemsLoading && page.filteredItems.length === 0
                        text: page.filterText.trim().length > 0
                              ? qsTr("No asset match the current filter.")
                              : qsTr("No assets in this watchlist.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !etoroClient.watchlistItemsLoading && page.filteredItems.length > 0
                height: compactHeaderRow.height + Theme.paddingSmall * 2
                radius: Theme.paddingSmall
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.06)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.12)

                Row {
                    id: compactHeaderRow
                    x: Theme.paddingSmall
                    y: Theme.paddingSmall
                    width: parent.width - 2 * Theme.paddingSmall
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width * 0.32
                        text: qsTr("Markets")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeTiny
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width * 0.29
                        text: qsTr("Sell")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeTiny
                        horizontalAlignment: Text.AlignRight
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width * 0.29
                        text: qsTr("Buy")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeTiny
                        horizontalAlignment: Text.AlignRight
                        truncationMode: TruncationMode.Fade
                    }
                }
            }

            Repeater {
                model: etoroClient.watchlistItemsLoading ? [] : page.filteredItems

                delegate: BackgroundItem {
                    width: parent ? parent.width : page.width
                    height: compactColumn.height + Theme.paddingSmall * 2

                    property var quotesMap: etoroClient.currentWatchlistQuotes
                    property var quote: quotesMap[String(modelData.instrumentId)] || ({})

                    onClicked: {
                        etoroClient.registerUserActivity()
                        pageStack.push(Qt.resolvedUrl("WatchlistDetailPage.qml"), {
                            instrumentData: modelData,
                            watchlistId: page.selectedWatchlistId,
                            watchlistName: page.selectedWatchlistName
                        })
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.rightMargin: Theme.horizontalPageMargin
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: Theme.paddingSmall
                        color: Theme.rgba(Theme.highlightBackgroundColor, 0.06)
                        border.width: 1
                        border.color: Theme.rgba(Theme.highlightColor, 0.10)
                    }

                    Column {
                        id: compactColumn
                        x: Theme.horizontalPageMargin + Theme.paddingSmall
                        y: Theme.paddingSmall
                        width: parent.width - 2 * Theme.horizontalPageMargin - 2 * Theme.paddingSmall
                        spacing: 2

                        Row {
                            width: parent.width
                            spacing: Theme.paddingSmall

                            Image {
                                id: logoImage
                                source: instrumentIcon50(modelData.instrumentId)
                                width: 50
                                height: 50
                                fillMode: Image.PreserveAspectFit
                            }

                            Column {
                                width: parent.width * 0.32
                                spacing: 0

                                Label {
                                    width: parent.width
                                    text: modelData.symbol || ("#" + modelData.instrumentId)
                                    color: Theme.primaryColor
                                    font.pixelSize: Theme.fontSizeSmall
                                    truncationMode: TruncationMode.Fade
                                }

                                Label {
                                    width: parent.width
                                    text: modelData.displayName || ""
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeTiny
                                    truncationMode: TruncationMode.Fade
                                    visible: (modelData.displayName || "").length > 0
                                }
                            }

                            Item {
                                width: parent.width * 0.29
                                height: bidValue.implicitHeight

                                PriceFlashValue {
                                    id: bidValue
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    rawValue: quote ? quote.bid : ""
                                    decimals: 4
                                    textColor: Theme.primaryColor
                                    fontSize: Theme.fontSizeSmall
                                }
                            }

                            Item {
                                width: parent.width * 0.29
                                height: askValue.implicitHeight

                                PriceFlashValue {
                                    id: askValue
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    rawValue: quote ? quote.ask : ""
                                    decimals: 4
                                    textColor: Theme.primaryColor
                                    fontSize: Theme.fontSizeSmall
                                }
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }

        VerticalScrollDecorator { }
    }

    // Rename watchlist overlay
    RenameWatchlistOverlay {
        id: renameWatchlistOverlay
        watchlistId: page.selectedWatchlistId
        watchlistName: page.selectedWatchlistName

        onRenamed: {
            page.reloadSelectedAfterWatchlistsRefresh = true
            page.reloadSelectedWatchlistId = watchlistId
        }
    }

    // Delete watchlist overlay
    DeleteWatchlistOverlay {
        id: deleteWatchlistOverlay
        watchlistId: page.selectedWatchlistId
        watchlistName: page.selectedWatchlistName

        onDeleted: {
            page.selectedWatchlistId = ""
            page.selectedWatchlistName = ""
            page.reloadSelectedAfterWatchlistsRefresh = false
        }
    }
}
