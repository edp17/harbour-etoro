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
    visible: etoroClient.successMessage.length > 0
    z: 9000

    Timer {
        id: dismissTimer
        interval: 3500
        repeat: false
        onTriggered: etoroClient.clearSuccessMessage()
    }

    Connections {
        target: etoroClient
        onSuccessMessageChanged: {
            if (etoroClient.successMessage.length > 0)
                dismissTimer.restart()
        }
    }

    Rectangle {
        id: banner
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: messageLabel.height + 2 * Theme.paddingMedium
        color: Theme.highlightBackgroundColor
        opacity: 0.96

        Label {
            id: messageLabel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.horizontalPageMargin
            anchors.rightMargin: Theme.horizontalPageMargin
            anchors.verticalCenter: parent.verticalCenter
            text: etoroClient.successMessage
            color: Theme.primaryColor
            font.pixelSize: Theme.fontSizeSmall
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        MouseArea {
            anchors.fill: parent
            onClicked: etoroClient.clearSuccessMessage()
        }
    }
}
