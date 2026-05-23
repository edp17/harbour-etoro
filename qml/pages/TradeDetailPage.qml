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

    property var tradeData: ({ })

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

    function profitPercent() {
        var invested = Number(tradeData.investment || 0)
        var pnl = Number(tradeData.netProfit || 0)
        if (invested === 0)
            return 0
        return (pnl / invested) * 100.0
    }

    function netValue() {
        return Number(tradeData.investment || 0) + Number(tradeData.netProfit || 0)
    }

    function valueText(value, decimals) {
        if (value === undefined || value === null || value === "")
            return "—"
        return amountText(value, decimals)
    }

    function instrumentIcon50(instrumentId) {
        if (instrumentId === undefined || instrumentId === null || instrumentId === "")
            return ""

        return "https://etoro-cdn.etorostatic.com/market-avatars/"
                + String(instrumentId)
                + "/50x50.png"
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingLarge

            Item {
                width: parent.width
                height: pageHeader.height + tradeIdLabel.height - Theme.paddingMedium

                PageHeader {
                    id: pageHeader
                    title: qsTr("Trade (%1)").arg(etoroClient.accountModeLabel)
                    width: parent.width
                }

                Label {
                    id: tradeIdLabel
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.horizontalPageMargin
                    anchors.top: pageHeader.bottom
                    anchors.topMargin: -Theme.paddingLarge
                    text: qsTr("ID#") + String(page.tradeData.positionId || "—")
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeTiny
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

                Column {
                    id: summaryCard
                    x: Theme.paddingLarge
                    y: Theme.paddingLarge
                    width: parent.width - 2 * Theme.paddingLarge
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Summary")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Image {
                            id: logoImage
                            source: instrumentIcon50(page.tradeData.instrumentId)
                            width: 150
                            height: 150
                            fillMode: Image.PreserveAspectFit
                        }

                        Column {
                            width: parent.width - totalValueLabel.width - Theme.paddingMedium - logoImage.width
                            spacing: 2

                            Label {
                                width: parent.width
                                text: page.tradeData.symbol || ("#" + page.tradeData.instrumentId)
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeMedium
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: page.tradeData.displayName || (qsTr("Instrument ") + page.tradeData.instrumentId)
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                truncationMode: TruncationMode.Fade
                            }
                        }

                        Label {
                            id: totalValueLabel
                            width: parent.width * 0.34
                            text: amountText(netValue(), 2)
                            color: Number(page.tradeData.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor
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
                            text: qsTr("Closed")
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall * 0.9
                            font.bold: true
                            truncationMode: TruncationMode.Fade
                        }

                        Label {
                            width: parent.width * 0.66 - Theme.paddingMedium
                            text: dateText(page.tradeData.closeTimestamp)
                            color: Theme.highlightColor
                            font.pixelSize: Theme.fontSizeSmall * 0.9
                            horizontalAlignment: Text.AlignRight
                            truncationMode: TruncationMode.Fade
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Label {
                            width: parent.width * 0.34
                            text: qsTr("Profit/Loss (%)")
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Label {
                            width: parent.width * 0.66 - Theme.paddingMedium
                            text: amountText(profitPercent(), 1) + "%"
                            color: Number(page.tradeData.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor
                            font.pixelSize: Theme.fontSizeSmall
                            horizontalAlignment: Text.AlignRight
                            truncationMode: TruncationMode.Fade
                        }
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: detailsCard.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: detailsCard
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Details")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

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
                                    text: ""
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeTiny
                                }
                            }


                            Column {
                                width: parent.width
                                spacing: 2

                                Label {
                                    width: parent.width
                                    text: qsTr("Close price")
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeSmall
                                }

                                Label {
                                    width: parent.width
                                    text: ""
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeTiny
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
                                text: qsTr("Profit/Loss (P/L)")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }

                            Label {
                                width: parent.width
                                text: qsTr("Fees")
                                color: Theme.secondaryColor
                                font.pixelSize: Theme.fontSizeSmall
                            }
                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Theme.rgba(Theme.primaryColor, 0.5)
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
                                text: valueText(page.tradeData.units, 4)
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
                                    text: valueText(page.tradeData.openRate, 4)
                                    color: Theme.primaryColor
                                    font.pixelSize: Theme.fontSizeSmall
                                    horizontalAlignment: Text.AlignRight
                                    truncationMode: TruncationMode.Fade
                                }

                                Label {
                                    width: parent.width
                                    text: dateText(page.tradeData.openTimestamp)
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeTiny
                                    horizontalAlignment: Text.AlignRight
                                    truncationMode: TruncationMode.Fade
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 2

                                Label {
                                    width: parent.width
                                    text: valueText(page.tradeData.closeRate, 4)
                                    color: Theme.primaryColor
                                    font.pixelSize: Theme.fontSizeSmall
                                    horizontalAlignment: Text.AlignRight
                                    truncationMode: TruncationMode.Fade
                                }

                                Label {
                                    width: parent.width
                                    text: dateText(page.tradeData.closeTimestamp)
                                    color: Theme.secondaryColor
                                    font.pixelSize: Theme.fontSizeTiny
                                    horizontalAlignment: Text.AlignRight
                                    truncationMode: TruncationMode.Fade
                                }
                            }

                            Label {
                                width: parent.width
                                text: valueText(page.tradeData.investment, 2)
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: valueText(page.tradeData.netProfit, 2)
                                color: Number(page.tradeData.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }

                            Label {
                                width: parent.width
                                text: valueText(page.tradeData.fees, 2)
                                color: Theme.primaryColor
                                font.pixelSize: Theme.fontSizeSmall
                                horizontalAlignment: Text.AlignRight
                                truncationMode: TruncationMode.Fade
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Theme.rgba(Theme.primaryColor, 0.5)
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
