/*
    PlasmaFlipLock — flip-clock lock screen for KScreenLocker (Plasma 6 / Wayland)
    SPDX-License-Identifier: GPL-2.0-or-later

    PasswordPanel.qml
    =================
    The glassmorphism password field at the bottom of the screen with the
    login button integrated on its right edge.

    Glassmorphism recipe (GPU-cheap, HD 620 safe):
      1. The wallpaper underneath is ALREADY gaussian-blurred fullscreen
         (see LockScreenUi.qml), so a translucent white fill on top reads as
         frosted glass — no second per-pixel backdrop blur needed.
      2. A 1 px translucent-white rim + a hairline top gloss sell the glass.
      3. A soft static drop shadow (MultiEffect, rendered once) lifts it off
         the background.

    Behaviour:
      - fades + slides in shortly after the screen appears (given `shown`)
      - grabs keyboard focus automatically (`focusPassword()`)
      - Enter/Return or the arrow button submits `submitted(password)`
      - `reject()` plays a short, restrained horizontal shake
      - the typed text is mirrored through the PasswordSync singleton so all
        screens of a multi-monitor setup stay in sync (same trick as the
        stock lock screen) — the greeter gives every screen its own view but
        only the view under the pointer receives keyboard focus
*/

import QtQuick
import QtQuick.Effects   // MultiEffect (static shadow only)

