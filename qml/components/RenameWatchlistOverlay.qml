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

Item {
    id: root

    anchors.fill: parent
    visible: false
    z: 10000

    property string watchlistId: ""
    property string watchlistName: ""

    property string renameText: ""
    property string errorText: ""

    signal renamed(string watchlistId)

    function open() {
        renameText = watchlistName
        errorText = ""
        visible = true
    }

    function close() {
        visible = false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.rgba("black", 0.65)
    }

    MouseArea {
        anchors.fill: parent

        onClicked: {
            if (!etoroClient.busy)
                root.close()
        }
    }

    Rectangle {
        width: parent.width - 2 * Theme.horizontalPageMargin
        x: Theme.horizontalPageMargin
        anchors.verticalCenter: parent.verticalCenter
        height: renameColumn.height + Theme.paddingLarge * 2

        radius: Theme.paddingMedium
        color: Theme.highlightDimmerColor

        border.width: 1
        border.color: Theme.rgba(Theme.highlightColor, 0.35)

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Column {
            id: renameColumn

            x: Theme.paddingLarge
            y: Theme.paddingLarge

            width: parent.width - 2 * Theme.paddingLarge
            spacing: Theme.paddingMedium

            Label {
                width: parent.width
                text: qsTr("Rename watchlist")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeMedium
                wrapMode: Text.Wrap
            }

            TextField {
                id: renameField

                width: parent.width

                label: qsTr("Watchlist name")
                placeholderText: qsTr("Name")

                text: root.renameText

                onTextChanged: root.renameText = text

                EnterKey.iconSource: "image://theme/icon-m-enter-accept"

                EnterKey.onClicked: {
                    renameButton.clicked()
                }
            }

            Label {
                width: parent.width
                visible: root.errorText !== ""

                text: root.errorText
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            Row {
                width: parent.width
                spacing: Theme.paddingMedium

                Button {
                    width: (parent.width - Theme.paddingMedium) / 2

                    text: qsTr("Cancel")
                    enabled: !etoroClient.busy

                    onClicked: root.close()
                }

                Button {
                    id: renameButton

                    width: (parent.width - Theme.paddingMedium) / 2

                    text: etoroClient.busy
                          ? qsTr("Renaming…")
                          : qsTr("Rename")

                    enabled: !etoroClient.busy

                    onClicked: {
                        root.errorText = ""

                        if (root.watchlistId === "") {
                            root.errorText = qsTr("Missing watchlist ID")
                            return
                        }

                        if (!etoroClient.renameWatchlist(root.watchlistId,
                                                         root.renameText)) {
                            root.errorText = etoroClient.lastError
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: etoroClient

        onWatchlistRenamed: {
            root.close()
            root.renamed(watchlistId)
        }

        onLastErrorChanged: {
            if (!root.visible)
                return

            if (etoroClient.lastError !== ""
                    && etoroClient.lastError !== "Watchlist renamed.") {
                root.errorText = etoroClient.lastError
            }
        }
    }
}
