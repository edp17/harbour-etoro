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

    function valueText(v) {
        return (v === undefined || v === null || v === "") ? "—" : String(v)
    }

    function numberText(v, decimals) {
        if (v === undefined || v === null || v === "")
            return "—"
        return Number(v).toLocaleString(Qt.locale(), 'f', decimals)
    }

    function instrumentIcon50(instrumentId) {
        if (instrumentId === undefined || instrumentId === null || instrumentId === "")
            return ""

        return "https://etoro-cdn.etorostatic.com/market-avatars/"
                + String(instrumentId)
                + "/50x50.png"
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
    }

    onStatusChanged: {
        if (status === PageStatus.Active
                && page.instrumentData
                && page.instrumentData.instrumentId !== undefined) {
            etoroClient.loadInstrumentQuote(page.instrumentData)
        }
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
                enabled: etoroClient.tradingEnabled

                text: qsTr("Open position")

                onClicked: {
                    pageStack.push(Qt.resolvedUrl("OpenPositionPage.qml"), {
                        instrumentData: {
                            instrumentId: page.instrumentData.instrumentId,
                            symbol: page.instrumentData.symbol,
                            displayName: page.instrumentData.displayName
                        }
                    })
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
                    width: parent.width
                    title: page.instrumentData.displayName || (qsTr("Instrument ") + valueText(page.instrumentData.instrumentId))
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
                                source: instrumentIcon50(page.instrumentData.instrumentId)
                                width: 100
                                height: 100
                                fillMode: Image.PreserveAspectFit
                            }
                        }

                        Label {
                            id: symbolLabel
                            width: etoroClient.tradingEnabled
                                   ? parent.width - logoSlot.width - openPositionButton.width - Theme.paddingMedium * 2
                                   : parent.width - logoSlot.width - Theme.paddingMedium
                            anchors.verticalCenter: logoSlot.verticalCenter
                            text: page.instrumentData.symbol || ("#" + valueText(page.instrumentData.instrumentId))
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeLarge
                            truncationMode: TruncationMode.Fade
                        }

                        Button {
                            id: openPositionButton
                            visible: etoroClient.tradingEnabled
                            anchors.verticalCenter: logoSlot.verticalCenter
                            text: qsTr("Open position")

                            onClicked: {
                                pageStack.push(Qt.resolvedUrl("OpenPositionPage.qml"), {
                                    instrumentData: {
                                        instrumentId: page.instrumentData.instrumentId,
                                        symbol: page.instrumentData.symbol,
                                        displayName: page.instrumentData.displayName
                                    }
                                })
                                etoroClient.registerUserActivity()
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        // --- Sell ---
                        Item {
                            width: parent.width
                            height: Math.max(sellLabel.height, sellValue.implicitHeight)

                            Label {
                                id: sellLabel
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Sell:")
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            PriceFlashValue {
                                id: sellValue
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                rawValue: etoroClient.selectedInstrumentQuote.sellPrice
                                decimals: 4
                                textColor: Theme.primaryColor
                                fontSize: Theme.fontSizeSmall
                            }
                        }

                        // --- Buy ---
                        Item {
                            width: parent.width
                            height: Math.max(buyLabel.height, buyValue.implicitHeight)

                            Label {
                                id: buyLabel
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Buy:")
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            PriceFlashValue {
                                id: buyValue
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                rawValue: etoroClient.selectedInstrumentQuote.buyPrice
                                decimals: 4
                                textColor: Theme.primaryColor
                                fontSize: Theme.fontSizeSmall
                            }
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
                        text: (page.instrumentData.displayName || qsTr("Instrument")) + qsTr(" details")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Price source: ") + valueText(page.instrumentData.priceSource)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Watchlist item rank: ") + valueText(page.instrumentData.itemRank)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
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
}
