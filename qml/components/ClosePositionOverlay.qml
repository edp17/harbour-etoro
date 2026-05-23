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

    property var positionData: ({})
    property string symbol: ""
    property string displayName: ""
    property string currentValueText: ""

    property bool closeSubmitting: false
    property string closeErrorText: ""

    property bool partialClose: false
    property bool partialCloseByAmount: false
    property string partialUnitsText: ""
    property string partialAmountText: ""
    property real currentSellPrice: 0

    anchors.fill: parent
    z: 10000
    visible: false

    signal closeSubmitted()

    function valueText(value, decimals) {
        if (value === undefined || value === null || value === "")
            return "—"
        return Number(value || 0).toLocaleString(Qt.locale(), "f", decimals)
    }

    function minimumTradeSize() {
        var typeId = Number(root.positionData.instrumentTypeId || 0)

        switch (typeId) {
        case 5:     // Stocks
        case 6:     // EFTs
        case 10:    // Crypto
            return 10

        case 1:     // Currencies / Forex
        case 2:     // Commodities
        case 4:     // Indices
            return 1000

        default:
            return 1000
        }
    }

    function amountFromUnits(unitsText) {
        var units = Number(unitsText || 0)
        var totalValue = root.positionValue()
        var totalUnits = root.positionUnits()

        if (units <= 0 || totalValue <= 0 || totalUnits <= 0)
            return ""

        return root.valueText((units / totalUnits) * totalValue, 2)
    }

    function unitsFromAmount(amountText) {
        var amount = Number(amountText || 0)
        var totalValue = root.positionValue()
        var totalUnits = root.positionUnits()

        if (amount <= 0 || totalValue <= 0 || totalUnits <= 0)
            return ""

        return root.valueText((amount / totalValue) * totalUnits, 4)
    }

    function positionUnits() {
        return Number(root.positionData.units || 0)
    }

    function positionValue() {
        var value = Number(root.positionData.netValue || 0)
        if (value > 0)
            return value

        value = Number(root.positionData.currentValue || 0)
        if (value > 0)
            return value

        return Number(root.positionData.invested || 0)
    }

    function calculatedUnitsToClose() {
        if (!root.partialClose)
            return ""

        if (!root.partialCloseByAmount)
            return root.partialUnitsText

        var amount = Number(root.partialAmountText || 0)
        var totalValue = root.positionValue()
        var totalUnits = root.positionUnits()

        if (amount <= 0 || totalValue <= 0 || totalUnits <= 0)
            return ""

        return String((amount / totalValue) * totalUnits)
    }

    function validatePartialClose() {
        if (!root.partialClose)
            return true

        var totalValue = root.positionValue()
        var totalUnits = root.positionUnits()
        var minSize = root.minimumTradeSize()

        if (totalValue <= 0 || totalUnits <= 0) {
            root.closeErrorText = qsTr("Current position value is unavailable.")
            return false
        }

        var unitsToClose = Number(root.calculatedUnitsToClose() || 0)
        if (unitsToClose <= 0) {
            root.closeErrorText = root.partialCloseByAmount
                    ? qsTr("Enter a valid amount to close")
                    : qsTr("Enter a valid number of units to close")
            return false
        }

        if (unitsToClose >= totalUnits) {
            root.closeErrorText = qsTr("Use full close, or enter less than the current units.")
            return false
        }

        var closeValue = (unitsToClose / totalUnits) * totalValue
        var remainingValue = totalValue - closeValue

        if (closeValue < minSize) {
            root.closeErrorText = qsTr("The part you close must be at least %1.").arg(root.valueText(minSize, 2))
            return false
        }

        if (remainingValue < minSize) {
            root.closeErrorText = qsTr("The remaining position must be at least %1.").arg(root.valueText(minSize, 2))
            return false
        }

        return true
    }

    function closeValue() {
        if (!root.partialClose)
            return root.positionValue()

        var unitsToClose = Number(root.calculatedUnitsToClose() || 0)
        var totalUnits = root.positionUnits()
        var totalValue = root.positionValue()

        if (unitsToClose <= 0 || totalUnits <= 0 || totalValue <= 0)
            return 0

        return (unitsToClose / totalUnits) * totalValue
    }

    function remainingValue() {
        if (!root.partialClose)
            return 0

        return root.positionValue() - root.closeValue()
    }

    function counterpartText() {
        if (!root.partialClose)
            return ""

        if (root.partialCloseByAmount)
            return qsTr("Estimated units: %1").arg(root.unitsFromAmount(root.partialAmountText))

        return qsTr("Estimated amount: %1").arg(root.amountFromUnits(root.partialUnitsText))
    }

    function hasPositionData() {
        return positionData
                && positionData.positionId !== undefined
                && positionData.positionId !== null
                && String(positionData.positionId) !== ""
    }

    function open() {
        closeErrorText = ""
        closeSubmitting = false
        visible = true
        partialClose = false
        partialCloseSwitch.checked = false
        partialCloseByAmount = false
        partialUnitsText = ""
        partialAmountText = ""
    }

    function close() {
        if (!closeSubmitting)
            visible = false
    }

    function confirmClosePosition() {
        closeErrorText = ""

        if (!hasPositionData()) {
            closeErrorText = qsTr("Missing position data")
            return
        }

        if (!validatePartialClose())
            return

        closeSubmitting = true

        if (!etoroClient.closePosition(positionData, root.calculatedUnitsToClose())) {
            closeSubmitting = false
            closeErrorText = etoroClient.lastError || qsTr("Could not submit close request")
        }
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
        height: closePositionColumn.height + Theme.paddingLarge * 2
        radius: Theme.paddingMedium
        color: Theme.highlightDimmerColor
        border.width: 1
        border.color: Theme.rgba(Theme.highlightColor, 0.35)

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Column {
            id: closePositionColumn
            x: Theme.paddingLarge
            y: Theme.paddingLarge
            width: parent.width - 2 * Theme.paddingLarge
            spacing: Theme.paddingMedium

            Label {
                width: parent.width
                text: qsTr("Close position")
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeMedium
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                text: qsTr("This will close the whole position at the current market price.")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                text: root.symbol
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
                truncationMode: TruncationMode.Fade
            }

            Label {
                width: parent.width
                text: root.displayName
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                truncationMode: TruncationMode.Fade
            }

            Label {
                width: parent.width
                text: qsTr("Units: %1").arg(root.valueText(root.positionData.units, 4))
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Label {
                width: parent.width
                text: qsTr("Invested: %1").arg(root.valueText(root.positionData.invested, 2))
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Label {
                width: parent.width
                text: qsTr("Current value: %1").arg(root.currentValueText)
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Label {
                width: parent.width
                text: qsTr("P/L: %1").arg(root.valueText(root.positionData.netProfit, 2))
                color: Number(root.positionData.netProfit || 0) >= 0 ? Theme.highlightColor : Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Label {
                width: parent.width
                visible: root.closeErrorText !== ""
                text: root.closeErrorText
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }

            TextSwitch {
                id: partialCloseSwitch
                width: parent.width
                text: qsTr("Partial close")
                checked: root.partialClose
                onCheckedChanged: root.partialClose = checked
            }

            ComboBox {
                width: parent.width
                visible: root.partialClose
                label: qsTr("Close by")
                currentIndex: root.partialCloseByAmount ? 1 : 0

                menu: ContextMenu {
                    MenuItem { text: qsTr("Units") }
                    MenuItem { text: qsTr("Amount") }
                }

                onCurrentIndexChanged: {
                    var newByAmount = currentIndex === 1

                    if (newByAmount === root.partialCloseByAmount)
                        return

                    if (newByAmount) {
                        root.partialAmountText = root.amountFromUnits(root.partialUnitsText)
                    } else {
                        root.partialUnitsText = root.unitsFromAmount(root.partialAmountText)
                    }

                    root.partialCloseByAmount = newByAmount
                }
            }

            TextField {
                width: parent.width
                visible: root.partialClose && !root.partialCloseByAmount
                label: qsTr("Units to close")
                placeholderText: qsTr("Current: %1").arg(root.valueText(root.positionData.units, 4))
                text: root.partialUnitsText
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                onTextChanged: root.partialUnitsText = text
            }

            TextField {
                width: parent.width
                visible: root.partialClose && root.partialCloseByAmount
                label: qsTr("Amount to close")
                placeholderText: qsTr("Current value: %1").arg(root.currentValueText)
                text: root.partialAmountText
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                onTextChanged: root.partialAmountText = text
            }

            Label {
                width: parent.width
                visible: root.partialClose && root.counterpartText() !== ""
                text: root.counterpartText()
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                visible: root.partialClose
                text: qsTr("Closing value: %1").arg(root.valueText(root.closeValue(), 2))
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                visible: root.partialClose
                text: qsTr("Remaining value: %1").arg(root.valueText(root.remainingValue(), 2))
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                wrapMode: Text.Wrap
            }

            Label {
                width: parent.width
                visible: root.partialClose
                text: qsTr("Minimum check: the closed part and remaining part must both be at least %1.").arg(root.valueText(root.minimumTradeSize(), 2))
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                wrapMode: Text.Wrap
            }

            Row {
                width: parent.width
                spacing: Theme.paddingMedium

                Button {
                    width: (parent.width - Theme.paddingMedium) / 2
                    text: qsTr("Cancel")
                    enabled: !root.closeSubmitting
                    onClicked: {
                        root.close()
                        etoroClient.registerUserActivity()
                    }
                }

                Button {
                    width: (parent.width - Theme.paddingMedium) / 2
                    text: root.closeSubmitting
                          ? qsTr("Closing…")
                          : (root.partialClose ? qsTr("Close partially") : qsTr("Close all"))
                    enabled: !root.closeSubmitting && !etoroClient.busy
                    onClicked: {
                        root.confirmClosePosition()
                        etoroClient.registerUserActivity()
                    }
                }
            }
        }
    }

    Connections {
        target: etoroClient

        onPositionCloseSubmitted: {
            root.closeSubmitting = false
            root.visible = false
            root.closeSubmitted()
        }

        onBusyChanged: {
            if (root.closeSubmitting && !etoroClient.busy) {
                root.closeSubmitting = false

                if (etoroClient.lastError && etoroClient.lastError.length > 0) {
                    if (String(etoroClient.lastError).indexOf("Position close submitted") >= 0)
                    {
                        root.visible = false
                        root.closeSubmitted()
                    } else {
                        root.closeErrorText = etoroClient.lastError
                    }
                } else {
                    root.visible = false
                }
            }
        }
    }
}
