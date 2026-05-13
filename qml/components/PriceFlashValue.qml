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

    property var rawValue: undefined
    property int decimals: 4
    property color textColor: Theme.primaryColor
    property int fontSize: Theme.fontSizeSmall
    property bool ready: false
    property real previousValue: 0
    property string placeholderText: "---"
    property int horizontalPadding: Theme.paddingMedium
    property int verticalPadding: Theme.paddingSmall

    function hasValue(v) {
        return !(v === undefined || v === null || v === "")
    }

    function numericValue(v) {
        return hasValue(v) ? Number(v) : 0
    }

    function displayText() {
        if (!hasValue(rawValue))
            return placeholderText
        return Number(rawValue).toLocaleString(Qt.locale(), "f", decimals)
    }

    implicitWidth: valueLabel.implicitWidth + horizontalPadding * 3
    implicitHeight: valueLabel.implicitHeight + verticalPadding * 3

    onRawValueChanged: {
        if (!hasValue(rawValue))
            return

        var now = numericValue(rawValue)

        if (!ready) {
            previousValue = now
            ready = true
            return
        }

        if (now > previousValue) {
            flashRect.color = Theme.rgba(Theme.highlightColor, 0.76)
            flashAnim.restart()
        } else if (now < previousValue) {
            flashRect.color = Theme.rgba(Theme.errorColor, 0.76)
            flashAnim.restart()
        }

        previousValue = now
    }

    Rectangle {
        id: flashRect
        anchors.fill: parent
        radius: Theme.paddingSmall
        color: "transparent"
        opacity: 0.0
    }

    Label {
        id: valueLabel
        anchors.centerIn: parent
        text: root.displayText()
        color: root.textColor
        font.pixelSize: root.fontSize
        truncationMode: TruncationMode.Fade
    }

    SequentialAnimation {
        id: flashAnim

        NumberAnimation {
            target: flashRect
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 120
        }

        NumberAnimation {
            target: flashRect
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: 700
        }
    }
}
