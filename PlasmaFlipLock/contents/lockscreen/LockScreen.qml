/*
    Fedlock Premium Flip — KDE Plasma 6.7 lock screen

    The visual tree is intentionally separate from authentication. The only
    password-related operation in this file is forwarding the field's text to
    the authenticator object supplied by kscreenlocker.

    Created by Muhammed Salman (CC).
*/
import QtQml
import QtQuick

Item {
    id: root

    // Properties/signals used by kscreenlocker_greet. Keep these names aligned
    // with Plasma 6's stock LockScreen.qml.
    property bool debug: false
    property bool viewVisible: false
    property bool locked: false
    property string notification: ""
    signal clearPassword()
    signal notificationRepeated()

    implicitWidth: 800
    implicitHeight: 600

    LayoutMirroring.enabled: Application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    Theme { id: designTheme }

    readonly property int cardHeight: Math.max(190, Math.round(Math.min(height * 0.34, width * 0.23)))
    readonly property bool passwordBusy: authenticator.busy === true || graceLockTimer.running
    property bool passwordlessReady: false

    AmbientBackground {
        anchors.fill: parent
        theme: designTheme
        pauseAfterMs: designTheme.ambientPauseAfterMs
        tickMs: designTheme.ambientTickMs
        animate: true
    }

    // This click target is behind the panel and keeps the greeter field ready
    // without changing how kscreenlocker authenticates.
    MouseArea {
        anchors.fill: parent
        z: 1
        onPressed: passwordField.forceFocus()
    }

    Column {
        id: centerContent
        z: 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -Math.round(parent.height * 0.045)
        spacing: Math.max(12, Math.round(parent.height * 0.020))

        FlipClock {
            id: clock
            theme: designTheme
            cardHeight: root.cardHeight
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.max(4, Math.round(parent.height * 0.006))

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.currentTime, "dddd", Qt.locale("en_US")).toUpperCase()
                color: designTheme.primaryText
                font.family: "DejaVu Sans"
                font.pixelSize: Math.max(17, Math.round(root.height * 0.030))
                font.weight: Font.Bold
                font.letterSpacing: Math.max(2, Math.round(root.height * 0.006))
                renderType: Text.NativeRendering
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.currentTime, "d MMMM yyyy", Qt.locale("en_US"))
                color: designTheme.secondaryText
                font.family: "DejaVu Sans"
                font.pixelSize: Math.max(15, Math.round(root.height * 0.021))
                renderType: Text.NativeRendering
            }
        }

        BatteryStatus {
            id: batteryStatus
            theme: designTheme
            pixelSize: Math.max(12, Math.round(root.height * 0.018))
            height: implicitHeight
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Text {
        id: statusText
        z: 3
        anchors.horizontalCenter: passwordField.horizontalCenter
        anchors.bottom: passwordField.top
        anchors.bottomMargin: Math.max(9, Math.round(root.height * 0.012))
        width: Math.min(implicitWidth, root.width * 0.75)
        text: root.notification
        color: root.notificationError ? designTheme.warning : designTheme.mutedText
        font.family: "DejaVu Sans"
        font.pixelSize: Math.max(12, Math.round(root.height * 0.016))
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        visible: text.length > 0
        renderType: Text.NativeRendering
    }

    PasswordField {
        id: passwordField
        z: 4
        visible: !root.passwordlessReady
        theme: designTheme
        width: Math.min(root.width * 0.52, Math.max(330, root.height * 0.52))
        height: Math.max(54, Math.min(78, root.height * 0.074))
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(38, Math.round(root.height * 0.085))
        busy: root.passwordBusy
        onSubmitted: password => {
            // Presentation only: PAM/kscreenlocker remains the verifier.
            authenticator.respond(password)
        }
    }

    // Same passwordless branch as the stock Plasma lockscreen: this becomes
    // available only after authenticator.succeeded() reports no password
    // prompt. It never decides whether authentication succeeded.
    Rectangle {
        id: passwordlessPanel
        z: 4
        visible: root.passwordlessReady
        width: passwordField.width
        height: passwordField.height
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: passwordField.bottom
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.16)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.30)
        focus: visible
        Keys.onEnterPressed: Qt.quit()
        Keys.onReturnPressed: Qt.quit()

        Text {
            anchors.centerIn: parent
            text: "Unlock"
            color: designTheme.primaryText
            font.family: "DejaVu Sans"
            font.pixelSize: Math.max(14, Math.round(parent.height * 0.25))
            font.weight: Font.Medium
            renderType: Text.NativeRendering
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.quit()
        }
    }

    property bool notificationError: false

    function showMessage(message, error) {
        if (message === undefined || message === null)
            return
        const clean = String(message).trim()
        if (clean.length === 0)
            return
        if (root.notification === clean) {
            root.notificationRepeated()
            return
        }
        root.notification = clean
        root.notificationError = error === true
        notificationTimer.restart()
    }

    Timer {
        id: notificationTimer
        interval: 3500
        repeat: false
        onTriggered: {
            root.notification = ""
            root.notificationError = false
        }
    }

    // Match Plasma 6's stock grace period. It prevents us from submitting
    // another response while PAM is deliberately delaying a failed attempt.
    Timer {
        id: graceLockTimer
        interval: 3000
        repeat: false
        onTriggered: {
            root.clearPassword()
            authenticator.startAuthenticating()
            passwordField.forceFocus()
        }
    }

    // These are the current Plasma 6.7 hooks. No PAM or password-verification
    // code is implemented here.
    Connections {
        target: authenticator

        function onFailed(kind) {
            if (kind != 0) { // noninteractive fingerprint/smart-card result
                return
            }
            root.showMessage("Unlocking failed", true)
            passwordField.reject()
            graceLockTimer.restart()
        }

        function onSucceeded() {
            if (authenticator.hadPrompt) {
                Qt.quit()
            } else {
                // Match stock NoPasswordUnlock.qml: the backend has already
                // succeeded; the user still explicitly activates the unlock
                // action before the greeter quits.
                root.passwordlessReady = true
                passwordlessPanel.forceActiveFocus()
            }
        }

        function onInfoMessageChanged() {
            root.showMessage(authenticator.infoMessage, false)
        }

        function onErrorMessageChanged() {
            root.showMessage(authenticator.errorMessage, true)
        }

        function onPromptChanged(message) {
            root.showMessage(authenticator.prompt, false)
        }

        function onPromptForSecretChanged(message) {
            passwordField.forceFocus()
        }
    }

    // kscreenlocker_greet sets viewVisible after the first frame. Starting the
    // backend here mirrors the stock theme and avoids authenticating too early.
    onViewVisibleChanged: {
        if (viewVisible) {
            authenticator.startAuthenticating()
            passwordField.forceFocus()
        }
    }

    onClearPassword: passwordField.clearPassword()
}
