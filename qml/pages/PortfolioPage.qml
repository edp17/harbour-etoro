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

    property string filterText: etoroClient.portfolioFilterText
    property string sortMode: etoroClient.portfolioSortMode
    property var filteredPositions: []
    property bool showFilterControls: etoroClient.portfolioShowFilter
    property bool showSortControls: etoroClient.portfolioShowSort
    property string viewMode: etoroClient.portfolioViewMode   // "card" or "compact"
    property bool sortDescending: true
    property bool readOnlyMode: !etoroClient.tradingEnabled

    function amountText(value, decimals) {
        return Number(value || 0).toLocaleString(Qt.locale(), "f", decimals)
    }

    function numberText(value, decimals) {
        if (value === undefined || value === null || value === "")
            return "---"
        return Number(value).toLocaleString(Qt.locale(), "f", decimals)
    }

    function percentText(value) {
        return amountText(value, 1) + "%"
    }

    function quoteText(instrumentId) {
        var q = etoroClient.quoteForPositionInstrument(instrumentId)
        if (!q || Object.keys(q).length === 0)
            return ""

        return qsTr("Bid: ") + amountText(q.bid, 6)
                + " • "
                + qsTr("Ask: ") + amountText(q.ask, 6)
                + " • "
                + qsTr("Last: ") + amountText(q.lastExecutionPrice, 6)
    }

    function shortAssetName(item) {
        var symbol = String(item.symbol || "")
        if (symbol.length > 0)
            return symbol

        var name = String(item.displayName || "")
        if (name.length <= 6)
            return name

        return name.slice(0, 6)
    }

    function profitPercent(item) {
        var invested = Number(item.invested || 0)
        var pnl = Number(item.netProfit || 0)
        if (invested === 0)
            return 0
        return (pnl / invested) * 100.0
    }

    function netValue(item) {
        return Number(item.invested || 0) + Number(item.netProfit || 0)
    }

    function compareByName(a, b) {
        var an = String(a.displayName || "").toLowerCase()
        var bn = String(b.displayName || "").toLowerCase()
        if (an < bn) return page.sortDescending ? 1 : -1
        if (an > bn) return page.sortDescending ? -1 : 1
        return 0
    }

    function compareByInvested(a, b) {
        var av = Number(a.invested || 0)
        var bv = Number(b.invested || 0)
        return page.sortDescending ? (bv - av) : (av - bv)
    }

    function compareByProfit(a, b) {
        var av = Number(a.netProfit || 0)
        var bv = Number(b.netProfit || 0)
        return page.sortDescending ? (bv - av) : (av - bv)
    }

    function columnTitle(mode) {
        if (mode === "pl_percent")
            return qsTr("P/L (%)")
        if (mode === "pl")
            return qsTr("P/L")
        if (mode === "net")
            return qsTr("Net value")
        if (mode === "buy")
            return qsTr("Buy")
        if (mode === "sell")
            return qsTr("Sell")
        return ""
    }

    function columnIndexFor(mode) {
        if (mode === "pl_percent")
            return 0
        if (mode === "pl")
            return 1
        if (mode === "net")
            return 2
        if (mode === "buy")
            return 3
        if (mode === "sell")
            return 4
        return 0
    }

    function columnModeFor(index) {
        switch (index) {
        case 0: return "pl_percent"
        case 1: return "pl"
        case 2: return "net"
        case 3: return "buy"
        case 4: return "sell"
        default: return "pl_percent"
        }
    }

    function columnValue(mode, item) {
        if (mode === "pl_percent")
            return percentText(profitPercent(item))

        if (mode === "pl")
            return amountText(item.netProfit, 2)

        if (mode === "net")
            return amountText(netValue(item), 2)

        var quote = etoroClient.quoteForPositionInstrument(item.instrumentId)

        if (mode === "buy")
            return numberText(quote ? quote.bid : "", 4)

        if (mode === "sell")
            return numberText(quote ? quote.ask : "", 4)

        return ""
    }

    function columnColor(mode, item) {
        if (mode === "pl_percent" || mode === "pl")
            return Number(item.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor

        return Theme.primaryColor
    }

    function applyFilterAndSort() {
        var source = etoroClient.groupedOpenPositions
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

        if (sortMode === "name")
            out.sort(compareByName)
        else if (sortMode === "profit")
            out.sort(compareByProfit)
        else
            out.sort(compareByInvested)

        filteredPositions = out
    }

    function instrumentIcon50(instrumentId) {
        if (instrumentId === undefined || instrumentId === null || instrumentId === "")
            return ""

        return "https://etoro-cdn.etorostatic.com/market-avatars/"
                + String(instrumentId)
                + "/50x50.png"
    }

    function setCompactColumn(which, newMode) {
        var c1 = etoroClient.portfolioColumn1
        var c2 = etoroClient.portfolioColumn2
        var c3 = etoroClient.portfolioColumn3

        if (which === 1) {
            var old = c1
            if (newMode === c2)
                etoroClient.setPortfolioColumn2(old)
            else if (newMode === c3)
                etoroClient.setPortfolioColumn3(old)

            etoroClient.setPortfolioColumn1(newMode)
        } else if (which === 2) {
            var old2 = c2
            if (newMode === c1)
                etoroClient.setPortfolioColumn1(old2)
            else if (newMode === c3)
                etoroClient.setPortfolioColumn3(old2)

            etoroClient.setPortfolioColumn2(newMode)
        } else if (which === 3) {
            var old3 = c3
            if (newMode === c1)
                etoroClient.setPortfolioColumn1(old3)
            else if (newMode === c2)
                etoroClient.setPortfolioColumn2(old3)

            etoroClient.setPortfolioColumn3(newMode)
        }

        compactCol1Combo.currentIndex = columnIndexFor(etoroClient.portfolioColumn1)
        compactCol2Combo.currentIndex = columnIndexFor(etoroClient.portfolioColumn2)
        compactCol3Combo.currentIndex = columnIndexFor(etoroClient.portfolioColumn3)

        refreshQuotesIfNeeded()
    }

    function compactColumnsNeedQuotes() {
        return etoroClient.portfolioColumn1 === "buy"
                || etoroClient.portfolioColumn1 === "sell"
                || etoroClient.portfolioColumn2 === "buy"
                || etoroClient.portfolioColumn2 === "sell"
                || etoroClient.portfolioColumn3 === "buy"
                || etoroClient.portfolioColumn3 === "sell"
    }

    function refreshQuotesIfNeeded() {
        if (!compactColumnsNeedQuotes())
            return

        if (!etoroClient.positionsQuotesLoading
                && !etoroClient.locked
                && page.filteredPositions.length > 0) {
            etoroClient.refreshPortfolio()
        }
    }

    Component {
        id: staticColumnComponent

        Label {
            property string columnMode: ""
            property var rowData: null

            anchors.fill: parent
            text: rowData ? columnValue(columnMode, rowData) : ""
            color: rowData ? columnColor(columnMode, rowData) : Theme.primaryColor
            font.pixelSize: Theme.fontSizeSmall * 0.9
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            truncationMode: TruncationMode.Fade
        }
    }

    Component {
        id: flashingColumnComponent

        Item {
            property string columnMode: ""
            property var rowData: null

            anchors.fill: parent

            PriceFlashValue {
                id: flashValue
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                rawValue: {
                    if (!rowData)
                        return undefined

                    var quote = etoroClient.quoteForPositionInstrument(rowData.instrumentId) || {}
                    if (columnMode === "buy")
                        return quote.bid
                    if (columnMode === "sell")
                        return quote.ask
                    return undefined
                }
                decimals: 4
                textColor: Theme.primaryColor
                fontSize: Theme.fontSizeSmall * 0.8
            }
        }
    }

    Timer {
        id: filterDebounceTimer
        interval: 180
        repeat: false
        onTriggered: page.applyFilterAndSort()
    }

    Timer {
        id: quoteRefreshTimer
        repeat: true
        running: page.status === PageStatus.Active
                 && etoroClient.effectiveQuoteRefreshIntervalSeconds("portfolio") > 0
                 && !etoroClient.locked
                 && !etoroClient.quoteRefreshCoolingDown
                 && page.filteredPositions.length > 0
                 && (page.viewMode === "card" || compactColumnsNeedQuotes())
        interval: etoroClient.effectiveQuoteRefreshIntervalSeconds("portfolio") * 1000

        onTriggered: {
            if (!etoroClient.positionsQuotesLoading)
                etoroClient.refreshPositionsQuotes()
        }
    }

    onFilterTextChanged: filterDebounceTimer.restart()
    onSortModeChanged: applyFilterAndSort()
    onSortDescendingChanged: applyFilterAndSort()

    Connections {
        target: etoroClient
        onOpenPositionsChanged: page.applyFilterAndSort()
    }

    Component.onCompleted: {
        filterField.text = etoroClient.portfolioFilterText

        if (sortMode === "profit")
            sortCombo.currentIndex = 1
        else if (sortMode === "name")
            sortCombo.currentIndex = 2
        else
            sortCombo.currentIndex = 0

        compactCol1Combo.currentIndex = columnIndexFor(etoroClient.portfolioColumn1)
        compactCol2Combo.currentIndex = columnIndexFor(etoroClient.portfolioColumn2)
        compactCol3Combo.currentIndex = columnIndexFor(etoroClient.portfolioColumn3)

        applyFilterAndSort()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                enabled: !etoroClient.busy && !etoroClient.locked
                onClicked: {
                    etoroClient.registerUserActivity()
                    etoroClient.refreshPortfolio()
                }
            }

            MenuItem {
                text: qsTr("Refresh quotes")
                enabled: !etoroClient.positionsQuotesLoading && !etoroClient.locked
                onClicked: {
                    etoroClient.registerUserActivity()
                    etoroClient.refreshPositionsQuotes()
                }
            }
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Portfolio")
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
                        text: qsTr("Trading is disabled. Portfolio holdings and live values remain available for review.")
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
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width - filterToggle.width - sortToggle.width - viewToggle.width - Theme.paddingMedium * 2
                            text: qsTr("Open positions")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall
                            verticalAlignment: Text.AlignVCenter
                        }

                        IconButton {
                            id: filterToggle
                            icon.source: "image://theme/icon-m-search"
                            highlighted: page.showFilterControls
                            onClicked: {
                                page.showFilterControls = !page.showFilterControls
                                etoroClient.setPortfolioShowFilter(page.showFilterControls)
                                etoroClient.registerUserActivity()

                                if (!page.showFilterControls) {
                                    filterField.text = ""
                                    page.filterText = ""
                                    etoroClient.setPortfolioFilterText("")
                                }
                            }
                        }

                        IconButton {
                            id: sortToggle
                            icon.source: "image://theme/icon-m-transfer"
                            highlighted: page.showSortControls
                            onClicked: {
                                page.showSortControls = !page.showSortControls
                                etoroClient.setPortfolioShowSort(page.showSortControls)
                                etoroClient.registerUserActivity()
                            }
                        }

                        IconButton {
                            id: viewToggle
                            icon.source: page.viewMode === "card"
                                         ? "image://theme/icon-camera-grid-ambience"
                                         : "image://theme/icon-camera-grid-thirds"
                            icon.width: Theme.iconSizeMedium
                            icon.height: Theme.iconSizeMedium
                            onClicked: {
                                page.viewMode = page.viewMode === "card" ? "compact" : "card"
                                etoroClient.setPortfolioViewMode(page.viewMode)
                                etoroClient.registerUserActivity()
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
                            etoroClient.setPortfolioFilterText(text)
                            etoroClient.registerUserActivity()
                        }
                    }

                    Row {
                        width: parent.width
                        height: sortCombo.height
                        visible: page.showSortControls
                        spacing: Theme.paddingSmall

                        ComboBox {
                            id: sortCombo
                            width: parent.width - directionLabel.width - directionButton.width - Theme.paddingSmall * 2
                            label: qsTr("Sort by")

                            menu: ContextMenu {
                                MenuItem { text: qsTr("Invested amount") }
                                MenuItem { text: qsTr("Unrealized P/L") }
                                MenuItem { text: qsTr("Name") }
                            }

                            currentIndex: 0

                            onCurrentIndexChanged: {
                                if (currentIndex === 0)
                                    page.sortMode = "invested"
                                else if (currentIndex === 1)
                                    page.sortMode = "profit"
                                else
                                    page.sortMode = "name"

                                etoroClient.setPortfolioSortMode(page.sortMode)
                                etoroClient.registerUserActivity()
                            }
                        }

                        Label {
                            id: directionLabel
                            anchors.verticalCenter: sortCombo.verticalCenter
                            text: page.sortDescending ? qsTr("Desc") : qsTr("Asc")
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        IconButton {
                            id: directionButton
                            anchors.verticalCenter: sortCombo.verticalCenter
                            icon.source: page.sortDescending
                                         ? "image://theme/icon-m-down"
                                         : "image://theme/icon-m-up"
                            onClicked: {
                                page.sortDescending = !page.sortDescending
                                etoroClient.registerUserActivity()
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        visible: page.showSortControls && page.viewMode === "compact"
                        spacing: Theme.paddingSmall

                        ComboBox {
                            id: compactCol1Combo
                            width: parent.width / 3 - Theme.paddingSmall
                            label: qsTr("Col 2")

                            menu: ContextMenu {
                                MenuItem { text: qsTr("P/L (%)") }
                                MenuItem { text: qsTr("P/L") }
                                MenuItem { text: qsTr("Net value") }
                                MenuItem { text: qsTr("Buy") }
                                MenuItem { text: qsTr("Sell") }
                            }

                            currentIndex: -1

                            onCurrentIndexChanged: {
                                if (currentIndex < 0)
                                    return
                                setCompactColumn(1, columnModeFor(currentIndex))
                                refreshQuotesIfNeeded()
                            }
                        }

                        ComboBox {
                            id: compactCol2Combo
                            width: parent.width / 3 - Theme.paddingSmall
                            label: qsTr("Col 3")

                            menu: ContextMenu {
                                MenuItem { text: qsTr("P/L (%)") }
                                MenuItem { text: qsTr("P/L") }
                                MenuItem { text: qsTr("Net value") }
                                MenuItem { text: qsTr("Buy") }
                                MenuItem { text: qsTr("Sell") }
                            }

                            currentIndex: -1

                            onCurrentIndexChanged: {
                                if (currentIndex < 0)
                                    return
                                setCompactColumn(2, columnModeFor(currentIndex))
                                refreshQuotesIfNeeded()
                            }
                        }

                        ComboBox {
                            id: compactCol3Combo
                            width: parent.width / 3 - Theme.paddingSmall
                            label: qsTr("Col 4")

                            menu: ContextMenu {
                                MenuItem { text: qsTr("P/L (%)") }
                                MenuItem { text: qsTr("P/L") }
                                MenuItem { text: qsTr("Net value") }
                                MenuItem { text: qsTr("Buy") }
                                MenuItem { text: qsTr("Sell") }
                            }

                            currentIndex: -1

                            onCurrentIndexChanged: {
                                if (currentIndex < 0)
                                    return
                                setCompactColumn(3, columnModeFor(currentIndex))
                                refreshQuotesIfNeeded()
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        visible: !etoroClient.busy && page.filteredPositions.length === 0
                        text: page.filterText.trim().length > 0
                              ? qsTr("No positions match the current filter.")
                              : qsTr("No open positions.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: page.viewMode === "compact" && page.filteredPositions.length > 0
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
                        width: parent.width * 0.24
                        text: qsTr("Asset (") + String(page.filteredPositions.length) + qsTr(")")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeTiny
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width * 0.24
                        text: columnTitle(etoroClient.portfolioColumn1)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeTiny
                        horizontalAlignment: Text.AlignRight
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width * 0.24
                        text: columnTitle(etoroClient.portfolioColumn2)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeTiny
                        horizontalAlignment: Text.AlignRight
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width * 0.24
                        text: columnTitle(etoroClient.portfolioColumn3)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeTiny
                        horizontalAlignment: Text.AlignRight
                        truncationMode: TruncationMode.Fade
                    }
                }
            }

            Repeater {
                model: page.filteredPositions

                delegate: BackgroundItem {
                    width: parent ? parent.width : page.width
                    height: page.viewMode === "card"
                            ? cardColumn.height + Theme.paddingMedium * 2
                            : compactColumn.height + Theme.paddingSmall * 2

                    onClicked: {
                        etoroClient.registerUserActivity()
                        pageStack.push(Qt.resolvedUrl("PositionDetailPage.qml"), {
                            positionData: modelData
                        })
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.horizontalPageMargin
                        anchors.rightMargin: Theme.horizontalPageMargin
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: page.viewMode === "card" ? Theme.paddingMedium : Theme.paddingSmall
                        color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                        border.width: 1
                        border.color: Theme.rgba(Theme.highlightColor, 0.12)
                    }

                    Column {
                        id: cardColumn
                        visible: page.viewMode === "card"
                        x: Theme.horizontalPageMargin + Theme.paddingMedium
                        y: Theme.paddingMedium
                        width: parent.width - 2 * Theme.horizontalPageMargin - 2 * Theme.paddingMedium
                        spacing: Theme.paddingSmall

                        Row {
                            width: parent.width
                            spacing: Theme.paddingMedium

                            Image {
                                id: cardLogoImage
                                source: instrumentIcon50(modelData.instrumentId)
                                width: 75
                                height: 75
                                fillMode: Image.PreserveAspectFit
                            }

                            Label {
                                width: parent.width * 0.34 - cardLogoImage.width - Theme.paddingMedium
                                text: modelData.symbol || ("#" + modelData.instrumentId)
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeMedium * 1.15
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                id: totalValueLabel
                                width: parent.width * 0.66 - Theme.paddingMedium
                                text: amountText(netValue(modelData), 2)
                                color: Number(modelData.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor
                                font.pixelSize: Theme.fontSizeMedium * 1.15
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.paddingMedium

                            Label {
                                width: parent.width * 0.34
                                text: modelData.displayName || (qsTr("Instrument ") + modelData.instrumentId)
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall * 0.9
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width * 0.66 - Theme.paddingMedium
                                text: amountText(profitPercent(modelData), 1) + "%"
                                color: Number(modelData.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.paddingMedium

                            Label {
                                width: parent.width * 0.34
                                text: qsTr("Invested:")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width * 0.66 - Theme.paddingMedium
                                text: amountText(modelData.invested, 2)
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.paddingMedium

                            Label {
                                width: parent.width * 0.34
                                text: qsTr("")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width * 0.66 - Theme.paddingMedium
                                text: amountText(modelData.units, 4)
                                      + qsTr(" Unit @ ")
                                      + amountText(modelData.averageOpenRate !== undefined ? modelData.averageOpenRate : modelData.openRate, 4)
                                color: Theme.primaryColor
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

                        Label {
                            width: parent.width
                            text: qsTr("Exposure: ") + amountText(modelData.exposureInAccountCurrency, 2)
                                  + " • "
                                  + qsTr("Current: ") + amountText(modelData.currentRate, 4)
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall * 0.9
                            truncationMode: TruncationMode.Fade
                        }
                    }

                    Column {
                        id: compactColumn
                        visible: page.viewMode === "compact"
                        x: Theme.horizontalPageMargin + Theme.paddingSmall
                        y: Theme.paddingSmall
                        width: parent.width - 2 * Theme.horizontalPageMargin - 2 * Theme.paddingSmall
                        spacing: 2

                        Row {
                            width: parent.width
                            spacing: Theme.paddingSmall
                            height: Theme.itemSizeSmall

                            Image {
                                id: compactLogoImage
                                source: instrumentIcon50(modelData.instrumentId)
                                width: 50
                                height: 50
                                fillMode: Image.PreserveAspectFit
                            }

                            Column {
                                width: parent.width * 0.24 - compactLogoImage.width - Theme.paddingSmall
                                spacing: 0

                                Label {
                                    width: parent.width
                                    text: shortAssetName(modelData)
                                    color: Theme.primaryColor
                                    font.pixelSize: Theme.fontSizeSmall
                                    truncationMode: TruncationMode.Fade
                                }

                                Label {
                                    width: parent.width
                                    text: amountText(modelData.currentRate, 4)
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeTiny
                                    truncationMode: TruncationMode.Fade
                                }
                            }

                            Item {
                                width: parent.width * 0.24
                                height: Theme.itemSizeSmall

                                Loader {
                                    id: compactLoader1
                                    anchors.fill: parent
                                    sourceComponent: (etoroClient.portfolioColumn1 === "buy" || etoroClient.portfolioColumn1 === "sell")
                                                     ? flashingColumnComponent
                                                     : staticColumnComponent

                                    property string columnMode: etoroClient.portfolioColumn1
                                    property var rowData: modelData

                                    onLoaded: {
                                        if (item) {
                                            item.columnMode = columnMode
                                            item.rowData = rowData
                                        }
                                    }
                                }
                            }

                            Item {
                                width: parent.width * 0.24
                                height: Theme.itemSizeSmall

                                Loader {
                                    id: compactLoader2
                                    anchors.fill: parent
                                    sourceComponent: (etoroClient.portfolioColumn2 === "buy" || etoroClient.portfolioColumn2 === "sell")
                                                     ? flashingColumnComponent
                                                     : staticColumnComponent

                                    property string columnMode: etoroClient.portfolioColumn2
                                    property var rowData: modelData

                                    onLoaded: {
                                        if (item) {
                                            item.columnMode = columnMode
                                            item.rowData = rowData
                                        }
                                    }
                                }
                            }

                            Item {
                                width: parent.width * 0.24
                                height: Theme.itemSizeSmall

                                Loader {
                                    id: compactLoader3
                                    anchors.fill: parent
                                    sourceComponent: (etoroClient.portfolioColumn3 === "buy" || etoroClient.portfolioColumn3 === "sell")
                                                     ? flashingColumnComponent
                                                     : staticColumnComponent

                                    property string columnMode: etoroClient.portfolioColumn3
                                    property var rowData: modelData

                                    onLoaded: {
                                        if (item) {
                                            item.columnMode = columnMode
                                            item.rowData = rowData
                                        }
                                    }
                                }
                            }
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
                }
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }

        VerticalScrollDecorator { }
    }
}
