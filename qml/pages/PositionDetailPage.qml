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

    property var positionData: ({ })
    property bool readOnlyMode: !etoroClient.tradingEnabled

    property bool closeSuccessVisible: false

    property string closeSuccessText: ""

    function restrictionValue(key) {
        if (page.positionData && page.positionData[key] !== undefined)
            return page.positionData[key]

        if (page.positionData.positions && page.positionData.positions.length > 0) {
            for (var i = 0; i < page.positionData.positions.length; ++i) {
                if (page.positionData.positions[i][key] !== undefined)
                    return page.positionData.positions[i][key]
            }
        }

        var cached = etoroClient.restrictionsForInstrument(page.positionData.instrumentId)
        if (cached && cached[key] !== undefined)
            return cached[key]

        return undefined
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

    function instrumentTypeName(typeId) {
        typeId = Number(typeId || 0)

        switch (typeId) {
        case 1: return qsTr("Currencies")
        case 2: return qsTr("Commodities")
        case 4: return qsTr("Indices")
        case 5: return qsTr("Stocks")
        case 6: return qsTr("ETFs")
        case 10: return qsTr("Crypto")
        default: return qsTr("Other")
        }
    }

    function effectiveInstrumentTypeId() {
        if (page.positionData.instrumentTypeId !== undefined
                && page.positionData.instrumentTypeId !== null
                && String(page.positionData.instrumentTypeId) !== "")
            return page.positionData.instrumentTypeId

        if (page.positionData.positions
                && page.positionData.positions.length > 0
                && page.positionData.positions[0].instrumentTypeId !== undefined)
            return page.positionData.positions[0].instrumentTypeId

        return 0
    }

    function showCloseSuccess(partial) {
        closeSuccessText = partial
                ? qsTr("Partial close submitted successfully.")
                : qsTr("Position close submitted successfully.")
        closeSuccessVisible = true
        closeSuccessTimer.restart()
    }

    function investedAmount(item) {
        if (!item)
            return 0

        if (item.positionCount !== undefined
                && Number(item.positionCount) > 1
                && item.invested !== undefined) {
            return Number(item.invested || 0)
        }

        if (item.positions && item.positions.length > 0) {
            var total = 0

            for (var i = 0; i < item.positions.length; ++i)
                total += Number(item.positions[i].invested || 0)

            return total
        }

        return Number(item.invested || 0)
    }

    function amountText(value, decimals) {
        return Number(value || 0).toLocaleString(Qt.locale(), 'f', decimals)
    }

    function dateText(value) {
        if (!value || value === "")
            return "—"

        var d = new Date(value)
        if (isNaN(d.getTime()))
            return value

        return Qt.formatDateTime(d, "dd/MM/yyyy")
    }

    function profitPercent(item) {
        var invested = Number(item.invested || 0)
        var pnl = Number(item.netProfit || 0)
        if (invested === 0)
            return 0
        return (pnl / invested) * 100.0
    }

    function netValue(item) {
        return investedAmount(item) + Number(item.netProfit || 0)
    }

    function openPositionsModel() {
        if (page.positionData.positions && page.positionData.positions.length > 0)
            return page.positionData.positions

        return [ page.positionData ]
    }

    function summaryOpenRate() {
        if (page.positionData.averageOpenRate !== undefined)
            return page.positionData.averageOpenRate
        return page.positionData.openRate
    }

    function detailPageTitle(item) {
        return item.isBuy ? qsTr("Buy position") : qsTr("Sell position")
    }

    function instrumentIcon50(instrumentId) {
        if (instrumentId === undefined || instrumentId === null || instrumentId === "")
            return ""

        return "https://etoro-cdn.etorostatic.com/market-avatars/"
                + String(instrumentId)
                + "/50x50.png"
    }

    function refreshPositionDataFromGroupedModel() {
        var currentInstrumentId = String(page.positionData.instrumentId || "")
        if (currentInstrumentId === "")
            return

        var grouped = etoroClient.groupedOpenPositions || []

        for (var i = 0; i < grouped.length; i++) {
            var item = grouped[i]
            if (String(item.instrumentId || "") === currentInstrumentId) {
                page.positionData = item
                return
            }
        }
    }

    Timer {
        id: closeSuccessTimer
        interval: 3500
        repeat: false
        onTriggered: page.closeSuccessVisible = false
    }

    Timer {
        id: positionQuoteRefreshTimer
        repeat: true
        running: page.status === PageStatus.Active
                 && etoroClient.effectiveQuoteRefreshIntervalSeconds("positionDetail") > 0
                 && !etoroClient.locked
                 && !etoroClient.quoteRefreshCoolingDown
        interval: etoroClient.effectiveQuoteRefreshIntervalSeconds("positionDetail") * 1000

        onTriggered: {
            if (!etoroClient.positionsQuotesLoading)
                etoroClient.refreshPositionsQuotes()
        }
    }

    Connections {
        target: etoroClient

        onGroupedOpenPositionsChanged: {
            page.refreshPositionDataFromGroupedModel()
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("Position (%1)").arg(etoroClient.accountModeLabel)
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
                        text: qsTr("Trading is disabled. Existing position information remains available for review.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                width: parent.width
                visible: page.closeSuccessVisible
                height: closeSuccessLabel.height + Theme.paddingMedium * 2
                radius: Theme.paddingSmall
                color: Theme.rgba(Theme.highlightColor, 0.18)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.45)

                Label {
                    id: closeSuccessLabel
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    text: page.closeSuccessText
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: summaryCard.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: summaryCard
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Position summary")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
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
                                source: instrumentIcon50(page.positionData.instrumentId)
                                width: 100
                                height: 100
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        Column {
                            width: parent.width - logoSlot.width - rightSummaryColumn.width - Theme.paddingMedium * 2
                            anchors.verticalCenter: logoSlot.verticalCenter
                            spacing: 2

                            Label {
                                width: parent.width
                                text: page.positionData.symbol || ("#" + page.positionData.instrumentId)
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeMedium
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: page.positionData.displayName || (qsTr("Asset ") + page.positionData.instrumentId)
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                truncationMode: TruncationMode.Fade
                            }
                        }

                        Column {
                            id: rightSummaryColumn
                            width: parent.width * 0.34
                            anchors.verticalCenter: logoSlot.verticalCenter
                            spacing: 2

                            Label {
                                width: parent.width
                                text: page.instrumentTypeName(page.effectiveInstrumentTypeId())
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: amountText(netValue(page.positionData), 2)
                                color: Number(page.positionData.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor
                                font.pixelSize: Theme.fontSizeMedium
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Label {
                            width: parent.width * 0.34
                            text: qsTr("Invested")
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            truncationMode: TruncationMode.Fade
                        }

                        Label {
                            width: parent.width * 0.60 - Theme.paddingMedium
                            text: amountText(investedAmount(page.positionData), 2)
                            color: Number(page.positionData.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor
                            font.pixelSize: Theme.fontSizeSmall
                            horizontalAlignment: Text.AlignRight
                            truncationMode: TruncationMode.Fade
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.rgba(Theme.primaryColor, 0.5)
                    }

                    // Sell -----
                    TradePriceActionRow {
                        width: parent.width
                        sideText: qsTr("Sell")
                        rawValue: (etoroClient.quoteForPositionInstrument(page.positionData.instrumentId) || {}).ask
                        decimals: 4
                        tradingEnabled: etoroClient.tradingEnabled
                        actionEnabled: false
                        textColor: Theme.secondaryColor
                        labelWidth: parent.width * 0.34
                    }

                    // Buy -----
                    TradePriceActionRow {
                        width: parent.width
                        sideText: qsTr("Buy")
                        rawValue: (etoroClient.quoteForPositionInstrument(page.positionData.instrumentId) || {}).bid
                        decimals: 4
                        tradingEnabled: etoroClient.tradingEnabled
                        actionEnabled: page.buyAllowed()
                        textColor: Theme.secondaryColor
                        labelWidth: parent.width * 0.34
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
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: openPositionsColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: openPositionsColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Open positions")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Rectangle {
                        width: parent.width
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
                                width: parent.width * 0.26
                                text: qsTr("Opened (") + String(page.openPositionsModel().length) + qsTr(")")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeTiny
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width * 0.18
                                text: qsTr("P/L (%)")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeTiny
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width * 0.18
                                text: qsTr("P/L")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeTiny
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width * 0.30
                                text: qsTr("Net value")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeTiny
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }
                        }
                    }

                    Repeater {
                        model: page.openPositionsModel()

                        delegate: BackgroundItem {
                            width: parent.width
                            height: compactColumn.height + Theme.paddingSmall * 2

                            onClicked: {
                                pageStack.push(Qt.resolvedUrl("OpenPositionPage.qml"), {
                                    positionData: modelData,
                                    instrumentData: page.positionData
                                })
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.paddingSmall
                                color: Theme.rgba(Theme.highlightBackgroundColor, 0.06)
                                border.width: 1
                                border.color: Theme.rgba(Theme.highlightColor, 0.10)
                            }

                            Column {
                                id: compactColumn
                                x: Theme.paddingSmall
                                y: Theme.paddingSmall
                                width: parent.width - 2 * Theme.paddingSmall
                                spacing: 2

                                Row {
                                    width: parent.width
                                    spacing: Theme.paddingSmall

                                    Label {
                                        width: parent.width * 0.26
                                        text: dateText(modelData.openDateTime || modelData.openDate)
                                        color: Theme.secondaryColor
                                        font.pixelSize: Theme.fontSizeTiny
                                        truncationMode: TruncationMode.Fade
                                    }

                                    Label {
                                        width: parent.width * 0.18
                                        text: amountText(profitPercent(modelData), 1)
                                        color: Number(modelData.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor
                                        font.pixelSize: Theme.fontSizeSmall
                                        horizontalAlignment: Text.AlignRight
                                        verticalAlignment: Text.AlignVCenter
                                        truncationMode: TruncationMode.Fade
                                    }

                                    Label {
                                        width: parent.width * 0.18
                                        text: amountText(modelData.netProfit, 2)
                                        color: Number(modelData.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor
                                        font.pixelSize: Theme.fontSizeSmall
                                        horizontalAlignment: Text.AlignRight
                                        verticalAlignment: Text.AlignVCenter
                                        truncationMode: TruncationMode.Fade
                                    }

                                    Label {
                                        width: parent.width * 0.30
                                        text: amountText(netValue(modelData), 2)
                                        color: Theme.primaryColor
                                        font.pixelSize: Theme.fontSizeSmall
                                        horizontalAlignment: Text.AlignRight
                                        verticalAlignment: Text.AlignVCenter
                                        truncationMode: TruncationMode.Fade
                                    }
                                }

                                Label {
                                    width: parent.width
                                    text: ""
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeTiny
                                    truncationMode: TruncationMode.Fade
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

    //Open position overlay
    OpenPositionOverlay {
        id: openPositionOverlay

        instrumentId: Number(page.positionData.instrumentId || 0)
        symbol: page.positionData.symbol || ""
        displayName: page.positionData.displayName || ""
        unitPrice: (etoroClient.quoteForPositionInstrument(page.positionData.instrumentId) || {}).bid

        onOrderSubmitted: {
            purchaseSubmittedOverlay.open()
        }
    }

    // Purchase submitted overlay
    PurchaseSubmittedOverlay {
        id: purchaseSubmittedOverlay
    }
}
