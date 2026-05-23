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

CoverBackground {
    id: cover

    property bool readyForContent: !etoroClient.locked && etoroClient.hasCredentials

    function amountText(value, decimals) {
        return Number(value || 0).toLocaleString(Qt.locale(), 'f', decimals)
    }

    function instrumentIcon50(instrumentId) {
        if (instrumentId === undefined || instrumentId === null || instrumentId === "")
            return ""

        return "https://etoro-cdn.etorostatic.com/market-avatars/"
                + String(instrumentId)
                + "/50x50.png"
    }

    // Unlocked content
    Column {
        anchors.fill: parent
        anchors.margins: Theme.paddingMedium
        spacing: Theme.paddingSmall
        visible: cover.readyForContent
        enabled: visible

        Row {
            width: parent.width
            spacing: Theme.paddingSmall

            Image {
                source: "file:///usr/share/icons/hicolor/172x172/apps/harbour-etoro.png"
                width: Theme.iconSizeSmall
                height: Theme.iconSizeSmall
                fillMode: Image.PreserveAspectFit
            }

            Label {
                width: parent.width - Theme.iconSizeSmall - Theme.paddingSmall
                text: qsTr("eToro")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                truncationMode: TruncationMode.Fade
                verticalAlignment: Text.AlignVCenter
            }
        }

        Item {
            width: 1
            height: Theme.paddingMedium
        }

        Row {
            width: parent.width
            spacing: Theme.paddingSmall

            Label {
                width: parent.width * 0.38
                text: qsTr("Equity")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall * 0.9
                truncationMode: TruncationMode.Fade
            }

            Label {
                width: parent.width * 0.62 - Theme.paddingSmall
                text: amountText(etoroClient.portfolioSummary.equity, 2)
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                horizontalAlignment: Text.AlignRight
                truncationMode: TruncationMode.Fade
            }
        }

        Row {
            width: parent.width
            spacing: Theme.paddingSmall

            Label {
                width: parent.width * 0.38
                text: qsTr("Invested")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall * 0.9
                truncationMode: TruncationMode.Fade
            }

            Label {
                width: parent.width * 0.62 - Theme.paddingSmall
                text: amountText(etoroClient.portfolioSummary.invested, 2)
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                horizontalAlignment: Text.AlignRight
                truncationMode: TruncationMode.Fade
            }
        }

        Rectangle {
            width: parent.width
            height: summaryColumn.height + Theme.paddingMedium * 2
            radius: Theme.paddingSmall
            color: Theme.rgba(Theme.highlightBackgroundColor, 0.15)
            border.width: 2
            border.color: Theme.rgba(Theme.highlightColor, 0.8)

            Column {
                id: summaryColumn
                x: Theme.paddingMedium
                y: Theme.paddingMedium
                width: parent.width - Theme.paddingMedium * 2
                spacing: Theme.paddingSmall

                Label {
                    width: parent.width
                    text: qsTr("Unrealized P/L")
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    wrapMode: Text.Wrap
                }

                Label {
                    width: parent.width
                    text: amountText(etoroClient.portfolioSummary.totalNetProfit, 2)
                    color: Number(etoroClient.portfolioSummary.totalNetProfit || 0) >= 0
                           ? Theme.highlightColor
                           : Theme.primaryColor
                    font.pixelSize: Theme.fontSizeMedium
                    wrapMode: Text.NoWrap
                    truncationMode: TruncationMode.Fade
                }
            }
        }

        Item {
            width: 1
            height: Theme.paddingSmall / 2
        }

        Row {
            width: parent.width
            spacing: Theme.paddingSmall
            visible: etoroClient.topPositions.length > 0

            Repeater {
                model: Math.min(3, etoroClient.topPositions.length)

                delegate: Item {
                    width: (parent.width - Theme.paddingSmall * 2) / 3
                    height: 50

                    Rectangle {
                        anchors.centerIn: parent
                        width: 50
                        height: 50
                        radius: Theme.paddingSmall
                        color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                        border.width: 1
                        border.color: Theme.rgba(Theme.highlightColor, 0.18)

                        Image {
                            anchors.centerIn: parent
                            width: 40
                            height: 40
                            fillMode: Image.PreserveAspectFit
                            source: instrumentIcon50(etoroClient.topPositions[index].instrumentId)
                        }
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.paddingSmall / 2

            Label {
                width: parent.width
                text: qsTr("Positions: %1").arg(String(etoroClient.portfolioSummary.openPositionsCount || 0))
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeExtraSmall * 0.9
                truncationMode: TruncationMode.Fade
            }

            Item {
                width: 1
                height: Theme.paddingSmall / 2
            }

            Label {
                width: parent.width
                wrapMode: Text.Wrap
                visible: etoroClient.busy
                text: qsTr("Refreshing...")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall * 0.75
                maximumLineCount: 1
                truncationMode: TruncationMode.Fade
            }
        }
    }

    // No credentials
    Item {
        anchors.fill: parent
        visible: !etoroClient.locked && !etoroClient.hasCredentials
        enabled: visible

        Column {
            width: parent.width - Theme.paddingLarge * 2
            anchors.centerIn: parent
            spacing: Theme.paddingSmall

            Image {
                source: "file:///usr/share/icons/hicolor/172x172/apps/harbour-etoro.png"
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.iconSizeMedium
                height: Theme.iconSizeMedium
                fillMode: Image.PreserveAspectFit
            }

            Label {
                width: parent.width
                text: qsTr("eToro")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
            }

            Label {
                width: parent.width
                text: etoroClient.demoMode ? qsTr("Virtual mode") : qsTr("Real mode")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                horizontalAlignment: Text.AlignHCenter
            }

            Label {
                width: parent.width
                wrapMode: Text.Wrap
                text: qsTr("No API credentials")
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // Locked content
    Item {
        anchors.fill: parent
        visible: etoroClient.locked
        enabled: visible

        Column {
            width: parent.width - Theme.paddingLarge * 2
            anchors.centerIn: parent
            spacing: Theme.paddingSmall

            Image {
                source: "file:///usr/share/icons/hicolor/172x172/apps/harbour-etoro.png"
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.iconSizeMedium
                height: Theme.iconSizeMedium
                fillMode: Image.PreserveAspectFit
            }

            Label {
                width: parent.width
                text: qsTr("eToro")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
            }

            Item {
                width: 1
                height: Theme.paddingSmall / 2
            }

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                source: "image://theme/icon-m-device-lock"
                width: Theme.iconSizeMedium
                height: Theme.iconSizeMedium
                highlighted: true
            }

            Label {
                width: parent.width
                text: qsTr("App locked")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
            }

            Label {
                width: parent.width
                wrapMode: Text.Wrap
                text: qsTr("Open app to unlock")
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
