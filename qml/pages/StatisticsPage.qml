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

Page {
    id: page

    property var tradeHistoryData: []
    property string selectedRangeLabel: ""
    property var groupedStats: []
    property var totals: ({
        invested: 0,
        netProfit: 0,
        trades: 0
    })

    property bool showSortControls: false
    property string sortMode: etoroClient.statisticsSortMode
    property bool sortDescending: true

    function shortIsoDate(value) {
        if (!value)
            return ""
        return String(value).substring(0, 10)
    }

    function historyItemDate(item) {
        var value = item.closeTimestamp || item.closeDateTime || item.closeDate || item.openTimestamp || item.openDateTime || ""
        return shortIsoDate(value)
    }

    function activeRangeLabel() {
        if (etoroClient.historyCustomRangeEnabled) {
            if (etoroClient.historyCustomToDate && etoroClient.historyCustomToDate.length > 0)
                return etoroClient.historyCustomFromDate + " - " + etoroClient.historyCustomToDate

            return qsTr("From ") + etoroClient.historyCustomFromDate
        }

        return selectedRangeLabel
    }

    function compareByAsset(a, b) {
        var an = String(a.displayName || a.symbol || "").toLowerCase()
        var bn = String(b.displayName || b.symbol || "").toLowerCase()
        if (an < bn) return page.sortDescending ? 1 : -1
        if (an > bn) return page.sortDescending ? -1 : 1
        return 0
    }

    function compareByTrades(a, b) {
        var av = Number(a.trades || 0)
        var bv = Number(b.trades || 0)
        return page.sortDescending ? (bv - av) : (av - bv)
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

    function compareByProfitPercent(a, b) {
        var ap = Number(a.invested || 0) === 0 ? 0 : (Number(a.netProfit || 0) / Number(a.invested || 0)) * 100.0
        var bp = Number(b.invested || 0) === 0 ? 0 : (Number(b.netProfit || 0) / Number(b.invested || 0)) * 100.0
        return page.sortDescending ? (bp - ap) : (ap - bp)
    }

    function amountText(value, decimals) {
        return Number(value || 0).toLocaleString(Qt.locale(), 'f', decimals)
    }

    function percentText(pnl, invested) {
        var i = Number(invested || 0)
        var p = Number(pnl || 0)
        if (i === 0)
            return "0.0%"
        return amountText((p / i) * 100.0, 1) + "%"
    }

    function rebuildStats() {
        var grouped = {}
        var toDate = etoroClient.historyCustomRangeEnabled ? String(etoroClient.historyCustomToDate || "") : ""
        var totalInvested = 0
        var totalProfit = 0
        var totalTrades = 0

        for (var i = 0; i < tradeHistoryData.length; ++i) {
            var item = tradeHistoryData[i]
            if (toDate !== "") {
                var itemDate = historyItemDate(item)
                if (itemDate !== "" && itemDate > toDate)
                    continue
            }
            var instrumentId = String(item.instrumentId || "")
            var symbol = String(item.symbol || "")
            var displayName = String(item.displayName || "")

            var key = instrumentId.length > 0 ? instrumentId : (symbol.length > 0 ? symbol : displayName)

            if (!grouped[key]) {
                grouped[key] = {
                    instrumentId: instrumentId,
                    symbol: symbol,
                    displayName: displayName,
                    trades: 0,
                    invested: 0,
                    netProfit: 0
                }
            }

            grouped[key].trades += 1
            grouped[key].invested += Number(item.investment || 0)
            grouped[key].netProfit += Number(item.netProfit || 0)

            totalTrades += 1
            totalInvested += Number(item.investment || 0)
            totalProfit += Number(item.netProfit || 0)
        }

        var out = []
        for (var k in grouped)
            out.push(grouped[k])

        if (sortMode === "trades")
            out.sort(compareByTrades)
        else if (sortMode === "invested")
            out.sort(compareByInvested)
        else if (sortMode === "profit")
            out.sort(compareByProfit)
        else if (sortMode === "profitPercent")
            out.sort(compareByProfitPercent)
        else
            out.sort(compareByAsset)

        groupedStats = out
        totals = {
            invested: totalInvested,
            netProfit: totalProfit,
            trades: totalTrades
        }
    }

    function instrumentIcon50(instrumentId) {
        if (instrumentId === undefined || instrumentId === null || instrumentId === "")
            return ""

        return "https://etoro-cdn.etorostatic.com/market-avatars/"
                + String(instrumentId)
                + "/50x50.png"
    }

    onSortModeChanged: rebuildStats()
    onSortDescendingChanged: rebuildStats()

    Component.onCompleted: {
        if (sortMode === "trades")
            sortCombo.currentIndex = 1
        else if (sortMode === "invested")
            sortCombo.currentIndex = 2
        else if (sortMode === "profit")
            sortCombo.currentIndex = 3
        else if (sortMode === "profitPercent")
            sortCombo.currentIndex = 4
        else
            sortCombo.currentIndex = 0

        rebuildStats()
    }

    Connections {
        target: etoroClient

        onHistoryUiChanged: page.rebuildStats()
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Statistics (%1)").arg(etoroClient.accountModeLabel)
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

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Label {
                            width: parent.width - sortToggle.width - Theme.paddingMedium
                            text: qsTr("Closed trade statistics")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall
                            verticalAlignment: Text.AlignVCenter
                        }

                        IconButton {
                            id: sortToggle
                            icon.source: "image://theme/icon-m-transfer"
                            highlighted: page.showSortControls
                            enabled: groupedStats.length > 0
                            onClicked: {
                                page.showSortControls = !page.showSortControls
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Range: ") + page.activeRangeLabel()
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Row {
                        width: parent.width
                        height: sortCombo.height
                        visible: page.showSortControls && groupedStats.length > 0
                        spacing: Theme.paddingSmall

                        ComboBox {
                            id: sortCombo
                            width: parent.width - directionLabel.width - directionButton.width - Theme.paddingSmall * 2
                            label: qsTr("Sort by")

                            menu: ContextMenu {
                                MenuItem { text: qsTr("Asset") }
                                MenuItem { text: qsTr("Trades") }
                                MenuItem { text: qsTr("Invested") }
                                MenuItem { text: qsTr("P/L") }
                                MenuItem { text: qsTr("P/L (%)") }
                            }

                            currentIndex: 0

                            onCurrentIndexChanged: {
                                if (currentIndex === 0)
                                    page.sortMode = "asset"
                                else if (currentIndex === 1)
                                    page.sortMode = "trades"
                                else if (currentIndex === 2)
                                    page.sortMode = "invested"
                                else if (currentIndex === 3)
                                    page.sortMode = "profit"
                                else
                                    page.sortMode = "profitPercent"

                                etoroClient.setStatisticsSortMode(page.sortMode)
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
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        visible: groupedStats.length === 0
                        text: qsTr("No statistics available for the selected range.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: groupedStats.length > 0
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
                        width: parent.width * 0.20
                        text: qsTr("Asset")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeTiny
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width * 0.10
                        text: qsTr("Trades")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeTiny
                        horizontalAlignment: Text.AlignRight
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width * 0.25
                        text: qsTr("Invested")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeTiny
                        horizontalAlignment: Text.AlignRight
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width * 0.21
                        text: qsTr("P/L")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeTiny
                        horizontalAlignment: Text.AlignRight
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
                }
            }

            Repeater {
                model: groupedStats

                delegate: Rectangle {
                    x: Theme.horizontalPageMargin
                    width: page.width - 2 * Theme.horizontalPageMargin
                    height: rowColumn.height + Theme.paddingSmall * 2
                    radius: Theme.paddingSmall
                    color: Theme.rgba(Theme.highlightBackgroundColor, 0.06)
                    border.width: 1
                    border.color: Theme.rgba(Theme.highlightColor, 0.10)

                    Column {
                        id: rowColumn
                        x: Theme.paddingSmall
                        y: Theme.paddingSmall
                        width: parent.width - 2 * Theme.paddingSmall
                        spacing: 2

                        Row {
                            width: parent.width
                            spacing: Theme.paddingSmall

                            Item {
                                id: logoSlot
                                width: 35
                                height: 35

                                Image {
                                    id: logoImage
                                    anchors.centerIn: parent
                                    source: instrumentIcon50(modelData.instrumentId)
                                    width: 35
                                    height: 35
                                    fillMode: Image.PreserveAspectFit
                                }
                            }

                            Label {
                                width: parent.width * 0.20 - logoSlot.width - Theme.paddingSmall
                                anchors.verticalCenter: logoSlot.verticalCenter
                                text: modelData.symbol || ("#" + modelData.instrumentId)
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width * 0.10
                                text: String(modelData.trades || 0)
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width * 0.25
                                text: amountText(modelData.invested, 2)
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width * 0.21
                                text: amountText(modelData.netProfit, 2)
                                color: Number(modelData.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width * 0.18
                                text: percentText(modelData.netProfit, modelData.invested)
                                color: Number(modelData.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }
                        }

                        Label {
                            width: parent.width
                            visible: (modelData.displayName || "").length > 0
                            text: modelData.displayName || ""
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeTiny
                            truncationMode: TruncationMode.Fade
                        }
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: groupedStats.length > 0
                height: Theme.paddingSmall
                color: Theme.rgba(Theme.primaryColor, 0.4)
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: groupedStats.length > 0
                height: totalColumn.height + Theme.paddingSmall * 2
                radius: Theme.paddingSmall
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.06)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.12)

                Column {
                    id: totalColumn
                    x: Theme.paddingSmall
                    y: Theme.paddingSmall
                    width: parent.width - 2 * Theme.paddingSmall
                    spacing: 2

                    Row {
                        width: parent.width
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width * 0.20
                            text: qsTr("Total")
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            truncationMode: TruncationMode.Fade
                        }

                        Label {
                            width: parent.width * 0.10
                            text: String(totals.trades || 0)
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            horizontalAlignment: Text.AlignRight
                            truncationMode: TruncationMode.Fade
                        }

                        Label {
                            width: parent.width * 0.25
                            text: amountText(totals.invested, 2)
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                            truncationMode: TruncationMode.Fade
                        }

                        Label {
                            width: parent.width * 0.21
                            text: amountText(totals.netProfit, 2)
                            color: Number(totals.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                            truncationMode: TruncationMode.Fade
                        }

                        Label {
                            width: parent.width * 0.18
                            text: percentText(totals.netProfit, totals.invested)
                            color: Number(totals.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
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
}