Item {
    id: panel

    // ---- public API ------------------------------------------------------
    required property Theme theme
    property alias password: field.text     // current text (echo-only, harmless)
    property bool  busy: false              // true while PAM is thinking
    property bool  shown: false             // master fade-in switch (viewVisible)

    implicitWidth:  480
    implicitHeight: 62

    signal submitted(string password)

    // ======================================================================
    //  Public helpers used by LockScreenUi
    // ======================================================================
    function focusPassword() {
        if (!panel.busy)
            field.forceActiveFocus()
    }

    // Clears the field AND re-establishes the singleton binding (direct text
    // assignment breaks the binding, exactly like the stock lock screen does)
    function reset() {
        field.text = ""
        field.text = Qt.binding(function() { return PasswordSync.password })
        panel.busy = false
        focusPassword()
    }

    function reject() {
        shakeAnim.restart()
    }

    function submit() {
        if (field.text.length === 0 || panel.busy)
            return
        panel.busy = true                    // dim until the answer comes back
        panel.submitted(field.text)
    }

    // ======================================================================
    //  Entrance animation — gentle rise + fade, triggered by `shown`
    //  ("smooth fade-in animation", "no unnecessary animations": this is
    //  the only decorative animation besides the clock flip)
    // ======================================================================
    opacity: 0
    transform: Translate { id: panelSlide; y: Math.round(panel.theme.panelHeightPx / 2.5) }

    SequentialAnimation {
        id: entranceAnim
        PauseAnimation { duration: panel.theme.panelFadeDelay }
        ParallelAnimation {
            NumberAnimation {
                target: panel
                property: "opacity"
                from: 0; to: 1
                duration: panel.theme.panelFadeDuration
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: panelSlide
                property: "y"
                to: 0
                duration: panel.theme.panelFadeDuration
                easing.type: Easing.OutCubic
            }
        }
    }
    onShownChanged: if (shown) entranceAnim.restart()
    Component.onCompleted: if (shown) entranceAnim.restart()

    // ======================================================================
    //  Failed-attempt shake — 3 quick taps, eased. Discrete and informative.
    // ======================================================================
    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: panel; property: "x"; to: -12;
            duration: panel.theme.rejectShakeDuration / 4.0; easing.type: Easing.InQuad }
        NumberAnimation { target: panel; property: "x"; to: 12;
            duration: panel.theme.rejectShakeDuration / 2.0; easing.type: Easing.InOutQuad }
        NumberAnimation { target: panel; property: "x"; to: -6;
            duration: panel.theme.rejectShakeDuration / 4.0 / 2.0; easing.type: Easing.InOutQuad }
        NumberAnimation { target: panel; property: "x"; to: 0;
            duration: panel.theme.rejectShakeDuration / 4.0 / 2.0; easing.type: Easing.OutQuad }
    }

    // ======================================================================
    //  SHADOW — static rounded plate blurred once by MultiEffect
    // ======================================================================
    Rectangle {
        id: panelShadowPlate
        anchors.fill: panelBody
        radius: panelBody.radius
        color: "#000000"
        visible: false
    }
    MultiEffect {
        x: panelBody.x - 24
        y: panelBody.y - 24
        width:  panelBody.width  + 48
        height: panelBody.height + 48
        source: panelShadowPlate
        shadowEnabled: true
        shadowColor: "#8a000000"
        shadowBlur: 1.0
        blurMax: 24
        shadowVerticalOffset: 8
        opacity: panel.busy ? 0.6 : 1.0     // subtle dim while authenticating
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    // ======================================================================
    //  GLASS BODY
    // ======================================================================
    Rectangle {
        id: panelBody
        anchors.fill: parent
        radius: height * panel.theme.panelRadiusFactor        // perfect pill
        color: Qt.rgba(1, 1, 1, panel.busy ? panel.theme.glassOpacity * 0.7
                                           : panel.theme.glassOpacity)
        border.color: Qt.rgba(1, 1, 1, panel.theme.glassBorderOpacity)
        border.width: 1
        antialiasing: true

        Behavior on color { ColorAnimation { duration: 200 } }

        // Hairline gloss along the top edge — the classic glass cue.
        Rectangle {
            anchors {
                top: parent.top
                topMargin: 1
                left: parent.left
                right: parent.right
                leftMargin: parent.radius * 0.8
                rightMargin: parent.radius * 0.8
            }
            height: 1
            color: "transparent"
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.34) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // ======================= content row ==============================
        Row {
            id: contentRow
            anchors {
                fill: parent
                leftMargin: Math.round(panelBody.height * 0.34)
                rightMargin: Math.round(panelBody.height * 0.16)
            }
            spacing: Math.round(panelBody.height * 0.22)

            // ---- lock glyph (vector-drawn padlock, tinted to theme) --------
            Item {
                id: lockGlyph
                width: Math.round(panelBody.height * 0.34)
                height: width
                anchors.verticalCenter: parent.verticalCenter
                opacity: 0.75

                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const w = width, h = height
                        ctx.strokeStyle = "rgba(255,255,255,0.92)"
                        ctx.lineWidth = Math.max(1.4, w * 0.09)
                        ctx.lineCap = "round"
                        // shackle
                        ctx.beginPath()
                        ctx.arc(w * 0.5, h * 0.40, w * 0.22, Math.PI, 0, false)
                        ctx.stroke()
                        // body (rounded rect)
                        ctx.fillStyle = "rgba(255,255,255,0.92)"
                        const bx = w * 0.16, by = h * 0.42, bw = w * 0.68, bh = h * 0.46
                        const r = w * 0.10
                        roundedRectPath(ctx, bx, by, bw, bh, r)
                        ctx.fill()
                    }
                    function roundedRectPath(ctx, x, y, w, h, r) {
                        ctx.beginPath()
                        ctx.moveTo(x + r, y)
                        ctx.arcTo(x + w, y,     x + w, y + h, r)
                        ctx.arcTo(x + w, y + h, x,     y + h, r)
                        ctx.arcTo(x,     y + h, x,     y,     r)
                        ctx.arcTo(x,     y,     x + w, y,     r)
                        ctx.closePath()
                    }
                }
            }

            // ---- password input ---------------------------------------------
            Item {
                id: fieldWrap
                height: parent.height
                width: contentRow.width - lockGlyph.width - goButton.width
                       - contentRow.spacing * 2

                TextInput {
                    id: field
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                        right: parent.right
                    }
                    height: Math.round(parent.height * 0.72)

                    // Text is mirrored across all lock-screen views.
                    text: PasswordSync.password

                    color: panel.theme.textPrimary
                    selectionColor: Qt.rgba(1, 1, 1, 0.35)
                    selectedTextColor: "#101014"
                    font.family: panel.theme.textFontFamily
                    // clamp so a 0-height panel during the first layout pass
                    // never produces a 0 px font (Qt would warn)
                    font.pixelSize: Math.max(12, Math.round(panelBody.height * 0.34))
                    renderType: Text.NativeRendering

                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    passwordMaskDelay: -1        // always masked (default anyway)
                    inputMethodHints: Qt.ImhHiddenText | Qt.ImhNoAutoUppercase
                                      | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                    maximumLength: 512
                    clip: true
                    selectByMouse: false         // lock screen: no drag-select
                    cursorVisible: activeFocus

                    Keys.onReturnPressed: panel.submit()
                    Keys.onEnterPressed: panel.submit()
                    Keys.onEscapePressed: {
                        field.text = ""
                        PasswordSync.password = ""
                    }

                    // Two-way mirror into the shared singleton (typed text is
                    // pushed out; other views' text is pulled in via `text:`)
                    Binding {
                        target: PasswordSync
                        property: "password"
                        value: field.text
                        when: field.activeFocus
                    }
                }

                // Placeholder — drawn, not a Palette property, so the glass
                // styling stays fully under our control.
                Text {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                    }
                    visible: field.text.length === 0
                    text: "Password"
                    color: panel.theme.textTertiary
                    font.family: panel.theme.textFontFamily
                    font.pixelSize: field.font.pixelSize
                    renderType: Text.NativeRendering
                }
            }

            // ---- integrated login button --------------------------------------
            Rectangle {
                id: goButton
                property bool focusRing: false
                width: Math.round(panelBody.height * 0.64)
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                enabled: field.text.length > 0 && !panel.busy
                color: enabled ? (goMouse.pressed ? Qt.rgba(1,1,1,0.95) : Qt.rgba(1,1,1,0.82))
                               : Qt.rgba(1,1,1,0.14)
                Behavior on color { ColorAnimation { duration: 150 } }

                // arrow (vector)
                Canvas {
                    id: arrowCanvas
                    anchors.centerIn: parent
                    width: Math.round(parent.width * 0.52)
                    height: width
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const w = width, h = height
                        ctx.strokeStyle = goButton.enabled ? "#15151a"
                                                           : "rgba(255,255,255,0.55)"
                        ctx.lineWidth = Math.max(1.8, w * 0.12)
                        ctx.lineCap = "round"
                        ctx.lineJoin = "round"
                        ctx.beginPath()
                        ctx.moveTo(w * 0.24, h * 0.5)
                        ctx.lineTo(w * 0.74, h * 0.5)
                        ctx.moveTo(w * 0.56, h * 0.28)
                        ctx.lineTo(w * 0.76, h * 0.5)
                        ctx.lineTo(w * 0.56, h * 0.72)
                        ctx.stroke()
                    }
                    Connections {
                        target: goButton
                        function onEnabledChanged() { arrowCanvas.requestPaint() }
                    }
                }

                MouseArea {
                    id: goMouse
                    anchors.fill: parent
                    enabled: goButton.enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: panel.submit()
                }
            }
        }
    }
}
