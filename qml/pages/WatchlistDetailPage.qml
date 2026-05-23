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

    property var instrumentData: ({ })
    property bool readOnlyMode: !etoroClient.tradingEnabled

    property string watchlistId: ""
    property string watchlistName: ""
    property bool openedFromWatchlist: false

    function restrictionValue(key) {
        if (page.instrumentData && page.instrumentData[key] !== undefined)
            return page.instrumentData[key]

        var cached = etoroClient.restrictionsForInstrument(page.instrumentData.instrumentId)
        if (cached && cached[key] !== undefined)
            return cached[key]

        return undefined
    }

    function mergeInstrumentDataPreservingRestrictions(newData) {
        if (!newData)
            return page.instrumentData

        var merged = {}
        var key

        for (key in page.instrumentData)
            merged[key] = page.instrumentData[key]

        for (key in newData)
            merged[key] = newData[key]

        var restrictionKeys = [
            "isBuyEnabled",
            "isCurrentlyTradable",
            "isExchangeOpen",
            "tradingDisabled"
        ]

        for (var i = 0; i < restrictionKeys.length; ++i) {
            key = restrictionKeys[i]

            if ((newData[key] === undefined || newData[key] === null || newData[key] === "")
                    && page.instrumentData[key] !== undefined) {
                merged[key] = page.instrumentData[key]
            }
        }

        return merged
    }

    function applyWatchlistMatches() {
        var matches = etoroClient.instrumentWatchlistMatches || []

        if (matches.length === 0)
            return

        var first = matches[0]

        page.instrumentData = page.mergeInstrumentDataPreservingRestrictions(first)
        page.watchlistName = String(first.watchlistName || "")

        if (page.openedFromWatchlist)
            page.watchlistId = String(first.watchlistId || "")
    }

    function enrichFromCurrentWatchlistIfPossible() {
        if (page.watchlistId !== "")
            return

        var item = etoroClient.currentWatchlistItemForInstrument(page.instrumentData.instrumentId)
        if (!item || (item.instrumentId === undefined && item.itemId === undefined))
            return

        page.instrumentData = page.mergeInstrumentDataPreservingRestrictions(item)
        page.watchlistName = etoroClient.currentWatchlistName
    }

    function buyRestrictedReason() {
        if (page.restrictionValue("tradingDisabled") === true)
            return qsTr("Trading is disabled for this market.")

        if (page.restrictionValue("isBuyEnabled") === false)
            return qsTr("Buying is not available for this market.")

        if (page.restrictionValue("isCurrentlyTradable") === false)
            return qsTr("This market is not currently tradable.")

        return ""
    }

    function buyAllowed() {
        return page.buyRestrictedReason() === ""
    }

    function valueText(v) {
        return (v === undefined || v === null || v === "") ? "—" : String(v)
    }

    function numberText(v, decimals) {
        if (v === undefined || v === null || v === "")
            return "—"
        return Number(v).toLocaleString(Qt.locale(), 'f', decimals)
    }

    function instrumentIcon50(instrument) {
        if (instrument.logoUrl)
            return instrument.logoUrl
        if (instrument.logo50x50)
            return instrument.logo50x50
        if (instrument.logo35x35)
            return instrument.logo35x35
        if (instrument.logo150x150)
            return instrument.logo150x150

        if (instrument.instrumentId === undefined || instrument.instrumentId === null || instrument.instrumentId === "")
            return ""

        return "https://etoro-cdn.etorostatic.com/market-avatars/" + String(instrument.instrumentId) + "/50x50.png"
    }

    Timer {
        id: instrumentQuoteRefreshTimer
        repeat: true
        running: page.status === PageStatus.Active
                 && etoroClient.quoteRefreshIntervalSeconds > 0
                 && !etoroClient.locked
                 && !etoroClient.quoteRefreshCoolingDown
        interval: etoroClient.effectiveQuoteRefreshIntervalSeconds("instrument") * 1000

        onTriggered: {
            if (!etoroClient.selectedInstrumentQuoteLoading) {
                etoroClient.loadInstrumentQuote(page.instrumentData)
            }
        }
    }

    Component.onCompleted: {
        etoroClient.loadInstrumentQuote(instrumentData)
        page.openedFromWatchlist = page.watchlistId !== ""
    }

    onStatusChanged: {
        if (status === PageStatus.Active)
            page.enrichFromCurrentWatchlistIfPossible()

        if (status === PageStatus.Active && page.watchlistId !== "")
        {
            etoroClient.loadInstrumentQuote(page.instrumentData)
        }

        if (status === PageStatus.Active && page.watchlistId === "")
            etoroClient.findWatchlistsForInstrument(page.instrumentData.instrumentId)
    }

    Component.onDestruction: {
        etoroClient.clearSelectedInstrumentQuote()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh quote")
                enabled: !etoroClient.selectedInstrumentQuoteLoading
                onClicked: etoroClient.loadInstrumentQuote(page.instrumentData)
            }
            MenuItem {
                visible: etoroClient.tradingEnabled
                enabled: etoroClient.tradingEnabled && page.buyAllowed()

                text: qsTr("Buy")

                onClicked: {
                    openPositionOverlay.open()
                }
            }
            MenuItem {
                text: qsTr("Add to watchlist")
                visible: !page.openedFromWatchlist
                enabled: !etoroClient.busy
                onClicked: addToWatchlistOverlay.open()
            }
            MenuItem {
                text: qsTr("Remove from watchlist")
                visible: page.openedFromWatchlist
                enabled: !etoroClient.busy
                onClicked: removeFromWatchlistOverlay.open()
            }
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingLarge

            Item {
                width: parent.width
                height: pageHeader.height + positionIdLabel.height - Theme.paddingMedium

                PageHeader {
                    id: pageHeader
                    width: parent.width
                    title: qsTr("%1 (%2)")
                           .arg(page.instrumentData.displayName || (qsTr("Asset ") + valueText(page.instrumentData.instrumentId)))
                           .arg(etoroClient.accountModeLabel)
                }

                Label {
                    id: positionIdLabel
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin
                    anchors.top: pageHeader.bottom
                    anchors.topMargin: -Theme.paddingLarge
                    text: qsTr("ID#") + valueText(page.instrumentData.instrumentId)
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeTiny
                    horizontalAlignment: Text.AlignRight
                    truncationMode: TruncationMode.Fade
                }
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
                        text: qsTr("Trading is disabled. Enable trading mode in Settings to open positions.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: summaryCard.height + Theme.paddingLarge * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: summaryCard
                    x: Theme.paddingLarge
                    y: Theme.paddingLarge
                    width: parent.width - 2 * Theme.paddingLarge
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Live quotes")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

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

                        Item {
                            id: logoSlot
                            width: 100
                            height: 100

                            Image {
                                id: logoImage
                                anchors.centerIn: parent
                                source: instrumentIcon50(page.instrumentData)
                                width: 100
                                height: 100
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        Label {
                            id: symbolLabel
                            width: parent.width - logoSlot.width - Theme.paddingMedium
                            anchors.verticalCenter: logoSlot.verticalCenter
                            text: page.instrumentData.symbol || ("#" + valueText(page.instrumentData.instrumentId))
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeLarge
                            truncationMode: TruncationMode.Fade
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        // --- Sell ---
                        TradePriceActionRow {
                            width: parent.width
                            sideText: qsTr("Sell")
                            rawValue: etoroClient.selectedInstrumentQuote.sellPrice
                            decimals: 4
                            tradingEnabled: etoroClient.tradingEnabled
                            actionEnabled: false
                            textColor: Theme.primaryColor
                        }

                        // --- Buy ---
                        TradePriceActionRow {
                            width: parent.width
                            sideText: qsTr("Buy")
                            rawValue: etoroClient.selectedInstrumentQuote.buyPrice
                            decimals: 4
                            tradingEnabled: etoroClient.tradingEnabled
                            actionEnabled: page.buyAllowed()
                            textColor: Theme.primaryColor
                            onClicked: {
                                if (!page.buyAllowed()) {
                                    etoroClient.clearLastError()
                                    return
                                }

                                openPositionOverlay.open()
                                etoroClient.registerUserActivity()
                            }
                        }

                        Label {
                            width: parent.width
                            visible: page.buyRestrictedReason() !== ""
                            text: page.buyRestrictedReason()
                            color: Theme.errorColor
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.rgba(Theme.primaryColor, 0.50)
                        }

                        // --- Spread ---
                        Item {
                            width: parent.width
                            height: Math.max(spreadLabel.height, spreadValue.implicitHeight)

                            Label {
                                id: spreadLabel
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Spread:")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            PriceFlashValue {
                                id: spreadValue
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                rawValue: Number(etoroClient.selectedInstrumentQuote.buyPrice || 0)
                                          - Number(etoroClient.selectedInstrumentQuote.sellPrice || 0)
                                decimals: 4
                                textColor: Theme.secondaryColor
                                fontSize: Theme.fontSizeSmall
                            }
                        }

                        // --- Last ---
                        Item {
                            width: parent.width
                            height: Math.max(lastLabel.height, lastValue.implicitHeight)

                            Label {
                                id: lastLabel
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Last:")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            PriceFlashValue {
                                id: lastValue
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                rawValue: etoroClient.selectedInstrumentQuote.lastExecutionPrice
                                decimals: 4
                                textColor: Theme.secondaryColor
                                fontSize: Theme.fontSizeSmall
                            }
                        }
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: detailCard.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: detailCard
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingMedium

                    Label {
                        width: parent.width
                        text: (page.instrumentData.displayName || qsTr("Asset")) + qsTr(" details")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        text: page.instrumentData.priceSource === undefined
                              || page.instrumentData.priceSource === null
                              || page.instrumentData.priceSource === ""
                              ? qsTr("Price source: Not in watchlist")
                              : qsTr("Price source: ") + valueText(page.instrumentData.priceSource)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: page.instrumentData.itemRank === undefined
                              || page.instrumentData.itemRank === null
                              || page.instrumentData.itemRank === ""
                              ? qsTr("Watchlist item rank: Not in watchlist")
                              : qsTr("Watchlist item rank: ") + valueText(page.instrumentData.itemRank)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.watchlistId === ""
                         || etoroClient.instrumentWatchlistLookupActive
                         || etoroClient.instrumentWatchlistMatches.length > 0
                height: watchlistsCard.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: watchlistsCard
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Watchlists")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        visible: etoroClient.instrumentWatchlistLookupActive
                                 && etoroClient.instrumentWatchlistMatches.length === 0
                        text: qsTr("Checking watchlists…")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        visible: !etoroClient.instrumentWatchlistLookupActive
                                 && etoroClient.instrumentWatchlistMatches.length === 0
                        text: qsTr("Not on any watchlists.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Repeater {
                        model: etoroClient.instrumentWatchlistMatches

                        Label {
                            width: parent.width
                            text: modelData.watchlistName || modelData.watchlistId
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            truncationMode: TruncationMode.Fade
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

    //Open position overlay
    OpenPositionOverlay {
        id: openPositionOverlay

        instrumentId: Number(page.instrumentData.instrumentId || 0)
        symbol: page.instrumentData.symbol || ""
        displayName: page.instrumentData.displayName || ""
        unitPrice: etoroClient.selectedInstrumentQuote.buyPrice

        onOrderSubmitted: {
            purchaseSubmittedOverlay.open()
        }
    }

    // Purchase submitted overlay
    PurchaseSubmittedOverlay {
        id: purchaseSubmittedOverlay
    }

    // Add to Watchlist overlay
    AddToWatchlistOverlay {
        id: addToWatchlistOverlay
        instrumentData: page.instrumentData

        onAdded: {
            etoroClient.findWatchlistsForInstrument(page.instrumentData.instrumentId)
        }
    }

    // Remove from watchlist overlay
    RemoveFromWatchlistOverlay {
        id: removeFromWatchlistOverlay
        watchlistId: page.watchlistId
        instrumentData: page.instrumentData

        onRemoved: {
            pageStack.pop()
        }
    }

    Connections {
        target: etoroClient

        onCurrentWatchlistItemsChanged: {
            if (page.watchlistId === "") {
                page.enrichFromCurrentWatchlistIfPossible()
                return
            }

            for (var i = 0; i < etoroClient.currentWatchlistItems.length; ++i) {
                var item = etoroClient.currentWatchlistItems[i]
                if (Number(item.instrumentId || item.itemId || 0) === Number(page.instrumentData.instrumentId || 0)) {
                    page.instrumentData = page.mergeInstrumentDataPreservingRestrictions(item)
                    page.watchlistName = etoroClient.currentWatchlistName
                    return
                }
            }
        }

        onInstrumentWatchlistMatchesChanged: {
            page.applyWatchlistMatches()
        }
    }
}
