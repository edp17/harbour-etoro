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
        return Number(item.invested || 0) + Number(item.netProfit || 0)
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

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("Position")
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
                            width: parent.width * 0.34
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
                                text: page.positionData.displayName || (qsTr("Instrument ") + page.positionData.instrumentId)
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                truncationMode: TruncationMode.Fade
                            }
                        }

                        Label {
                            id: totalValueLabel
                            anchors.verticalCenter: logoSlot.verticalCenter
                            width: parent.width * 0.40
                            text: amountText(netValue(page.positionData), 2)
                            color: Number(page.positionData.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor
                            font.pixelSize: Theme.fontSizeMedium
                            horizontalAlignment: Text.AlignRight
                            truncationMode: TruncationMode.Fade
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
                            text: amountText(profitPercent(page.positionData), 1) + "%"
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

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Label {
                            width: parent.width * 0.34
                            text: qsTr("Sell:")
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            truncationMode: TruncationMode.Fade
                        }

                        Item {
                            width: parent.width * 0.66 - Theme.paddingMedium
                            height: positionSellValue.implicitHeight

                            PriceFlashValue {
                                id: positionSellValue
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                rawValue: (etoroClient.quoteForPositionInstrument(page.positionData.instrumentId) || {}).ask
                                decimals: 4
                                textColor: Theme.secondaryColor
                                fontSize: Theme.fontSizeSmall
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Label {
                            width: parent.width * 0.34
                            text: qsTr("Buy:")
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            truncationMode: TruncationMode.Fade
                        }

                        Item {
                            width: parent.width * 0.66 - Theme.paddingMedium
                            height: positionBuyValue.implicitHeight

                            PriceFlashValue {
                                id: positionBuyValue
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                rawValue: (etoroClient.quoteForPositionInstrument(page.positionData.instrumentId) || {}).bid
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
                                    pageTitle: page.detailPageTitle(modelData)
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
}
