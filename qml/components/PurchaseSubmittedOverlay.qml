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
    visible: overlayVisible
    z: 9999

    property bool overlayVisible: false

    function orderIdText() {
        var order = etoroClient.lastOrderStatus || {}
        return String(order.orderId || order.OrderId || order.orderID || "")
    }

    function statusText() {
        if (etoroClient.orderStatusLoading)
            return qsTr("Checking order status…")

        var order = etoroClient.lastOrderStatus || {}
        var status = order.status
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

    function statusColor() {
        var status = (etoroClient.lastOrderStatus || {}).status
        if (status && typeof status === "object")
            status = status.name
        status = String(status || "").toLowerCase()
        if (status.indexOf("filled") >= 0)
            return Theme.highlightColor
        if (status.indexOf("reject") >= 0 || status.indexOf("fail") >= 0
                || status.indexOf("cancel") >= 0 || status.indexOf("expire") >= 0)
            return Theme.errorColor
        return Theme.primaryColor
    }

    function open() {
        overlayVisible = true
        etoroClient.registerUserActivity()
    }

    function close() {
        overlayVisible = false
        etoroClient.registerUserActivity()
    }

    Rectangle {
        anchors.fill: parent
        color: "#80000000"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            // swallow clicks
        }
    }

    Rectangle {
        width: parent.width - 2 * Theme.horizontalPageMargin
        anchors.centerIn: parent
        radius: Theme.paddingMedium
        color: Theme.highlightDimmerColor
        border.width: 2
        border.color: Theme.rgba(Theme.primaryColor, 0.65)
        height: submittedColumn.height + 2 * Theme.paddingLarge

        Column {
            id: submittedColumn
            x: Theme.paddingLarge
            y: Theme.paddingLarge
            width: parent.width - 2 * Theme.paddingLarge
            spacing: Theme.paddingMedium

            Label {
                width: parent.width
                text: qsTr("Purchase submitted")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeLarge
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                text: qsTr("The order was submitted successfully. It may take a moment before the new position appears in your portfolio.")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                visible: root.orderIdText().length > 0
                text: qsTr("Order ID: %1").arg(root.orderIdText())
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                text: qsTr("Status: %1").arg(root.statusText())
                color: root.statusColor()
                font.pixelSize: Theme.fontSizeMedium
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                visible: etoroClient.orderStatusError.length > 0
                text: etoroClient.orderStatusError
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Row {
                width: parent.width
                spacing: Theme.paddingMedium

                Button {
                    width: (parent.width - Theme.paddingMedium) / 2
                    text: qsTr("Close")

                    onClicked: {
                        root.close()
                    }
                }

                Button {
                    width: (parent.width - Theme.paddingMedium) / 2
                    text: qsTr("Refresh status")

                    onClicked: {
                        etoroClient.refreshLastOrderStatus()
                    }
                }
            }
        }
    }
}
