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
    z: 10000
    visible: false

    property string fromDateText: ""
    property string toDateText: ""

    function open() {
        root.fromDateText = etoroClient.historyCustomFromDate
        root.toDateText = etoroClient.historyCustomToDate
        root.visible = true
    }

    function close() {
        root.visible = false
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.rgba("black", 0.65)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        width: parent.width - 2 * Theme.horizontalPageMargin
        x: Theme.horizontalPageMargin
        anchors.verticalCenter: parent.verticalCenter
        height: customRangeColumn.height + Theme.paddingLarge * 2
        radius: Theme.paddingMedium
        color: Theme.highlightDimmerColor
        border.width: 1
        border.color: Theme.rgba(Theme.highlightColor, 0.35)

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Column {
            id: customRangeColumn
            x: Theme.paddingLarge
            y: Theme.paddingLarge
            width: parent.width - 2 * Theme.paddingLarge
            spacing: Theme.paddingMedium

            Label {
                width: parent.width
                text: qsTr("Custom history range")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeMedium
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                text: qsTr("Enter the start date in YYYY-MM-DD format.")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            TextField {
                width: parent.width
                label: qsTr("From date")
                placeholderText: qsTr("2026-04-18")
                text: root.fromDateText
                inputMethodHints: Qt.ImhDate
                onTextChanged: root.fromDateText = text
            }

            TextField {
                width: parent.width
                label: qsTr("To date")
                placeholderText: qsTr("Optional, YYYY-MM-DD")
                text: root.toDateText
                inputMethodHints: Qt.ImhDate
                onTextChanged: root.toDateText = text
            }

            Row {
                width: parent.width
                spacing: Theme.paddingMedium

                Button {
                    width: (parent.width - Theme.paddingMedium) / 2
                    text: qsTr("Clear")
                    enabled: !etoroClient.busy
                    onClicked: {
                        root.close()
                        etoroClient.clearHistoryCustomRange()
                    }
                }

                Button {
                    width: (parent.width - Theme.paddingMedium) / 2
                    text: qsTr("Apply")
                    enabled: !etoroClient.busy
                    onClicked: {
                        etoroClient.setHistoryCustomFromDate(root.fromDateText)
                        etoroClient.setHistoryCustomToDate(root.toDateText)
                        etoroClient.applyHistoryCustomRange()
                        root.close()
                    }
                }
            }
        }
    }
}
