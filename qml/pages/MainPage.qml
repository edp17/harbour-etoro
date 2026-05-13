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

    property bool initialLoadDone: false

    function amountText(value, decimals) {
        return Number(value || 0).toLocaleString(Qt.locale(), 'f', decimals)
    }

    function quoteText(instrumentId) {
        var q = etoroClient.quoteForPositionInstrument(instrumentId)
        if (!q || Object.keys(q).length === 0)
            return ""

        return qsTr("Bid: ") + amountText(q.bid, 6)
                + "   •   "
                + qsTr("Ask: ") + amountText(q.ask, 6)
                + "   •   "
                + qsTr("Last: ") + amountText(q.lastExecutionPrice, 6)
    }

    function instrumentIcon50(instrumentId) {
        if (instrumentId === undefined || instrumentId === null || instrumentId === "")
            return ""

        return "https://etoro-cdn.etorostatic.com/market-avatars/"
                + String(instrumentId)
                + "/50x50.png"
    }

    Component.onCompleted: {
        if (!initialLoadDone) {
            initialLoadDone = true

            if (etoroClient.hasCredentials && !etoroClient.locked) {
                etoroClient.refreshPortfolio()
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: qsTr("Refresh")
                enabled: etoroClient.hasCredentials && !etoroClient.busy && !etoroClient.locked
                onClicked: {
                    etoroClient.registerUserActivity()
                    etoroClient.refreshPortfolio()
                }
            }
            MenuItem {
                text: qsTr("Portfolio")
                enabled: etoroClient.openPositions.length > 0
                onClicked: {
                    etoroClient.registerUserActivity()
                    pageStack.push(Qt.resolvedUrl("PortfolioPage.qml"))
                }
            }
            MenuItem {
                text: qsTr("Watchlists")
                enabled: etoroClient.hasCredentials && !etoroClient.busy
                onClicked: {
                    etoroClient.registerUserActivity()
                    etoroClient.refreshWatchlists()
                    pageStack.push(Qt.resolvedUrl("WatchlistsPage.qml"))
                }
            }
            MenuItem {
                text: qsTr("History")
                enabled: etoroClient.hasCredentials && !etoroClient.busy
                onClicked: {
                    etoroClient.registerUserActivity()
                    pageStack.push(Qt.resolvedUrl("HistoryPage.qml"))
                }
            }
            MenuItem {
                text: qsTr("Settings")
                onClicked: {
                    etoroClient.registerUserActivity()
                    pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
                }
            }
            MenuItem {
                text: qsTr("About")
                onClicked: {
                    etoroClient.registerUserActivity()
                    pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
                }
            }
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingLarge

            Item {
                width: parent.width
                height: pageHeader.height + tradingModeLabel.height - Theme.paddingMedium

                PageHeader {
                    id: pageHeader
                    title: qsTr("Dashboard")
                    width: parent.width
                }

                Label {
                    id: tradingModeLabel
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin
                    anchors.top: pageHeader.bottom
                    anchors.topMargin: -Theme.paddingLarge
                    text: etoroClient.tradingEnabled
                           ? qsTr("Trading")
                           : qsTr("Read-only")
                    color: etoroClient.tradingEnabled ? Theme.highlightColor : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: etoroClient.tradingEnabled ? true : false
                    horizontalAlignment: Text.AlignRight
                    truncationMode: TruncationMode.Fade
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
                visible: etoroClient.hasCredentials && !etoroClient.busy && etoroClient.lastError.length === 0

                Column {
                    id: summaryCard
                    x: Theme.paddingLarge
                    y: Theme.paddingLarge
                    width: parent.width - 2 * Theme.paddingLarge
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Portfolio summary")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        text: etoroClient.hasCredentials && !etoroClient.locked
                              ? amountText(etoroClient.portfolioSummary.equity, 2)
                              : "—"
                        color: Theme.primaryColor
                        font.pixelSize: Theme.fontSizeExtraLarge
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width
                        text: etoroClient.hasCredentials && !etoroClient.locked
                              ? qsTr("Unrealized P/L: ") + amountText(etoroClient.portfolioSummary.totalNetProfit, 2)
                              : qsTr("Unrealized P/L: —")
                        color: Number(etoroClient.portfolioSummary.totalNetProfit || 0) >= 0
                               ? Theme.highlightColor : Theme.errorColor
                        font.pixelSize: Theme.fontSizeMedium
                        wrapMode: Text.Wrap
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Column {
                            width: (parent.width - Theme.paddingMedium) / 2
                            spacing: Theme.paddingSmall

                            Label {
                                width: parent.width
                                text: qsTr("Invested")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Label {
                                width: parent.width
                                text: amountText(etoroClient.portfolioSummary.invested, 2)
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeMedium
                                truncationMode: TruncationMode.Fade
                            }
                        }

                        Column {
                            width: (parent.width - Theme.paddingMedium) / 2
                            spacing: Theme.paddingSmall

                            Label {
                                width: parent.width
                                text: qsTr("Open positions")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Label {
                                width: parent.width
                                text: String(etoroClient.portfolioSummary.openPositionsCount || 0)
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeMedium
                                truncationMode: TruncationMode.Fade
                            }
                        }
                    }
                }
            }


            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: qsTr("Top positions")
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeMedium
                visible: etoroClient.topPositions.length > 0
            }

            Repeater {
                model: etoroClient.topPositions

                delegate: BackgroundItem {
                    width: parent ? parent.width : page.width
                    height: rowColumn.height + Theme.paddingMedium * 2

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
                        radius: Theme.paddingMedium
                        color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                        border.width: 1
                        border.color: Theme.rgba(Theme.highlightColor, 0.12)
                    }

                    Column {
                        id: rowColumn
                        x: Theme.horizontalPageMargin + Theme.paddingMedium
                        y: Theme.paddingMedium
                        width: parent.width - 2 * Theme.horizontalPageMargin - 2 * Theme.paddingMedium
                        spacing: Theme.paddingSmall

                        Row {
                            width: parent.width
                            spacing: Theme.paddingSmall

                                Item {
                                    id: logoSlot
                                    width: 50
                                    height: 50

                                    Image {
                                        id: logoImage
                                        anchors.centerIn: parent
                                        source: instrumentIcon50(modelData.instrumentId)
                                        width: 50
                                        height: 50
                                        fillMode: Image.PreserveAspectFit
                                    }
                                }

                            Label {
                                width: parent.width * 0.62 - logoSlot.width - Theme.paddingSmall
                                anchors.top: logoSlot.top
                                text: modelData.displayName || (qsTr("Instrument ") + modelData.instrumentId)
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeMedium * 0.85
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width * 0.38 - Theme.paddingMedium
                                anchors.verticalCenter: logoSlot.verticalCenter
                                text: amountText(modelData.netProfit, 2)
                                color: Number(modelData.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor
                                font.pixelSize: Theme.fontSizeMedium * 0.85
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }
                        }

                        Label {
                            width: parent.width
                            text: (modelData.symbol || ("#" + modelData.instrumentId))
                                  + "   •   "
                                  + qsTr("Invested: ") + amountText(modelData.invested, 2)
                                  + "   •   "
                                  + qsTr("Current: ") + amountText(modelData.currentRate, 4)
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall * 0.85
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            Button {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: etoroClient.openPositions.length > 4
                text: qsTr("View all positions")
                onClicked: {
                    etoroClient.registerUserActivity()
                    pageStack.push(Qt.resolvedUrl("PortfolioPage.qml"))
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: statusColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)
                visible: !etoroClient.hasCredentials || etoroClient.busy || etoroClient.lastError.length > 0

                Column {
                    id: statusColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        visible: !etoroClient.hasCredentials
                        text: qsTr("No API credentials saved yet. Open Settings and add your API key and user key.")
                        color: Theme.primaryColor
                        wrapMode: Text.Wrap
                    }

                    Item {
                        width: parent.width
                        height: etoroClient.busy ? loadingColumn.height : 0
                        visible: etoroClient.busy

                        Column {
                            id: loadingColumn
                            anchors.centerIn: parent
                            width: parent.width
                            spacing: Theme.paddingMedium

                            BusyIndicator {
                                anchors.horizontalCenter: parent.horizontalCenter
                                size: BusyIndicatorSize.Medium
                                running: etoroClient.busy
                                visible: etoroClient.busy
                            }

                            Label {
                                width: parent.width
                                text: qsTr("Loading portfolio…")
                                color: Theme.primaryColor
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        visible: etoroClient.lastError.length > 0
                        text: etoroClient.lastError
                        color: Theme.errorColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }
    }
}
