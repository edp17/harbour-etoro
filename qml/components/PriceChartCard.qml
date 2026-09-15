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
import "../js/AssetUtils.js" as AssetUtils

Item {
    id: root
    width: parent ? parent.width : Screen.width
    height: chartPanel.height

    property int instrumentId: 0
    property string assetName: ""
    property bool completed: false
    property int selectedCandleIndex: -1
    property var ranges: [
        { label: qsTr("1 day"), interval: "FifteenMinutes", count: 96 },
        { label: qsTr("1 week"), interval: "FourHours", count: 42 },
        { label: qsTr("1 month"), interval: "OneDay", count: 30 },
        { label: qsTr("3 months"), interval: "OneDay", count: 90 },
        { label: qsTr("1 year"), interval: "OneWeek", count: 52 }
    ]

    function loadSelectedRange() {
        if (!root.completed || root.instrumentId <= 0 || rangeCombo.currentIndex < 0)
            return
        var range = root.ranges[rangeCombo.currentIndex]
        root.selectedCandleIndex = -1
        etoroClient.loadPriceChart(root.instrumentId, range.interval, range.count)
    }

    function selectNearestCandle(x, chartWidth) {
        var candles = etoroClient.priceChartCandles || []
        if (candles.length < 2 || chartWidth <= 0)
            return

        var pad = Theme.paddingSmall
        var usableWidth = Math.max(1, chartWidth - 2 * pad)
        var relativeX = Math.max(0, Math.min(usableWidth, x - pad))
        root.selectedCandleIndex = Math.round(relativeX * (candles.length - 1) / usableWidth)
        chart.requestPaint()
    }

    function selectedCandle() {
        var candles = etoroClient.priceChartCandles || []
        if (root.selectedCandleIndex < 0 || root.selectedCandleIndex >= candles.length)
            return null
        return candles[root.selectedCandleIndex]
    }

    function candleDateText(candle) {
        if (!candle)
            return ""
        var value = candle.fromDate || candle.date || candle.timestamp || candle.FromDate || ""
        if (!value)
            return ""
        var date = new Date(value)
        if (isNaN(date.getTime()))
            return String(value)
        var range = root.ranges[rangeCombo.currentIndex]
        return range && (range.interval === "FifteenMinutes" || range.interval === "FourHours")
                ? Qt.formatDateTime(date, "dd MMM, hh:mm")
                : Qt.formatDate(date, "dd MMM yyyy")
    }

    onInstrumentIdChanged: loadSelectedRange()

    Connections {
        target: etoroClient
        onPriceChartChanged: {
            if (etoroClient.priceChartLoading)
                root.selectedCandleIndex = -1
            chart.requestPaint()
        }
    }

    Rectangle {
        id: chartPanel
        x: Theme.horizontalPageMargin
        width: root.width - 2 * x
        height: chartColumn.height + 2 * Theme.paddingMedium
        radius: Theme.paddingMedium
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
        border.width: 1
        border.color: Theme.rgba(Theme.highlightColor, 0.18)

        Column {
            id: chartColumn
            x: Theme.paddingMedium
            y: Theme.paddingMedium
            width: parent.width - 2 * Theme.paddingMedium
            spacing: Theme.paddingSmall

            Label {
                width: parent.width
                text: root.assetName.length > 0
                      ? qsTr("Price history — %1").arg(root.assetName)
                      : qsTr("Price history")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                truncationMode: TruncationMode.Fade
            }

            ComboBox {
                id: rangeCombo
                width: parent.width
                label: qsTr("Range")
                currentIndex: 2

                menu: ContextMenu {
                    Repeater {
                        model: root.ranges
                        delegate: MenuItem { text: modelData.label }
                    }
                }

                onCurrentIndexChanged: root.loadSelectedRange()
            }

            Item {
                width: parent.width
                height: Theme.itemSizeHuge * 1.5

                BusyIndicator {
                    anchors.centerIn: parent
                    running: etoroClient.priceChartLoading
                    size: BusyIndicatorSize.Medium
                }

                Label {
                    anchors.centerIn: parent
                    width: parent.width
                    visible: !etoroClient.priceChartLoading
                             && etoroClient.priceChartError.length > 0
                    text: etoroClient.priceChartError
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }

                Canvas {
                    id: chart
                    anchors.fill: parent
                    anchors.margins: Theme.paddingSmall
                    visible: !etoroClient.priceChartLoading
                             && etoroClient.priceChartError.length === 0
                             && etoroClient.priceChartCandles.length > 1

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        var candles = etoroClient.priceChartCandles || []
                        if (candles.length < 2)
                            return

                        var min = Number(candles[0].close)
                        var max = min
                        for (var i = 1; i < candles.length; ++i) {
                            var price = Number(candles[i].close)
                            min = Math.min(min, price)
                            max = Math.max(max, price)
                        }

                        var span = Math.max(max - min, Math.abs(max) * 0.001, 0.000001)
                        var pad = Theme.paddingSmall
                        var chartWidth = width - 2 * pad
                        var chartHeight = height - 2 * pad

                        ctx.strokeStyle = Theme.rgba(Theme.secondaryColor, 0.25)
                        ctx.lineWidth = 1
                        for (var grid = 0; grid <= 3; ++grid) {
                            var gridY = pad + chartHeight * grid / 3
                            ctx.beginPath()
                            ctx.moveTo(pad, gridY)
                            ctx.lineTo(width - pad, gridY)
                            ctx.stroke()
                        }

                        ctx.strokeStyle = Number(candles[candles.length - 1].close) >= Number(candles[0].close)
                                ? Theme.highlightColor : Theme.errorColor
                        ctx.lineWidth = Math.max(2, Theme.paddingSmall / 3)
                        ctx.beginPath()
                        for (i = 0; i < candles.length; ++i) {
                            var x = pad + chartWidth * i / (candles.length - 1)
                            var y = pad + chartHeight * (max - Number(candles[i].close)) / span
                            if (i === 0)
                                ctx.moveTo(x, y)
                            else
                                ctx.lineTo(x, y)
                        }
                        ctx.stroke()

                        if (root.selectedCandleIndex >= 0
                                && root.selectedCandleIndex < candles.length) {
                            var selectedX = pad + chartWidth * root.selectedCandleIndex / (candles.length - 1)
                            var selectedY = pad + chartHeight
                                    * (max - Number(candles[root.selectedCandleIndex].close)) / span

                            ctx.strokeStyle = Theme.primaryColor
                            ctx.lineWidth = 1
                            ctx.beginPath()
                            ctx.moveTo(selectedX, pad)
                            ctx.lineTo(selectedX, height - pad)
                            ctx.stroke()

                            ctx.fillStyle = Theme.primaryColor
                            ctx.beginPath()
                            ctx.arc(selectedX, selectedY, Theme.paddingSmall / 2, 0, Math.PI * 2)
                            ctx.fill()
                        }
                    }
                }

                MouseArea {
                    anchors.fill: chart
                    enabled: chart.visible
                    preventStealing: false
                    onClicked: root.selectNearestCandle(mouse.x, width)
                }
            }

            Label {
                width: parent.width
                visible: root.selectedCandle() !== null
                text: {
                    var candle = root.selectedCandle()
                    var dateText = root.candleDateText(candle)
                    var priceText = AssetUtils.numberText(candle ? candle.close : "", 4)
                    return dateText.length > 0
                            ? qsTr("%1 · Close: %2").arg(dateText).arg(priceText)
                            : qsTr("Close: %1").arg(priceText)
                }
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                visible: etoroClient.priceChartCandles.length > 1
                         && root.selectedCandle() === null
                text: qsTr("Tap the chart to inspect a price.")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                horizontalAlignment: Text.AlignHCenter
            }

            Row {
                width: parent.width
                visible: etoroClient.priceChartCandles.length > 1
                spacing: Theme.paddingMedium

                Label {
                    width: (parent.width - Theme.paddingMedium) / 2
                    text: qsTr("Low: %1").arg(AssetUtils.numberText(chartLow(), 4))
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                }

                Label {
                    width: (parent.width - Theme.paddingMedium) / 2
                    text: qsTr("High: %1").arg(AssetUtils.numberText(chartHigh(), 4))
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    function chartLow() {
        var candles = etoroClient.priceChartCandles || []
        if (candles.length === 0)
            return 0
        var value = Number(candles[0].low)
        for (var i = 1; i < candles.length; ++i)
            value = Math.min(value, Number(candles[i].low))
        return value
    }

    function chartHigh() {
        var candles = etoroClient.priceChartCandles || []
        if (candles.length === 0)
            return 0
        var value = Number(candles[0].high)
        for (var i = 1; i < candles.length; ++i)
            value = Math.max(value, Number(candles[i].high))
        return value
    }

    Component.onCompleted: {
        root.completed = true
        loadSelectedRange()
    }
}
