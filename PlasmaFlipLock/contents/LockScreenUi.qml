/*
    PlasmaFlipLock — flip-clock lock screen for KScreenLocker (Plasma 6 / Wayland)
    SPDX-License-Identifier: GPL-2.0-or-later

    LockScreenUi.qml
    ================
    Composition root of the PlasmaFlipLock UI:
      - full-screen blurred (GPU) wallpaper with dim + vignette
      - centred FlipClock, day name and date
      - status strip (battery + optional weather)
      - glass PasswordPanel at the bottom
      - ALL the authentication glue (`authenticator` context property)

    ── IMPORTANT: AUTHENTICATION IS ENTIRELY KDE'S ────────────────────────
    This file (and the whole package) does NOT touch PAM, kcheckpass or any
    authentication logic. It only:
        reads   the greeter-provided `authenticator` context object,
        calls   authenticator.respond(password)        (Plasma ≥ 6.4)
                [fallback: authenticator.tryUnlock(pw)  Plasma ≤ 6.3],
        reacts  to succeeded / failed / message signals.
    Quitting via Qt.quit() after `succeeded()` is the greeter's official
    unlock path (see kscreenlocker greeterapp.cpp).
    ────────────────────────────────────────────────────────────────────────

    Greeter-provided context properties used here:
        wallpaper   (QQuickItem)   lock-screen wallpaper rendered by the
                                   configured wallpaper plugin, parented to
                                   the view root, full size, z = -1000
        authenticator (QObject)    PAM conversation front-end
        config      (KConfigPropertyMap) settings from contents/lockscreen/
                                   config/main.xml + kscreenlockerrc
                                   "[Greeter][LnF]" overrides (optional)
        kscreenlocker_userName     display name of the session user
        kscreenlocker_userImage    avatar path (unused by this design)
*/

import QtQuick
import QtQuick.Effects                          // MultiEffect — GPU blur + shadows
// Caps-Lock indicator: same module the stock Plasma 6 lock screen uses
// (ships with plasma-workspace → always present where a lock screen runs).
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator

