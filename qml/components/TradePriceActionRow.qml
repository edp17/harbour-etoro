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

    property string sideText: ""
    property var rawValue: undefined
    property int decimals: 4
    property bool tradingEnabled: false
    property bool actionEnabled: tradingEnabled
    property color textColor: Theme.primaryColor
    property int fontSize: Theme.fontSizeSmall
    property real labelWidth: Theme.itemSizeExtraLarge

    signal clicked()

    width: parent ? parent.width : implicitWidth
    height: Math.max(actionButton.implicitHeight, sideLabel.implicitHeight, priceValue.implicitHeight)

    Label {
        id: sideLabel
        visible: !root.tradingEnabled
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.labelWidth
        text: root.sideText + ":"
        color: root.textColor
        font.pixelSize: root.fontSize
        truncationMode: TruncationMode.Fade
    }

    Button {
        id: actionButton
        visible: root.tradingEnabled
        enabled: root.actionEnabled
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.labelWidth
        text: root.sideText
        onClicked: root.clicked()
    }

    PriceFlashValue {
        id: priceValue
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        rawValue: root.rawValue
        decimals: root.decimals
        textColor: root.textColor
        fontSize: root.fontSize
    }
}
