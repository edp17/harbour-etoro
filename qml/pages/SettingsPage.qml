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
import "../components"

Page {
    id: page

    property bool settingsUnlocked: !etoroClient.locked

    function syncCredentialFields() {
        apiKeyField.text = settingsUnlocked ? etoroClient.apiKey : ""
        userKeyField.text = settingsUnlocked ? etoroClient.userKey : ""
    }

    onSettingsUnlockedChanged: {
        if (settingsUnlocked)
            syncCredentialFields()
        else {
            apiKeyField.text = ""
            userKeyField.text = ""
        }
    }

    onStatusChanged: {
        if (status === PageStatus.Active)
            syncCredentialFields()
    }

    property bool pinConfirmOverlayVisible: false
    property string pinConfirmMode: ""   // "change" or "remove"
    property string localPinError: ""

    function openPinConfirmOverlay(mode) {
        pinConfirmMode = mode
        currentPinOverlayField.text = ""
        pinConfirmOverlayVisible = true
    }

    function closePinConfirmOverlay() {
        pinConfirmOverlayVisible = false
        pinConfirmMode = ""
        currentPinOverlayField.text = ""
    }

    function submitPinOverlayAction() {
        etoroClient.registerUserActivity()
        etoroClient.clearPinSettingsError()
        localPinError = ""

        if (pinConfirmMode === "change") {
            if (newPinField.text !== confirmPinField.text) {
                localPinError = qsTr("New PIN values do not match.")
                return
            }

            if (etoroClient.changePin(currentPinOverlayField.text, newPinField.text)) {
                newPinField.text = ""
                confirmPinField.text = ""
                closePinConfirmOverlay()
            }
            return
        }

        if (pinConfirmMode === "remove") {
            if (etoroClient.removePin(currentPinOverlayField.text)) {
                newPinField.text = ""
                confirmPinField.text = ""
                closePinConfirmOverlay()
            }
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: contentColumn.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                text: "Clear stored data"
                onClicked: {
                    etoroClient.registerUserActivity()
                    etoroClient.clearCredentials()
                    apiKeyField.text = ""
                    userKeyField.text = ""
                    newPinField.text = ""
                    confirmPinField.text = ""
                    localPinError = ""
                }
            }
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.paddingSmall

            PageHeader {
                title: "Settings"
            }

            SectionHeader {
                text: "API Access"
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: apiAccessColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: apiAccessColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("eToro API credentials")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Store your public API key and user key securely on this device. These are required to load your portfolio.")
                        wrapMode: Text.Wrap
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TextField {
                        id: apiKeyField
                        width: parent.width
                        label: qsTr("API key")
                        placeholderText: qsTr("Paste eToro API key")
                        text: ""
                        echoMode: TextInput.Password
                        onTextChanged: etoroClient.registerUserActivity()
                    }

                    TextField {
                        id: userKeyField
                        width: parent.width
                        label: qsTr("User key")
                        placeholderText: qsTr("Paste eToro user key")
                        text: ""
                        echoMode: TextInput.Password
                        onTextChanged: etoroClient.registerUserActivity()
                    }

                    Button {
                        width: parent.width
                        text: qsTr("Save credentials")
                        onClicked: {
                            etoroClient.registerUserActivity()
                            etoroClient.saveCredentials(apiKeyField.text, userKeyField.text)
                            syncCredentialFields()
                        }
                    }
                }
            }

            SectionHeader {
                text: "Security"
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: securityOverviewColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: securityOverviewColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Security overview")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("API credentials and the app PIN are stored securely on the device. Non-sensitive preferences such as lock timing are stored separately.")
                        wrapMode: Text.Wrap
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Lock on background: ")
                              + (etoroClient.lockOnBackground ? qsTr("On") : qsTr("Off"))
                              + "\n"
                              + qsTr("Inactivity auto-lock: ")
                              + (etoroClient.autoLockMinutes > 0
                                 ? etoroClient.autoLockMinutes + qsTr(" min")
                                 : qsTr("Off"))
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Version 0.5 is read-only. It can display account and market information, but it cannot place, modify or close trades. Trading actions are planned for a later version.")
                        color: Theme.secondaryColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: appPinColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: appPinColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("App PIN")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("An app PIN protects access to the app and is required to unlock it.")
                        wrapMode: Text.Wrap
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        visible: etoroClient.pinEnabled
                        text: qsTr("To change the app PIN, enter the current PIN first.")
                        wrapMode: Text.Wrap
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Item {
                        width: parent.width
                        height: newPinField.height

                        PasswordField {
                            id: newPinField
                            width: parent.width
                            label: qsTr("New PIN")
                            placeholderText: qsTr("Enter PIN")
                            inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText

                            onTextChanged: {
                                etoroClient.registerUserActivity()
                                etoroClient.clearPinSettingsError()
                                localPinError = ""
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: confirmPinField.height

                        PasswordField {
                            id: confirmPinField
                            width: parent.width
                            label: qsTr("Confirm PIN")
                            placeholderText: qsTr("Repeat PIN")
                            inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText

                            onTextChanged: {
                                etoroClient.registerUserActivity()
                                etoroClient.clearPinSettingsError()
                                localPinError = ""
                            }
                        }
                    }

                    Label {
                        width: parent.width
                        visible: localPinError.length > 0 || etoroClient.pinSettingsError.length > 0
                        text: localPinError.length > 0 ? localPinError : etoroClient.pinSettingsError
                        color: Theme.errorColor
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Button {
                        width: parent.width
                        text: etoroClient.pinEnabled ? qsTr("Change app PIN") : qsTr("Enable app PIN")

                        onClicked: {
                            etoroClient.registerUserActivity()
                            etoroClient.clearPinSettingsError()
                            localPinError = ""

                            if (newPinField.text !== confirmPinField.text) {
                                localPinError = qsTr("New PIN values do not match.")
                                return
                            }

                            if (newPinField.text.length === 0) {
                                localPinError = qsTr("PIN cannot be empty.")
                                return
                            }

                            if (etoroClient.pinEnabled) {
                                openPinConfirmOverlay("change")
                                return
                            }

                            if (etoroClient.setPin(newPinField.text)) {
                                newPinField.text = ""
                                confirmPinField.text = ""
                            }
                        }
                    }

                    Button {
                        width: parent.width
                        visible: etoroClient.pinEnabled
                        text: qsTr("Remove PIN")

                        onClicked: {
                            etoroClient.registerUserActivity()
                            etoroClient.clearPinSettingsError()
                            localPinError = ""
                            openPinConfirmOverlay("remove")
                        }
                    }
                }
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: appLockColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: appLockColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("App lock")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Control when the app should lock automatically.")
                        wrapMode: Text.Wrap
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TextSwitch {
                        width: parent.width
                        text: qsTr("Lock on background")
                        description: qsTr("Lock the app when it goes to background.")
                        checked: etoroClient.lockOnBackground
                        onCheckedChanged: {
                            etoroClient.setLockOnBackground(checked)
                            etoroClient.registerUserActivity()
                        }
                    }

                    ComboBox {
                        id: autoLockCombo
                        width: parent.width
                        label: qsTr("Auto-lock after inactivity")

                        menu: ContextMenu {
                            MenuItem { text: qsTr("Off") }
                            MenuItem { text: qsTr("1 minute") }
                            MenuItem { text: qsTr("2 minutes") }
                            MenuItem { text: qsTr("5 minutes") }
                            MenuItem { text: qsTr("10 minutes") }
                            MenuItem { text: qsTr("30 minutes") }
                        }

                        function indexForMinutes(minutes) {
                            if (minutes <= 0) return 0
                            if (minutes === 1) return 1
                            if (minutes === 2) return 2
                            if (minutes === 5) return 3
                            if (minutes === 10) return 4
                            return 5
                        }

                        function minutesForIndex(index) {
                            switch (index) {
                            case 0: return 0
                            case 1: return 1
                            case 2: return 2
                            case 3: return 5
                            case 4: return 10
                            default: return 30
                            }
                        }

                        currentIndex: indexForMinutes(etoroClient.autoLockMinutes)

                        onCurrentIndexChanged: {
                            etoroClient.setAutoLockMinutes(minutesForIndex(currentIndex))
                            etoroClient.registerUserActivity()
                        }
                    }
                }
            }

            SectionHeader {
                text: qsTr("Live quotes")
            }

            Rectangle {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                height: liveQuotesColumn.height + Theme.paddingMedium * 2
                radius: Theme.paddingMedium
                color: Theme.rgba(Theme.highlightBackgroundColor, 0.10)
                border.width: 1
                border.color: Theme.rgba(Theme.highlightColor, 0.18)

                Column {
                    id: liveQuotesColumn
                    x: Theme.paddingMedium
                    y: Theme.paddingMedium
                    width: parent.width - 2 * Theme.paddingMedium
                    spacing: Theme.paddingSmall

                    Label {
                        width: parent.width
                        text: qsTr("Quote refresh interval")
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Controls how often visible quote data should refresh. Lower intervals use more battery and network traffic.")
                        wrapMode: Text.Wrap
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Fast refresh intervals are best for single-instrument pages. Multi-instrument pages may use a safer minimum interval to reduce network traffic and avoid rate limiting.")
                        wrapMode: Text.Wrap
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    Label {
                        width: parent.width
                        visible: etoroClient.quoteRefreshCoolingDown
                        text: etoroClient.quoteRateLimitMessage
                        wrapMode: Text.Wrap
                        color: Theme.errorColor
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    ComboBox {
                        id: quoteRefreshCombo
                        width: parent.width
                        label: qsTr("Refresh interval")

                        menu: ContextMenu {
                            MenuItem { text: qsTr("Off") }
                            MenuItem { text: qsTr("1 second") }
                            MenuItem { text: qsTr("2 seconds") }
                            MenuItem { text: qsTr("5 seconds") }
                            MenuItem { text: qsTr("10 seconds") }
                            MenuItem { text: qsTr("20 seconds") }
                            MenuItem { text: qsTr("30 seconds") }
                            MenuItem { text: qsTr("60 seconds") }
                        }

                        function indexForSeconds(seconds) {
                            if (seconds <= 0) return 0
                            if (seconds === 1) return 1
                            if (seconds === 2) return 2
                            if (seconds === 5) return 3
                            if (seconds === 10) return 4
                            if (seconds === 20) return 5
                            if (seconds === 30) return 6
                            return 7
                        }

                        function secondsForIndex(index) {
                            switch (index) {
                            case 0: return 0
                            case 1: return 1
                            case 2: return 2
                            case 3: return 5
                            case 4: return 10
                            case 5: return 20
                            case 6: return 30
                            default: return 60
                            }
                        }

                        currentIndex: indexForSeconds(etoroClient.quoteRefreshIntervalSeconds)

                        onCurrentIndexChanged: {
                            etoroClient.setQuoteRefreshIntervalSeconds(secondsForIndex(currentIndex))
                            etoroClient.registerUserActivity()
                        }
                    }

                    Label {
                        width: parent.width
                        text: qsTr("Applies only while supported pages are open.")
                        wrapMode: Text.Wrap
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: pinConfirmOverlayVisible
        z: 5000

        Rectangle {
            anchors.fill: parent
            color: "#80000000"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: { }
        }

        Rectangle {
            width: parent.width - 2 * Theme.horizontalPageMargin
            anchors.centerIn: parent
            radius: Theme.paddingMedium
            color: Theme.highlightDimmerColor
            border.width: 2
            border.color: Theme.rgba(Theme.primaryColor, 0.65)
            height: confirmColumn.height + 2 * Theme.paddingLarge

            Column {
                id: confirmColumn
                x: Theme.paddingLarge
                y: Theme.paddingLarge
                width: parent.width - 2 * Theme.paddingLarge
                spacing: Theme.paddingMedium

                Label {
                    width: parent.width
                    text: pinConfirmMode === "remove" ? qsTr("Remove app PIN") : qsTr("Change app PIN")
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.primaryColor
                }

                Label {
                    width: parent.width
                    text: pinConfirmMode === "remove"
                          ? qsTr("Enter the current PIN to remove app protection.")
                          : qsTr("Enter the current PIN to confirm the PIN change.")
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Theme.secondaryColor
                }

                PasswordField {
                    id: currentPinOverlayField
                    width: parent.width
                    label: qsTr("Current PIN")
                    placeholderText: qsTr("Enter current PIN")
                    inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText

                    onTextChanged: {
                        etoroClient.registerUserActivity()
                        etoroClient.clearPinSettingsError()
                        localPinError = ""
                    }
                }

                Label {
                    width: parent.width
                    visible: etoroClient.pinSettingsError.length > 0
                    text: etoroClient.pinSettingsError
                    color: Theme.errorColor
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeSmall
                }

                Row {
                    width: parent.width
                    spacing: Theme.paddingMedium

                    Button {
                        width: (parent.width - Theme.paddingMedium) / 2
                        text: qsTr("Cancel")
                        onClicked: closePinConfirmOverlay()
                    }

                    Button {
                        width: (parent.width - Theme.paddingMedium) / 2
                        text: pinConfirmMode === "remove" ? qsTr("Remove") : qsTr("Confirm")
                        onClicked: submitPinOverlayAction()
                    }
                }
            }
        }
    }
}
