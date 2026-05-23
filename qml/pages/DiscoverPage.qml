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

    property int selectedTypeId: 0
    property var filteredResults: []

    function valueText(value, decimals) {
        if (decimals === undefined)
            decimals = 4

        if (value === undefined || value === null || value === "")
            return "—"

        return Number(value || 0).toLocaleString(Qt.locale(), "f", decimals)
    }

    function typeName(typeId) {
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

    function updateFilteredResults() {
        var out = []
        var rows = etoroClient.discoverResults || []

        for (var i = 0; i < rows.length; ++i) {
            var item = rows[i]
            var typeId = Number(item.instrumentTypeId || 0)

            if (page.selectedTypeId === 0 || typeId === page.selectedTypeId)
                out.push(item)
        }

        page.filteredResults = out
    }

    onStatusChanged: {
        if (status === PageStatus.Active)
            updateFilteredResults()
    }

    Connections {
        target: etoroClient

        onDiscoverResultsChanged: {
            page.updateFilteredResults()
        }
    }

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: page.filteredResults

        PullDownMenu {
            MenuItem {
                text: qsTr("Clear")
                onClicked: {
                    page.searchText = ""
                    searchField.text = ""
                    etoroClient.clearDiscoverResults()
                    page.updateFilteredResults()
                }
            }
        }

        header: Column {
            width: listView.width
            spacing: Theme.paddingMedium

            PageHeader {
                title: qsTr("Discover (%1)").arg(etoroClient.accountModeLabel)
            }

            ComboBox {
                id: typeCombo
                width: parent.width
                label: qsTr("Instrument type")
                currentIndex: 0

                menu: ContextMenu {
                    MenuItem { text: qsTr("All") }
                    MenuItem { text: qsTr("Stocks") }
                    MenuItem { text: qsTr("Crypto") }
                    MenuItem { text: qsTr("ETFs") }
                    MenuItem { text: qsTr("Indices") }
                    MenuItem { text: qsTr("Commodities") }
                    MenuItem { text: qsTr("Currencies") }
                }

                onCurrentIndexChanged: {
                    // ETF type id still unknown; leave it mapped to 0 for now.
                    if (currentIndex === 0)
                        page.selectedTypeId = 0
                    else if (currentIndex === 1)
                        page.selectedTypeId = 5
                    else if (currentIndex === 2)
                        page.selectedTypeId = 10
                    else if (currentIndex === 3)
                        page.selectedTypeId = 6
                    else if (currentIndex === 4)
                        page.selectedTypeId = 4
                    else if (currentIndex === 5)
                        page.selectedTypeId = 2
                    else if (currentIndex === 6)
                        page.selectedTypeId = 1

                    page.updateFilteredResults()
                }
            }

            SearchField {
                id: searchField
                width: parent.width
                placeholderText: qsTr("Search symbol or name")

                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: {
                    etoroClient.searchDiscoverInstruments(text)
                    focus = false
                }

                text: etoroClient.discoverSearchText

                onTextChanged: {
                    etoroClient.discoverSearchText = text
                    if (text.trim().length === 0) {
                        etoroClient.clearDiscoverResults()
                        page.updateFilteredResults()
                    }
                }
            }

            Button {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                text: etoroClient.discoverLoading ? qsTr("Searching…") : qsTr("Search")
                enabled: !etoroClient.discoverLoading && searchField.text.trim().length > 0
                onClicked: {
                    etoroClient.searchDiscoverInstruments(searchField.text)
                    searchField.focus = false
                }
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                visible: etoroClient.discoverLoading
                text: qsTr("Searching instruments…")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                visible: !etoroClient.discoverLoading
                         && searchField.text.trim().length > 0
                         && page.filteredResults.length === 0
                         && etoroClient.lastError === ""
                text: qsTr("No matching asset found.")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width - 2 * Theme.horizontalPageMargin
                x: Theme.horizontalPageMargin
                visible: etoroClient.lastError !== ""
                text: etoroClient.lastError
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }
        }

        delegate: BackgroundItem {
            width: listView.width
            height: Math.max(resultRow.height + Theme.paddingMedium * 2, Theme.itemSizeMedium)

            property var quote: {
                var trigger = etoroClient.discoverQuotes
                return etoroClient.quoteForDiscoverInstrument(modelData.instrumentId) || ({})
            }

            onClicked: {
                pageStack.push(Qt.resolvedUrl("WatchlistDetailPage.qml"), {
                    instrumentData: modelData
                })
            }

            Row {
                id: resultRow
                x: Theme.horizontalPageMargin
                y: Theme.paddingMedium
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingMedium

                Item {
                    id: logoSlot
                    width: Theme.iconSizeMedium
                    height: Theme.iconSizeMedium
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: modelData.logoUrl || ""
                        visible: source !== ""
                        fillMode: Image.PreserveAspectFit
                    }
                }

    Column {
        id: resultColumn
        width: parent.width - logoSlot.width - addButton.width - Theme.paddingMedium * 2
        spacing: Theme.paddingSmall

                    Row {
                        width: parent.width
                        spacing: Theme.paddingSmall

                        Label {
                            width: parent.width * 0.28
                            text: modelData.symbol || ("#" + modelData.instrumentId)
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeMedium
                            truncationMode: TruncationMode.Fade
                        }

                        Label {
                            width: parent.width - (parent.width * 0.28) - Theme.paddingSmall
                            text: modelData.displayName || ""
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeSmall
                            truncationMode: TruncationMode.Fade
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.paddingMedium

                        Label {
                            width: (parent.width - Theme.paddingMedium) / 2
                            text: qsTr("Sell: ") + valueText(quote.bid)
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                            truncationMode: TruncationMode.Fade
                        }

                        Label {
                            width: (parent.width - Theme.paddingMedium) / 2
                            text: qsTr("Buy: ") + valueText(quote.ask)
                            color: Theme.secondaryColor
                            font.pixelSize: Theme.fontSizeExtraSmall
                            truncationMode: TruncationMode.Fade
                        }
                    }

                    Label {
                        width: parent.width
                        text: qsTr("%1 • ID %2")
                                .arg(page.typeName(modelData.instrumentTypeId))
                                .arg(modelData.instrumentId)
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        truncationMode: TruncationMode.Fade
                    }
                }

                Item {
                    id: addButton
                    width: Theme.iconSizeMedium
                    height: Theme.iconSizeMedium
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.centerIn: parent
                        width: Theme.iconSizeMedium * 0.6
                        height: width
                        source: "image://theme/icon-m-new"
                        fillMode: Image.PreserveAspectFit
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            addToWatchlistOverlay.instrumentData = modelData
                            addToWatchlistOverlay.open()
                        }
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }

    // Add to Watchlist overlay
    AddToWatchlistOverlay {
        id: addToWatchlistOverlay
    }
}
