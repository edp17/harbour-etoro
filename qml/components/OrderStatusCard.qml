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
    width: parent ? parent.width : Screen.width
    height: visible ? panel.height : 0
    visible: Object.keys(etoroClient.lastOrderStatus || {}).length > 0
             || etoroClient.orderStatusLoading
             || etoroClient.orderStatusError.length > 0

    function value(keys) {
        var order = etoroClient.lastOrderStatus || {}
        for (var i = 0; i < keys.length; ++i) {
            var value = order[keys[i]]
            if (value !== undefined && value !== null && String(value).length > 0)
                return String(value)
        }
        return ""
    }

    function statusText() {
        if (etoroClient.orderStatusLoading)
            return qsTr("Checking…")
        var status = (etoroClient.lastOrderStatus || {}).status
        if (status && typeof status === "object")
            status = status.name
        var raw = status ? String(status) : "Submitted"
        switch (raw.toLowerCase()) {
        case "filled": return qsTr("Filled")
        case "rejected": return qsTr("Rejected")
        case "cancelled":
        case "canceled": return qsTr("Cancelled")
        case "failed": return qsTr("Failed")
        case "expired": return qsTr("Expired")
        case "pending": return qsTr("Pending")
        default: return raw === "Submitted" ? qsTr("Submitted") : raw
        }
    }

    Rectangle {
        id: panel
        x: Theme.horizontalPageMargin
        width: root.width - 2 * x
        height: content.height + 2 * Theme.paddingMedium
        radius: Theme.paddingMedium
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
        border.width: 1
        border.color: Theme.rgba(Theme.highlightColor, 0.18)

        Column {
            id: content
            x: Theme.paddingMedium
            y: Theme.paddingMedium
            width: parent.width - 2 * Theme.paddingMedium
            spacing: Theme.paddingSmall

            Label {
                width: parent.width
                text: qsTr("Latest order")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Label {
                width: parent.width
                text: root.value(["orderId", "OrderId", "orderID"]).length > 0
                      ? qsTr("Status: %1 · Order %2").arg(root.statusText()).arg(root.value(["orderId", "OrderId", "orderID"]))
                      : qsTr("Status: %1").arg(root.statusText())
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeMedium
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                visible: etoroClient.orderStatusError.length > 0
                text: etoroClient.orderStatusError
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            Row {
                width: parent.width
                spacing: Theme.paddingMedium

                Button {
                    width: (parent.width - Theme.paddingMedium) / 2
                    text: qsTr("Refresh status")
                    enabled: !etoroClient.orderStatusLoading
                    onClicked: etoroClient.refreshLastOrderStatus()
                }

                Button {
                    width: (parent.width - Theme.paddingMedium) / 2
                    text: qsTr("Dismiss")
                    onClicked: etoroClient.clearLastOrderStatus()
                }
            }
        }
    }
}
