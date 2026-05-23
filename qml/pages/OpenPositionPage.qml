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

    property var positionData: ({})
    property var instrumentData: ({})
    property bool readOnlyMode: !etoroClient.tradingEnabled
    property bool submitAttempted: false

    function restrictionValue(key) {
        if (page.positionData && page.positionData[key] !== undefined)
            return page.positionData[key]

        if (page.instrumentData && page.instrumentData[key] !== undefined)
            return page.instrumentData[key]

        var cached = etoroClient.restrictionsForInstrument(page.effectiveInstrumentId)
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

    property bool hasPositionData: {
        return positionData
                && positionData.positionId !== undefined
                && positionData.positionId !== null
                && String(positionData.positionId) !== ""
    }

    property string effectiveInstrumentId: {
        var v = hasPositionData ? positionData.instrumentId : instrumentData.instrumentId
        if (v === undefined || v === null || String(v) === "")
            return ""
        return String(v)
    }

    property string effectiveSymbol: {
        var v = hasPositionData ? positionData.symbol : instrumentData.symbol
        if (v === undefined || v === null || String(v) === "")
            return effectiveInstrumentId !== "" ? ("#" + effectiveInstrumentId) : "—"
        return String(v)
    }

    property string effectiveDisplayName: {
        var v = hasPositionData ? positionData.displayName : instrumentData.displayName
        if (v === undefined || v === null || String(v) === "")
            return effectiveInstrumentId !== "" ? (qsTr("Instrument ") + effectiveInstrumentId) : "—"
        return String(v)
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

    function calculatedPageTitle() {
        if (hasPositionData)
            return isBuyPosition()
                    ? qsTr("Buy position (%1)").arg(etoroClient.accountModeLabel)
                    : qsTr("Sell position (%1)").arg(etoroClient.accountModeLabel)

        return qsTr("Open position (%1)").arg(etoroClient.accountModeLabel)
    }

    function isBuyPosition() {
        var v = positionData.isBuy
        if (v === true || v === 1)
            return true
        if (v === false || v === 0)
            return false

        var s = String(v).toLowerCase()
        if (s === "true" || s === "1")
            return true
        if (s === "false" || s === "0")
            return false

        var dir = String(positionData.direction || "").toLowerCase()
        return dir === "buy"
    }

    function hasStopLoss() {
        return positionData.stopLossRate !== undefined
                && positionData.stopLossRate !== null
                && String(positionData.stopLossRate) !== ""
                && !positionData.isNoStopLoss
    }

    function hasTakeProfit() {
        return positionData.takeProfitRate !== undefined
                && positionData.takeProfitRate !== null
                && String(positionData.takeProfitRate) !== ""
                && !positionData.isNoTakeProfit
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

    function dateTimeText(value) {
        if (!value || value === "")
            return "—"
        var d = new Date(value)
        if (isNaN(d.getTime()))
            return value
        return Qt.formatDateTime(d, "dd/MM/yyyy hh:mm")
    }

    function profitPercent() {
        var invested = Number(positionData.invested || 0)
        var pnl = Number(positionData.netProfit || 0)
        if (invested === 0)
            return 0
        return (pnl / invested) * 100.0
    }

    function netValue() {
        return Number(positionData.invested || 0) + Number(positionData.netProfit || 0)
    }

    function valueText(value, decimals) {
        if (value === undefined || value === null || value === "")
            return "—"
        return amountText(value, decimals)
    }

    function instrumentIcon50(instrumentId) {
        if (instrumentId === undefined || instrumentId === null || instrumentId === "")
            return ""
        return "https://etoro-cdn.etorostatic.com/market-avatars/" + String(instrumentId) + "/50x50.png"
    }

    function liveQuote() {
        if (hasPositionData)
            return etoroClient.quoteForPositionInstrument(effectiveInstrumentId)
        return etoroClient.selectedInstrumentQuote || ({})
    }

    function refreshQuote() {
        if (hasPositionData) {
            if (!etoroClient.positionsQuotesLoading)
                etoroClient.refreshPositionsQuotes()
            return
        }

        if (effectiveInstrumentId !== "" && instrumentData && instrumentData.instrumentId !== undefined)
            etoroClient.loadInstrumentQuote(instrumentData)
    }

    Component.onCompleted: {
        if (!hasPositionData)
            refreshQuote()
    }

    Timer {
        id: openPositionQuoteRefreshTimer
        repeat: true
        running: page.status === PageStatus.Active
                 && etoroClient.effectiveQuoteRefreshIntervalSeconds("positionDetail") > 0
                 && !etoroClient.locked
                 && !etoroClient.quoteRefreshCoolingDown
        interval: etoroClient.effectiveQuoteRefreshIntervalSeconds("positionDetail") * 1000

        onTriggered: {
            page.refreshQuote()
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh quote")
                onClicked: {
                    page.refreshQuote()
                    etoroClient.registerUserActivity()
                }
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
                    title: page.calculatedPageTitle()
                    width: parent.width
                }

                Label {
                    id: positionIdLabel
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin
                    anchors.top: pageHeader.bottom
                    anchors.topMargin: -Theme.paddingLarge
                    visible: page.hasPositionData
                    text: qsTr("ID#") + String(positionData.positionId || "—")
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
                        text: qsTr("Summary")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingSmall

                        Item {
                            id: logoSlot
                            width: 100
                            height: 100

                            Image {
                                id: logoImage
                                anchors.centerIn: parent
                                source: instrumentIcon50(page.effectiveInstrumentId)
                                width: 100
                                height: 100
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        Column {
                            width: page.hasPositionData
                                   ? parent.width - logoSlot.width - actionColumn.width - Theme.paddingSmall * 2
                                   : parent.width - logoSlot.width - actionColumn.width - Theme.paddingSmall * 2
                            anchors.verticalCenter: logoSlot.verticalCenter
                            spacing: 2

                            Label {
                                width: parent.width
                                text: page.effectiveSymbol
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeMedium
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: page.effectiveDisplayName
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                truncationMode: TruncationMode.Fade
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                            }
                        }

                        Column {
                            id: actionColumn
                            width: parent.width * 0.34
                            anchors.verticalCenter: logoSlot.verticalCenter
                            spacing: Theme.paddingSmall

                            Label {
                                width: parent.width
                                text: page.instrumentTypeName(page.hasPositionData
                                                              ? page.positionData.instrumentTypeId
                                                              : page.instrumentData.instrumentTypeId)
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                visible: page.hasPositionData
                                text: amountText(netValue(), 2)
                                color: Number(positionData.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor
                                font.pixelSize: Theme.fontSizeMedium
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.rgba(Theme.primaryColor, 0.50)
                    }

                    // Sell -----
                    TradePriceActionRow {
                        width: parent.width
                        sideText: qsTr("Sell")
                        rawValue: (page.liveQuote() || {}).ask
                        decimals: 4
                        tradingEnabled: etoroClient.tradingEnabled
                        actionEnabled: page.hasPositionData && !etoroClient.busy
                        textColor: Theme.secondaryColor
                        onClicked: {
                            closePositionOverlay.open()
                            etoroClient.registerUserActivity()
                        }
                    }

                    // Buy -----
                    TradePriceActionRow {
                        width: parent.width
                        sideText: qsTr("Buy")
                        rawValue: (page.liveQuote() || {}).bid
                        decimals: 4
                        tradingEnabled: etoroClient.tradingEnabled
                        actionEnabled: page.buyAllowed()
                        textColor: Theme.secondaryColor
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

                    Label {
                        width: parent.width
                        visible: page.submitAttempted && !page.hasPositionData
                        text: qsTr("Enter order details to continue.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !page.hasPositionData && !page.readOnlyMode
                height: tradingPrepColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: tradingPrepColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Open position")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Order entry will be added here in the next step.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }
                }
            }

            Row {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                spacing: Theme.paddingMedium
                visible: page.hasPositionData

                Rectangle {
                    width: (parent.width - Theme.paddingMedium) / 2
                    height: stopLossColumn.height + Theme.paddingMedium * 2
                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                    border.width: 1
                    border.color: Theme.rgba(Theme.highlightColor, 0.75)

                    Column {
                        id: stopLossColumn
                        x: Theme.paddingMedium
                        y: Theme.paddingMedium
                        width: parent.width - 2 * Theme.paddingMedium
                        spacing: 2

                        Label {
                            width: parent.width
                            text: qsTr("Stop Loss Price")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                        }

                        Label {
                            width: parent.width
                            text: hasStopLoss() ? valueText(positionData.stopLossRate, 4) : "—"
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                        }
                    }
                }

                Rectangle {
                    width: (parent.width - Theme.paddingMedium) / 2
                    height: takeProfitColumn.height + Theme.paddingMedium * 2
                    radius: Theme.paddingMedium
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                    border.width: 1
                    border.color: Theme.rgba(Theme.highlightColor, 0.75)

                    Column {
                        id: takeProfitColumn
                        x: Theme.paddingMedium
                        y: Theme.paddingMedium
                        width: parent.width - 2 * Theme.paddingMedium
                        spacing: 2

                        Label {
                            width: parent.width
                            text: qsTr("Take Profit Price")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                        }

                        Label {
                            width: parent.width
                            text: hasTakeProfit() ? valueText(positionData.takeProfitRate, 4) : "—"
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

// Temp ----
//SectionHeader {
//    text: qsTr("Protection test")
//    visible: etoroClient.tradingEnabled
//}
//
//TextField {
//    id: testStopLossField
//    width: parent.width
//    visible: etoroClient.tradingEnabled
//    label: qsTr("New Stop Loss")
//    placeholderText: qsTr("Optional")
//    inputMethodHints: Qt.ImhFormattedNumbersOnly
//}
//
//TextField {
//    id: testTakeProfitField
//    width: parent.width
//    visible: etoroClient.tradingEnabled
//    label: qsTr("New Take Profit")
//    placeholderText: qsTr("Optional")
//    inputMethodHints: Qt.ImhFormattedNumbersOnly
//}
//
//Button {
//    width: parent.width
//    visible: etoroClient.tradingEnabled
//    enabled: !etoroClient.busy
//    text: etoroClient.busy ? qsTr("Submitting…") : qsTr("Test SL/TP update")
//
//    onClicked: {
//        etoroClient.updatePositionProtection(page.positionData, {
//            "stopLoss": testStopLossField.text,
//            "takeProfit": testTakeProfitField.text
//        })
//        etoroClient.registerUserActivity()
//    }
//}
//
//Label {
//    width: parent.width
//    visible: etoroClient.tradingEnabled && etoroClient.lastError !== ""
//    text: etoroClient.lastError
//    color: etoroClient.lastError.indexOf("updated") >= 0 ? Theme.highlightColor : Theme.errorColor
//    font.pixelSize: Theme.fontSizeSmall
//    wrapMode: Text.Wrap
//}
// Temp ----

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: detailsColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: detailsColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: page.hasPositionData ? qsTr("Details") : qsTr("Instrument")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium
                        visible: page.hasPositionData

                        Column {
                            width: parent.width * 0.38
                            spacing: Theme.paddingSmall

                            Label {
                                width: parent.width
                                text: qsTr("Units")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Column {
                                width: parent.width
                                spacing: 2

                                Label {
                                    width: parent.width
                                    text: qsTr("Open price")
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeSmall
                                }

                                Label {
                                    width: parent.width
                                    text: qsTr("")
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeTiny
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            Label {
                                width: parent.width
                                text: qsTr("Invested")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Label {
                                width: parent.width
                                text: qsTr("Current price")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Label {
                                width: parent.width
                                text: qsTr("Profit/Loss (P/L)")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Theme.rgba(Theme.primaryColor, 0.50)
                            }

                            Label {
                                width: parent.width
                                text: qsTr("Value")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }

                        Column {
                            id: valuesColumn
                            width: parent.width - (parent.width * 0.38) - Theme.paddingMedium - 1
                            spacing: Theme.paddingSmall

                            Label {
                                width: parent.width
                                text: valueText(positionData.units, 4)
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }

                            Column {
                                width: parent.width
                                spacing: 2

                                Label {
                                    width: parent.width
                                    text: valueText(positionData.openRate, 4)
                                    color: Theme.primaryColor
                                    font.pixelSize: Theme.fontSizeSmall
                                    horizontalAlignment: Text.AlignRight
                                    truncationMode: TruncationMode.Fade
                                }

                                Label {
                                    width: parent.width
                                    text: dateTimeText(positionData.openDateTime || positionData.openDate)
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeTiny
                                    horizontalAlignment: Text.AlignRight
                                    truncationMode: TruncationMode.Fade
                                }
                            }

                            Label {
                                width: parent.width
                                text: valueText(positionData.invested, 2)
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: valueText(positionData.currentRate, 4)
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: valueText(positionData.netProfit, 2)
                                color: Number(positionData.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Theme.rgba(Theme.primaryColor, 0.50)
                            }

                            Label {
                                width: parent.width
                                text: amountText(netValue(), 2)
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.paddingSmall
                        visible: !page.hasPositionData

                        Item {
                            width: parent.width
                            height: symbolLabel.height

                            Label {
                                id: symbolLabel
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Symbol")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Label {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: page.effectiveSymbol
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        Item {
                            width: parent.width
                            height: instrumentNameLabel.height

                            Label {
                                id: instrumentNameLabel
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Name")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Label {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * 0.62
                                text: page.effectiveDisplayName
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                wrapMode: Text.Wrap
                            }
                        }

                        Item {
                            width: parent.width
                            height: instrumentIdLabel.height

                            Label {
                                id: instrumentIdLabel
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Asset ID")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Label {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: page.effectiveInstrumentId !== "" ? page.effectiveInstrumentId : "—"
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
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

        instrumentId: Number(page.effectiveInstrumentId || 0)
        symbol: page.effectiveSymbol || ""
        displayName: page.effectiveDisplayName || ""
        unitPrice: (page.liveQuote() || {}).bid

        onOrderSubmitted: {
            purchaseSubmittedOverlay.open()
        }
    }

    // Purchase submitted overlay
    PurchaseSubmittedOverlay {
        id: purchaseSubmittedOverlay
    }

    // Sell (Close position) overlay
    ClosePositionOverlay {
        id: closePositionOverlay
        positionData: page.positionData
        symbol: page.effectiveSymbol
        displayName: page.effectiveDisplayName
        currentValueText: page.amountText(page.netValue(), 2)

        onCloseSubmitted: {
            pageStack.previousPage().showCloseSuccess(closePositionOverlay.partialClose)
            pageStack.pop()
        }
    }
}
