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
    z: 9998

    signal orderSubmitted()

    property bool overlayVisible: false

    property int instrumentId: 0
    property string symbol: ""
    property string displayName: ""
    property var unitPrice: 0

    property bool orderByAmount: true
    property string orderAmountText: ""
    property string orderUnitsText: ""
    property string orderLeverageText: "1"
    property string orderStopLossText: ""
    property string orderTakeProfitText: ""
    property bool orderSubmitAttempted: false
    property bool orderConfirmMode: false
    property string orderResultMessage: ""
    property bool orderResultIsError: false
    property bool orderCompleted: false

    property bool orderAmountValid: parseOrderNumber(orderAmountText) > 0
    property bool orderUnitsValid: parseOrderNumber(orderUnitsText) > 0
    property bool orderLeverageValid: parseOrderNumber(orderLeverageText) >= 1
    property bool orderFormValid: orderLeverageValid && (orderByAmount ? orderAmountValid : orderUnitsValid)

    function open() {
        orderSubmitAttempted = false
        orderConfirmMode = false
        overlayVisible = true
        orderResultMessage = ""
        orderResultIsError = false
        orderCompleted = false
        etoroClient.registerUserActivity()
    }

    function close() {
        overlayVisible = false
        orderConfirmMode = false
        orderResultMessage = ""
        orderResultIsError = false
        orderCompleted = false
        etoroClient.clearLastError()
        etoroClient.registerUserActivity()
    }

    function parseOrderNumber(text) {
        var s = String(text || "").replace(",", ".")
        var n = Number(s)
        return isNaN(n) ? 0 : n
    }

    function orderUnitPrice() {
        return parseOrderNumber(unitPrice)
    }

    function formatOrderNumber(value, decimals) {
        if (!isFinite(value) || value <= 0)
            return ""
        return Number(value).toFixed(decimals)
    }

    function convertAmountToUnits() {
        var price = orderUnitPrice()
        var amount = parseOrderNumber(orderAmountText)

        if (price > 0 && amount > 0)
            orderUnitsText = formatOrderNumber(amount / price, 6)
    }

    function convertUnitsToAmount() {
        var price = orderUnitPrice()
        var units = parseOrderNumber(orderUnitsText)

        if (price > 0 && units > 0)
            orderAmountText = formatOrderNumber(units * price, 2)
    }

    function confirmOrderAfterPin() {
        var ok = etoroClient.prepareMarketOrder({
            instrumentId: root.instrumentId,
            symbol: root.symbol,
            displayName: root.displayName,
            isBuy: true,
            byAmount: root.orderByAmount,
            amount: parseOrderNumber(root.orderAmountText),
            units: parseOrderNumber(root.orderUnitsText),
            leverage: parseOrderNumber(root.orderLeverageText),
            stopLoss: root.orderStopLossText,
            takeProfit: root.orderTakeProfitText,
            unitPrice: orderUnitPrice()
        })

        root.orderSubmitAttempted = true
        root.orderResultIsError = !ok
        root.orderCompleted = ok
        if (ok) {
            root.orderSubmitted()
            root.close()
        }
        root.orderResultMessage = ok
                ? qsTr("Order submitted. Refreshing portfolio…")
                : etoroClient.lastError

        if (!ok && root.orderResultMessage === "")
            root.orderResultMessage = qsTr("Order could not be prepared.")

        etoroClient.clearLastError()
        etoroClient.registerUserActivity()
    }

    Rectangle {
        anchors.fill: parent
        color: "#80000000"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            // swallow outside clicks
        }
    }

    Rectangle {
        id: orderPanel
        width: parent.width - 2 * Theme.horizontalPageMargin
        anchors.centerIn: parent
        radius: Theme.paddingMedium
        color: Theme.highlightDimmerColor
        border.width: 2
        border.color: Theme.rgba(Theme.primaryColor, 0.65)
        height: orderColumn.height + 2 * Theme.paddingLarge

        Column {
            id: orderColumn
            x: Theme.paddingLarge
            y: Theme.paddingLarge
            width: parent.width - 2 * Theme.paddingLarge
            spacing: Theme.paddingMedium

            Label {
                width: parent.width
                text: qsTr("Open position")
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.primaryColor
            }

            Label {
                width: parent.width
                text: (root.symbol !== "" ? root.symbol : ("#" + root.instrumentId))
                      + " • "
                      + (root.displayName !== "" ? root.displayName : qsTr("Instrument"))
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
            }

            Label {
                width: parent.width
                text: qsTr("Buy / long position")
                horizontalAlignment: Text.AlignHCenter
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Rectangle {
                width: parent.width
                height: unitPriceRow.height + Theme.paddingSmall * 2
                radius: Theme.paddingSmall
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.12)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Row {
                    id: unitPriceRow
                    x: Theme.paddingSmall
                    y: Theme.paddingSmall
                    width: parent.width - 2 * Theme.paddingSmall
                    spacing: Theme.paddingMedium

                    Label {
                        width: parent.width * 0.48
                        text: qsTr("Current buy price")
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        truncationMode: TruncationMode.Fade
                    }

                    PriceFlashValue {
                        width: parent.width * 0.52 - Theme.paddingMedium
                        rawValue: root.unitPrice
                        decimals: 4
                        textColor: Theme.highlightColor
                        fontSize: Theme.fontSizeSmall
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.paddingMedium
                visible: !root.orderConfirmMode

                Row {
                    width: parent.width
                    spacing: Theme.paddingMedium

                    Button {
                        width: (parent.width - Theme.paddingMedium) / 2
                        text: qsTr("By amount")
                        down: root.orderByAmount

                        onClicked: {
                            if (!root.orderByAmount)
                                root.convertUnitsToAmount()

                            root.orderByAmount = true
                            etoroClient.registerUserActivity()
                        }
                    }

                    Button {
                        width: (parent.width - Theme.paddingMedium) / 2
                        text: qsTr("By units")
                        down: !root.orderByAmount

                        onClicked: {
                            if (root.orderByAmount)
                                root.convertAmountToUnits()

                            root.orderByAmount = false
                            etoroClient.registerUserActivity()
                        }
                    }
                }

                TextField {
                    width: parent.width
                    visible: root.orderByAmount
                    label: qsTr("Amount")
                    placeholderText: qsTr("Amount to invest")
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    text: root.orderAmountText

                    onTextChanged: {
                        root.orderAmountText = text
                        etoroClient.registerUserActivity()
                    }
                }

                TextField {
                    width: parent.width
                    visible: !root.orderByAmount
                    label: qsTr("Units")
                    placeholderText: qsTr("Number of units to buy")
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    text: root.orderUnitsText

                    onTextChanged: {
                        root.orderUnitsText = text
                        etoroClient.registerUserActivity()
                    }
                }

                TextField {
                    width: parent.width
                    label: qsTr("Leverage")
                    placeholderText: qsTr("1")
                    inputMethodHints: Qt.ImhDigitsOnly
                    text: root.orderLeverageText

                    onTextChanged: {
                        root.orderLeverageText = text
                        etoroClient.registerUserActivity()
                    }
                }

                TextField {
                    width: parent.width
                    label: qsTr("Stop Loss")
                    placeholderText: qsTr("Optional stop loss price")
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    text: root.orderStopLossText

                    onTextChanged: {
                        root.orderStopLossText = text
                        etoroClient.registerUserActivity()
                    }
                }

                TextField {
                    width: parent.width
                    label: qsTr("Take Profit")
                    placeholderText: qsTr("Optional take profit price")
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    text: root.orderTakeProfitText

                    onTextChanged: {
                        root.orderTakeProfitText = text
                        etoroClient.registerUserActivity()
                    }
                }

                Label {
                    width: parent.width
                    text: qsTr("Orders are submitted only when live trading is enabled in Settings.")
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Column {
                width: parent.width
                spacing: Theme.paddingSmall
                visible: root.orderConfirmMode

                Label {
                    width: parent.width
                    text: qsTr("Review order")
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignHCenter
                }

                Label {
                    width: parent.width
                    text: qsTr("Please review carefully. The live price may change before submission.")
                    color: Theme.errorColor
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Label {
                    width: parent.width
                    text: qsTr("Direction: Buy / long")
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                Label {
                    width: parent.width
                    text: root.orderByAmount
                          ? qsTr("Amount: ") + root.orderAmountText
                          : qsTr("Units: ") + root.orderUnitsText
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                Label {
                    width: parent.width
                    text: qsTr("Leverage: ") + root.orderLeverageText
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                Label {
                    width: parent.width
                    text: qsTr("Stop Loss: ") + (root.orderStopLossText !== "" ? root.orderStopLossText : qsTr("Not set"))
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }

                Label {
                    width: parent.width
                    text: qsTr("Take Profit: ") + (root.orderTakeProfitText !== "" ? root.orderTakeProfitText : qsTr("Not set"))
                    color: Theme.primaryColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            Row {
                width: parent.width
                spacing: Theme.paddingMedium

                Button {
                    width: (parent.width - Theme.paddingMedium) / 2
                    text: root.orderCompleted
                          ? qsTr("Close")
                          : (root.orderConfirmMode ? qsTr("Back") : qsTr("Cancel"))

                    onClicked: {
                        if (root.orderConfirmMode)
                            root.orderConfirmMode = false
                        else
                            root.close()

                        etoroClient.registerUserActivity()
                    }
                }

                Button {
                    width: (parent.width - Theme.paddingMedium) / 2
                    text: root.orderCompleted
                          ? qsTr("Submitted")
                          : (root.orderConfirmMode ? qsTr("Confirm order") : qsTr("Review"))
                    enabled: root.orderFormValid && !root.orderCompleted

                    onClicked: {
                        if (!root.orderConfirmMode) {
                            root.orderConfirmMode = true
                            root.orderSubmitAttempted = false
                        } else {
                            root.confirmOrderAfterPin()
                        }

                        etoroClient.registerUserActivity()
                    }
                }
            }

            Label {
                width: parent.width
                visible: root.orderSubmitAttempted
                text: root.orderResultMessage
                color: root.orderResultIsError ? Theme.errorColor : Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
