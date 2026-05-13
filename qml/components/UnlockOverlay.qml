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
    visible: etoroClient.locked
    z: 9999

    property string title: qsTr("Unlock app")
    property string message: qsTr("Enter your app PIN to continue.")
    property bool busy: false
    property string buttonText: qsTr("Unlock")

    Connections {
        target: etoroClient

        onLockedChanged: {
            if (!etoroClient.locked) {
                pinField.text = ""
                etoroClient.clearPinSettingsError()
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.highlightDimmerColor
        opacity: 0.98
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            // swallow clicks
        }
    }

    Rectangle {
        id: panel
        width: parent.width - 2 * Theme.horizontalPageMargin
        anchors.centerIn: parent
        radius: Theme.paddingMedium
        color: Theme.highlightDimmerColor
        border.width: 2
        border.color: Theme.rgba(Theme.primaryColor, 0.65)
        height: contentColumn.height + 2 * Theme.paddingLarge

        Column {
            id: contentColumn
            x: Theme.paddingLarge
            y: Theme.paddingLarge
            width: parent.width - 2 * Theme.paddingLarge
            spacing: Theme.paddingMedium

            Label {
                width: parent.width
                text: root.title
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.primaryColor
            }

            Label {
                width: parent.width
                text: root.message
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
            }

            PasswordField {
                id: pinField
                width: parent.width
                label: qsTr("PIN")
                placeholderText: qsTr("Enter PIN")
                inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText

                EnterKey.enabled: text.length > 0
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: unlockButton.clicked()

                onTextChanged: {
                    if (etoroClient.lastError.length > 0)
                        etoroClient.clearPinSettingsError()
                }
            }

            Label {
                width: parent.width
                visible: etoroClient.lastError.length > 0
                text: etoroClient.lastError
                color: Theme.errorColor
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeSmall
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: root.busy
                visible: running
                size: BusyIndicatorSize.Medium
            }

            Button {
                id: unlockButton
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.buttonText
                enabled: !root.busy && pinField.text.length > 0

                onClicked: {
                    if (etoroClient.unlockWithPin(pinField.text)) {
                        pinField.text = ""
                    }
                }
            }
        }
    }
}
