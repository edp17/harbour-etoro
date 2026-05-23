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

    property bool initialLoadDone: false
    property bool showFilterControls: false
    property string filterText: etoroClient.historyFilterText
    property string selectedRangeLabel: qsTr("Last 30 days")
    property var filteredHistory: []
    property bool historyAvailable: !etoroClient.demoMode
    property bool customRangeVisible: false
    property string customFromDateText: etoroClient.historyCustomFromDate

    function amountText(value, decimals) {
        return Number(value || 0).toLocaleString(Qt.locale(), 'f', decimals)
    }

    function dateText(value) {
        if (!value || value === "")
            return "—"

        var d = new Date(value)
        if (isNaN(d.getTime()))
            return value

        return Qt.formatDateTime(d, "dd MMM yyyy hh:mm")
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

    function shortIsoDate(value) {
        if (!value || value === "")
            return ""
        return String(value).slice(0, 10)
    }

    function isoDaysAgo(days) {
        var d = new Date()
        d.setUTCDate(d.getUTCDate() - days)
        return d.toISOString()
    }

    function isoYearsAgo(years) {
        var d = new Date()
        d.setUTCFullYear(d.getUTCFullYear() - years)
        return d.toISOString()
    }

    function loadRange(minDateIso, labelText) {
        etoroClient.registerUserActivity()
        selectedRangeLabel = labelText
        filterText = ""
        if (filterField.text !== "")
            filterField.text = ""
        etoroClient.refreshTradeHistoryFrom(minDateIso)
    }

    function profitPercent(item) {
        var invested = Number(item.investment || 0)
        var pnl = Number(item.netProfit || 0)
        if (invested === 0)
            return 0
        return (pnl / invested) * 100.0
    }

    function netValue(item) {
        return Number(item.investment || 0) + Number(item.netProfit || 0)
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

    function instrumentIcon50(instrumentId) {
        if (instrumentId === undefined || instrumentId === null || instrumentId === "")
            return ""

        return "https://etoro-cdn.etorostatic.com/market-avatars/"
                + String(instrumentId)
                + "/50x50.png"
    }

    function applyFilterNow() {
        var source = etoroClient.tradeHistory || []
        var q = filterText ? filterText.toLowerCase().trim() : ""
        var toDate = etoroClient.historyCustomRangeEnabled ? String(etoroClient.historyCustomToDate || "") : ""

        var out = []

        for (var i = 0; i < source.length; ++i) {
            var item = source[i]

            if (toDate !== "") {
                var itemDate = historyItemDate(item)
                if (itemDate !== "" && itemDate > toDate)
                    continue
            }

            if (q) {
                var name = String(item.displayName || "").toLowerCase()
                var symbol = String(item.symbol || "").toLowerCase()
                var instrumentId = String(item.instrumentId || "").toLowerCase()

                if (name.indexOf(q) === -1
                        && symbol.indexOf(q) === -1
                        && instrumentId.indexOf(q) === -1)
                    continue
            }

            out.push(item)
        }

        filteredHistory = out
    }

    Timer {
        id: filterDebounceTimer
        interval: 180
        repeat: false
        onTriggered: page.applyFilterNow()
    }

    onFilterTextChanged: filterDebounceTimer.restart()

    Connections {
        target: etoroClient

        onTradeHistoryChanged: {
            page.applyFilterNow()

            if (etoroClient.tradeHistory.length === 0) {
                page.showFilterControls = false
                page.filterText = ""
                filterField.text = ""
                etoroClient.setHistoryFilterText("")
            }
        }

        onHistoryUiChanged: page.applyFilterNow()
    }

    Component.onCompleted: {
        filterField.text = etoroClient.historyFilterText
        page.filterText = etoroClient.historyFilterText

        if (!initialLoadDone) {
            initialLoadDone = true

            if (page.historyAvailable)
                loadRange(isoDaysAgo(30), qsTr("Last 30 days"))
            else
                selectedRangeLabel = qsTr("Last 30 days")
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Statistics")
                enabled: page.historyAvailable && !etoroClient.historyLoading && etoroClient.tradeHistory.length > 0
                visible: page.historyAvailable
                onClicked: {
                    etoroClient.registerUserActivity()
                    pageStack.push(Qt.resolvedUrl("StatisticsPage.qml"), {
                        tradeHistoryData: etoroClient.tradeHistory,
                        selectedRangeLabel: page.selectedRangeLabel
                    })
                }
            }
            MenuItem {
                text: qsTr("Refresh current range")
                enabled: page.historyAvailable && !etoroClient.busy && !etoroClient.locked && etoroClient.historyMinDate.length > 0
                visible: page.historyAvailable
                onClicked: loadRange(etoroClient.historyMinDate, selectedRangeLabel)
            }
            MenuItem {
                text: qsTr("Last 30 days")
                enabled: page.historyAvailable && !etoroClient.busy && !etoroClient.locked
                visible: page.historyAvailable
                onClicked: {
                    etoroClient.clearHistoryCustomRange()
                    loadRange(isoDaysAgo(30), qsTr("Last 30 days"))
                }
            }
            MenuItem {
                text: qsTr("Last 90 days")
                enabled: page.historyAvailable && !etoroClient.busy && !etoroClient.locked
                visible: page.historyAvailable
                onClicked: {
                    etoroClient.clearHistoryCustomRange()
                    loadRange(isoDaysAgo(90), qsTr("Last 90 days"))
                }
            }
            MenuItem {
                text: qsTr("Last 365 days")
                enabled: page.historyAvailable && !etoroClient.busy && !etoroClient.locked
                visible: page.historyAvailable
                onClicked: {
                    etoroClient.clearHistoryCustomRange()
                    loadRange(isoDaysAgo(365), qsTr("Last 365 days"))
                }
            }
            MenuItem {
                text: qsTr("Last 5 years")
                enabled: page.historyAvailable && !etoroClient.busy && !etoroClient.locked
                visible: page.historyAvailable
                onClicked: {
                    etoroClient.clearHistoryCustomRange()
                    loadRange(isoYearsAgo(5), qsTr("Last 5 years"))
                }
            }
            MenuItem {
                text: qsTr("Last 10 years")
                enabled: page.historyAvailable && !etoroClient.busy && !etoroClient.locked
                visible: page.historyAvailable
                onClicked: {
                    etoroClient.clearHistoryCustomRange()
                    loadRange(isoYearsAgo(10), qsTr("Last 10 years"))
                }
            }
            MenuItem {
                text: qsTr("Custom range")
                enabled: !etoroClient.busy && !etoroClient.demoMode
                onClicked: customRangeOverlay.open()
            }
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("History (%1)").arg(etoroClient.accountModeLabel)
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !page.historyAvailable
                height: virtualHistoryColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: virtualHistoryColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Trade history is not available in Virtual mode")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Switch to Real account mode to view closed trades and transaction history.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                visible: page.historyAvailable
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
                    visible: page.historyAvailable
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Row {
                        width: parent.width
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width - filterToggle.width - Theme.paddingSmall
                            text: qsTr("Closed trades")
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall
                            verticalAlignment: Text.AlignVCenter
                        }

                        IconButton {
                            id: filterToggle
                            icon.source: "image://theme/icon-m-search"
                            highlighted: page.showFilterControls
                            enabled: !etoroClient.historyLoading && etoroClient.tradeHistory.length > 0
                            onClicked: {
                                page.showFilterControls = !page.showFilterControls
                                etoroClient.registerUserActivity()

                                if (!page.showFilterControls) {
                                    filterField.text = ""
                                    page.filterText = ""
                                }
                            }
                        }
                    }

                    SearchField {
                        id: filterField
                        width: parent.width
                        visible: page.showFilterControls && etoroClient.tradeHistory.length > 0
                        placeholderText: qsTr("Filter trades")
                        onTextChanged: {
                            page.filterText = text
                            etoroClient.setHistoryFilterText(text)
                            etoroClient.registerUserActivity()
                        }
                    }

                    Item {
                        width: parent.width
                        height: etoroClient.historyLoading && etoroClient.tradeHistory.length === 0
                                ? loadingColumn.height + Theme.paddingSmall
                                : 0
                        visible: etoroClient.historyLoading && etoroClient.tradeHistory.length === 0

                        Column {
                            id: loadingColumn
                            anchors.centerIn: parent
                            width: parent.width
                            spacing: Theme.paddingMedium

                            BusyIndicator {
                                anchors.horizontalCenter: parent.horizontalCenter
                                size: BusyIndicatorSize.Medium
                                running: etoroClient.historyLoading
                                visible: etoroClient.historyLoading
                            }

                            Label {
                                width: parent.width
                                text: qsTr("Loading history…")
                                color: Theme.primaryColor
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
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

                    Label {
                        width: parent.width
                        visible: !etoroClient.historyLoading && etoroClient.tradeHistory.length > 0
                        text: qsTr("Page: ") + String(etoroClient.historyCurrentPage || 0)
                              + " • "
                              + qsTr("Page size: ") + String(etoroClient.historyPageSize || 0)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        visible: !etoroClient.busy && !etoroClient.historyLoading && page.filterText.trim().length > 0
                        text: qsTr("Matches: ") + String(page.filteredHistory.length)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Rectangle {
                        width: parent.width
                        height: 3
                        color: Theme.rgba(Theme.primaryColor, 0.01)
                    }

                    Label {
                        width: parent.width
                        visible: !etoroClient.busy && !etoroClient.historyLoading && page.filteredHistory.length === 0
                        text: page.filterText.trim().length > 0
                              ? qsTr("No transactions match the current filter.")
                              : qsTr("No trade history in the selected range.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                visible: page.historyAvailable && page.filteredHistory.length > 0
                width: parent.width - 2 * x
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
                        width: parent.width * 0.34
                        text: qsTr("Trade")
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
                        width: parent.width * 0.22
                        text: qsTr("Net value")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeTiny
                        horizontalAlignment: Text.AlignRight
                        truncationMode: TruncationMode.Fade
                    }
                }
            }

            Repeater {
                model: page.filteredHistory

                delegate: BackgroundItem {
                    width: parent ? parent.width : page.width
                    height: compactColumn.height + Theme.paddingSmall * 2

                    onClicked: {
                        etoroClient.registerUserActivity()
                        pageStack.push(Qt.resolvedUrl("TradeDetailPage.qml"), {
                            tradeData: modelData
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

                            Column {
                                width: parent.width * 0.34
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
                                        width: parent.width - logoImage.width - Theme.paddingSmall
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
                                            text: (modelData.displayName || "")
                                            color: Theme.secondaryColor
                                            font.pixelSize: Theme.fontSizeTiny
                                            truncationMode: TruncationMode.Fade
                                            visible: (modelData.displayName || "").length > 0
                                        }
                                    }
                                }

                                Label {
                                    width: parent.width
                                    text: dateText(modelData.closeTimestamp)
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeTiny
                                    truncationMode: TruncationMode.Fade
                                }
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
                                width: parent.width * 0.22
                                text: amountText(netValue(modelData), 2)
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                verticalAlignment: Text.AlignVCenter
                                truncationMode: TruncationMode.Fade
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: footerColumn.height
                visible: page.historyAvailable && (etoroClient.historyHasMore || etoroClient.tradeHistory.length > 0)

                Column {
                    id: footerColumn
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    spacing: Theme.paddingMedium

                    BusyIndicator {
                        anchors.horizontalCenter: parent.horizontalCenter
                        running: etoroClient.busy && etoroClient.tradeHistory.length > 0
                        visible: running
                        size: BusyIndicatorSize.Medium
                    }

                    Button {
                        width: parent.width
                        visible: etoroClient.historyHasMore && !etoroClient.busy
                        text: qsTr("Load more")
                        onClicked: {
                            etoroClient.registerUserActivity()
                            etoroClient.loadMoreTradeHistory()
                        }
                    }

                    Label {
                        width: parent.width
                        visible: !etoroClient.historyHasMore && etoroClient.tradeHistory.length > 0
                        text: qsTr("No more results in the current range.")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
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

    // Custom range overlay
    HistoryCustomRangeOverlay {
        id: customRangeOverlay
    }
}