Item {
    id: uiRoot

    // Set from LockScreen.qml (which receives it from kscreenlocker_greet).
    property bool viewVisible: false

    // ======================================================================
    //  DESIGN TOKENS + CONFIG OVERRIDE
    // ======================================================================
    Theme { id: theme }

    FontLoader {
        id: flipFontLoader
        // Bundled Bebas Neue (SIL OFL). If the file is missing or Qt cannot
        // parse it, status stays != Ready and we fall back to Oswald/system.
        source: Qt.resolvedUrl("assets/fonts/BebasNeue-Regular.ttf")
    }

    readonly property string fallbackDigitFont: {
        // Prefer a condensed typeface if the user happens to have one.
        const candidates = ["Bebas Neue", "Oswald", "Barlow Condensed",
                            "Roboto Condensed", "Noto Sans"]
        let ok = []
        try { ok = Qt.fontFamilies() } catch (e) {}
        for (let i = 0; i < candidates.length; ++i)
            if (ok.indexOf(candidates[i]) !== -1)
                return candidates[i]
        return "Noto Sans"
    }

    // Resolve the digit font once the loader reports back.
    Binding {
        target: theme
        property: "digitFontFamily"
        value: flipFontLoader.status === FontLoader.Ready
               ? flipFontLoader.name : uiRoot.fallbackDigitFont
    }

    // Guarded accessor for kscreenlockerrc "[Greeter][LnF]" settings.
    // `config` is a greeter context property — it may be a plain *missing*
    // identifier when this file is opened outside kscreenlocker_greet,
    // hence the try/catch.
    function cfgValue(key, fallback) {
        try {
            if (typeof config !== "undefined" && config !== null) {
                const v = config[key]
                if (v !== undefined && v !== null)
                    return v
            }
        } catch (e) {}
        return fallback
    }

    // ======================================================================
    //  DERIVED GEOMETRY (reactive to screen size; 1920x1080 reference: u = 1)
    // ======================================================================
    readonly property real u: height / 1080.0
    readonly property int cardH: {
        const raw = height * theme.clockHeightFactor * theme.clockScale
        return Math.round(Math.max(Math.min(raw, height * 0.58), Math.min(200, height * 0.9)))
    }
    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software

    // ======================================================================
    //  BACKGROUND — wallpaper (sharp) + blurred copy + dim + vignette
    // ======================================================================
    // `wallpaper` is parented to the view root by the greeter (full size).
    // ShaderEffectSource snapshots it; MultiEffect does the gaussian blur
    // on the GPU. This is the greeter-side equivalent of the compositor's
    // blur-behind effect and looks identical on Wayland, where the lock
    // surfaces are the only thing on screen.
    readonly property var wallpaperItem: {
        try { return (typeof wallpaper !== "undefined") ? wallpaper : null }
        catch (e) { return null }
    }

    Item {
        id: backgroundLayer
        anchors.fill: parent

        // Fallback: rich dark gradient when no wallpaper plugin is active.
        Rectangle {
            anchors.fill: parent
            visible: uiRoot.wallpaperItem === null
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#1b1d24" }
                GradientStop { position: 0.55; color: "#111318" }
                GradientStop { position: 1.0; color: "#07080b" }
            }
        }

        // Snapshot of the greeter's wallpaper item. `live` only re-samples
        // when the texture actually changes (static image ⇒ zero churn).
        ShaderEffectSource {
            id: wallpaperSnapshot
            anchors.fill: parent
            sourceItem: uiRoot.wallpaperItem
            live: true
            hideSource: false            // the sharp wallpaper stays beneath
            visible: false               // only feeds the effect below
        }

        // GPU gaussian blur (greeter-side compositor-blur equivalent).
        MultiEffect {
            anchors.fill: parent
            visible: uiRoot.wallpaperItem !== null
                     && theme.blurWallpaper
                     && !uiRoot.softwareRendering
            source: wallpaperSnapshot
            blurEnabled: visible
            blur: 1.0                    // 1.0 × blurMax
            blurMax: 48                  // ~48 px blur radius at any resolution
            brightness: -0.04
            saturation: 1.02
        }

        // Dim layer so the clock and the glass panel pop on bright images.
        Rectangle {
            anchors.fill: parent
            color: theme.dimColor
        }

        // Subtle vignette: light edge darkening, premium cinema feel, static.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.30) }
                GradientStop { position: 0.18; color: "transparent" }
                GradientStop { position: 0.82; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.34) }
            }
            rotation: 0   // vertical gradient — top & bottom darkened
        }
    }

    // Any click that wasn't consumed by an interactive child lands back in
    // the password field — keeps typing frictionless.
    MouseArea {
        anchors.fill: parent
        z: 1
        onPressed: panel.focusPassword()
    }

    // ======================================================================
    //  CENTER STACK — clock, day, date, status strip
    // ======================================================================
    Column {
        id: centerStack
        z: 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        // Bias the stack slightly above true centre so the panel at the
        // bottom feels balanced instead of the clock dropping low.
        anchors.verticalCenterOffset: -Math.round(parent.height * 0.045)
        spacing: Math.round(parent.height * 0.026)

        // ---- the HH:MM flip clock (≈ 45 % of screen height) ---------------
        FlipClock {
            id: flipClock
            theme: theme
            cardHeight: uiRoot.cardH
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // ---- day + date (share one tick with the clock) --------------------
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Math.round(uiRoot.height * 0.007)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                // "Tuesday"
                text: Qt.formatDateTime(flipClock.currentTime, "dddd")
                color: theme.textPrimary
                opacity: 0.94
                font.family: theme.textFontFamily
                font.pixelSize: Math.round(uiRoot.height * theme.dayNameFactor)
                font.weight: Font.Medium
                font.letterSpacing: Math.round(uiRoot.height * 0.006)
                font.capitalization: Font.AllUppercase
                renderType: Text.NativeRendering
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                // "3 August 2026"
                text: Qt.formatDateTime(flipClock.currentTime, "d MMMM yyyy")
                color: theme.textSecondary
                font.family: theme.textFontFamily
                font.pixelSize: Math.round(uiRoot.height * theme.dateFactor)
                font.letterSpacing: 1
                renderType: Text.NativeRendering
            }
        }

        // ---- battery (+ optional weather) ------------------------------------
        BatteryWidget {
            id: statusStrip
            theme: theme
            pixelSize: Math.round(uiRoot.height * theme.statusFactor)
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ======================================================================
    //  STATUS LINE — caps-lock hint / notifications (right above the panel)
    // ======================================================================
    KeyboardIndicator.KeyState {
        id: capsLockState
        key: Qt.Key_CapsLock
    }
    readonly property bool capsLockOn: capsLockState.locked === true

    // notification plumbing ------------------------------------------------
    property string notification: ""
    property bool   notificationIsError: false
    signal notificationRepeated()

    function setStatus(msg, isError) {
        if (msg === undefined || msg === null || String(msg).trim().length === 0)
            return
        const text = String(msg).trim()
        if (uiRoot.notification === text) {
            uiRoot.notificationRepeated()
            return
        }
        uiRoot.notification = text
        uiRoot.notificationIsError = isError === true
        statusClearTimer.restart()
    }

    Timer {
        id: statusClearTimer
        interval: 3500
        onTriggered: uiRoot.notification = ""
    }

    Text {
        id: statusLine
        z: 3
        anchors {
            horizontalCenter: panel.horizontalCenter
            bottom: panel.top
            bottomMargin: Math.round(parent.height * 0.014)
        }
        width: Math.min(implicitWidth, parent.width * 0.7)
        elide: Text.ElideRight
        maximumLineCount: 1

        readonly property string capsHint: "Caps Lock is on"
        // priority: explicit notification → caps-lock hint
        text: uiRoot.notification.length > 0 ? uiRoot.notification
              : (uiRoot.capsLockOn ? capsHint : "")

        visible: opacity > 0
        opacity: text.length > 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        color: uiRoot.notificationIsError ? theme.danger : theme.textTertiary
        font.family: theme.textFontFamily
        font.pixelSize: Math.max(12, Math.round(uiRoot.height * 0.016))
        renderType: Text.NativeRendering
    }

    // ======================================================================
    //  PASSWORD PANEL
    // ======================================================================
    PasswordPanel {
        id: panel
        z: 3
        theme: theme
        shown: uiRoot.viewVisible

        // Pill width: 560 px at 1080p, ~400 px at 768p, never under 320 px
        // and never wider than 60 % of the screen.
        width: Math.round(Math.min(parent.width * 0.6, Math.max(320, 560 * uiRoot.u)))
        height: Math.round(Math.max(46, Math.min(theme.panelHeightPx * uiRoot.u, 86)))

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(parent.height * 0.085)

        onSubmitted: pw => uiRoot.submitPassword(pw)
    }

    // ======================================================================
    //  AUTHENTICATION GLUE — READ-ONLY W.R.T. KDE's AUTHENTICATOR
    //  (see header note: PAM logic is untouched; this is UI plumbing only)
    // ======================================================================
    // Keep a JS-side reference so `typeof authenticator` never throws even if
    // the identifier is missing (e.g. previewing outside the greeter).
    property var authObj: null
    property string pendingPassword: ""   // held while PAM rate-limits us

    // External clear request (LockScreen.qml's clearPassword signal).
    function resetExternal() {
        panel.reset()
    }

    function startAuth() {
        // Newer Plasma starts the PAM conversation explicitly so prompts
        // (including fingerprint on non-interactive backends) can arrive.
        if (authObj && typeof authObj.startAuthenticating === "function")
            authObj.startAuthenticating()
    }

    function submitPassword(pw) {
        if (!authObj || pw.length === 0)
            return
        // Plasma ≥ 6.6: PAM may be in a fail-delay window; stash and deliver
        // the pending response when pamTimeout clears.
        if (typeof authObj.pamTimeout !== "undefined" && authObj.pamTimeout) {
            uiRoot.pendingPassword = pw
            return
        }
        deliverPassword(pw)
    }

    function deliverPassword(pw) {
        if (typeof authObj.respond === "function")          // Plasma ≥ 6.4
            authObj.respond(pw)
        else if (typeof authObj.tryUnlock === "function")   // Plasma ≤ 6.3
            authObj.tryUnlock(pw)
    }

    Connections {
        target: authObj ? authObj : null

        // -- success: Qt.quit() is the greeter's official unlock path --
        function onSucceeded() {
            Qt.quit()
        }

        // -- failure --
        //   Plasma ≥ 6.4: failed(kind, authenticator) — kind 0 = password.
        //   Plasma ≤ 6.3: failed()                    — no arguments.
        //   Non-interactive kinds (fingerprint/smartcard) failing in the
        //   background must NOT clear the typed password or shake the panel.
        function onFailed(kind) {
            if (kind !== undefined && kind !== null && kind !== 0)
                return
            uiRoot.startAuth()                    // re-arm the PAM prompt
            panel.busy = false
            panel.reject()                        // short shake
            panel.reset()                         // clear + refocus
            uiRoot.setStatus("Unlocking failed", true)
        }

        // -- conversation messages (both API eras; the missing one just
        //    logs a one-line runtime note and stays inert) --
        function onBusyChanged() {
            try { panel.busy = authObj.busy === true } catch (e) {}
        }
        function onInfoMessageChanged() {
            try { uiRoot.setStatus(authObj.infoMessage, false) } catch (e) {}
        }
        function onErrorMessageChanged() {
            try { uiRoot.setStatus(authObj.errorMessage, true) } catch (e) {}
        }
        function onPromptChanged() {
            try { uiRoot.setStatus(authObj.prompt, false) } catch (e) {}
        }
        function onPromptForSecretChanged() {
            panel.focusPassword()                 // PAM asks for the secret
        }
        // Plasma ≤ 6.3 message signals (carry the text as an argument):
        function onInfoMessage(msg)  { uiRoot.setStatus(msg, false) }
        function onErrorMessage(msg) { uiRoot.setStatus(msg, true) }
        function onPrompt(msg)       { uiRoot.setStatus(msg, false) }
    }

    // ======================================================================
    //  START-UP: config overrides → auth arming → focus → entrance fade
    // ======================================================================
    opacity: 0

    SequentialAnimation {
        id: entranceFade
        PauseAnimation { duration: 60 }
        NumberAnimation {
            target: uiRoot
            property: "opacity"
            from: 0
            to: 1
            duration: theme.fadeInDuration
            easing.type: Easing.OutCubic
        }
    }

    onViewVisibleChanged: {
        if (viewVisible) {
            entranceFade.restart()
            panel.focusPassword()
        }
    }

    // Standalone preview helper: when NOT running inside the greeter nobody
    // sets viewVisible; reveal after a beat so the QML can be developed with
    // the `qml` tool too. Harmless in the greeter (viewVisible arrives first).
    Timer {
        interval: 1300
        running: true
        onTriggered: if (!uiRoot.viewVisible) uiRoot.viewVisible = true
    }

    Component.onCompleted: {
        // -- apply persisted settings (see config/main.xml) --
        theme.showBattery    = cfgValue("showBattery",    theme.showBattery)    === true
        theme.showWeather    = cfgValue("showWeather",    theme.showWeather)    === true
        theme.blurWallpaper  = cfgValue("blurWallpaper",  theme.blurWallpaper)  === true
        theme.weatherSource  = String(cfgValue("weatherSource", theme.weatherSource))
        const cs = Number(cfgValue("clockScale", theme.clockScale))
        if (isFinite(cs) && cs >= 0.6 && cs <= 1.4)
            theme.clockScale = cs

        // -- cache the authenticator reference safely --
        try { authObj = authenticator } catch (e) { authObj = null }

        // -- pamTimeout (Plasma ≥ 6.6) signal hookup, only if it exists --
        try {
            if (authObj && typeof authObj.pamTimeout !== "undefined") {
                authObj.pamTimeoutChanged.connect(function() {
                    if (!authObj.pamTimeout && uiRoot.pendingPassword.length > 0) {
                        const pw = uiRoot.pendingPassword
                        uiRoot.pendingPassword = ""
                        uiRoot.deliverPassword(pw)
                    }
                })
            }
        } catch (e) {}

        startAuth()
        panel.focusPassword()
    }
}
