/*
    PlasmaFlipLock — flip-clock lock screen for KScreenLocker (Plasma 6 / Wayland)
    SPDX-License-Identifier: GPL-2.0-or-later

    FlipDigit.qml
    =============
    ONE flip-clock digit card (0–9) with a two-phase mechanical flip.

    Layer cake (back → front):

        cardShadow   MultiEffect drop shadow   (static texture, GPU cached)
        staticTop    top half,    shows the NEW digit (revealed in phase 1)
        staticBottom bottom half, shows the OLD digit (covered   in phase 2)
        flapTop      top half,    shows the OLD digit, folds 0°→90°  (phase 1)
        flapBottom   bottom half, shows the NEW digit, swings 90°→0° (phase 2)
        seam         the little horizontal hinge line (always on top)

    The flip itself is, per the design spec, a QML SequentialAnimation of two
    RotationAnimation steps around the X axis. Qt Quick projects rotations
    orthographically, so depth is faked with a darkening gloss on the moving
    flap — cheap and it sells the mechanic.

    PERFORMANCE NOTES (Intel HD 620 friendly):
      - The drop shadow is rendered once (static source) — no per-frame cost.
      - While idle *nothing* in this file re-renders (no timers, no layers).
      - During a flip only the two small flaps are transformed; the glyphs are
        NativeRendering rasterized once and then merely moved on the GPU.
*/

import QtQuick
import QtQuick.Effects   // MultiEffect (Qt >= 6.5, part of every Qt 6 desktop)

Item {
    id: card

    // ---- public API -------------------------------------------------------
    required property Theme theme          // shared design tokens
    property string value: "0"             // the digit to display ("0"…"9")
    property int    cardWidth:  320
    property int    cardHeight: 460

    implicitWidth:  cardWidth
    implicitHeight: cardHeight

    // ---- derived geometry --------------------------------------------------
    readonly property int cornerRadius: Math.max(6, Math.round(cardHeight * theme.cardRadiusFactor))
    readonly property int shadowPad:    Math.max(16, Math.round(cardHeight * 0.085))
    readonly property int seamThickness: Math.max(2, Math.round(cardHeight * theme.seamFactor))

    // ---- private state ------------------------------------------------------
    // All flip bookkeeping lives in one place, updated manually (NOT via
    // bindings) so the running animation never fights binding re-evaluation.
    QtObject {
        id: priv
        property bool   initialized: false  // suppress flip on first assignment
        property bool   animating:   false  // true while flipAnim runs
        property string oldValue: "0"       // digit shown before the flip
        property string newValue: "0"       // digit the flip is heading to
    }

    // =========================================================================
    //  Flip trigger — "flip animation only when digits change"
    // =========================================================================
    onValueChanged: {
        if (!priv.initialized) {
            return                              // first assignment: just render it
        }
        if (!flipAnim.running) {                // startFlip() also runs from here
            startFlip()
        } else {
            requireRestart = true               // a change landed mid-flip
        }
    }
    Component.onCompleted: priv.initialized = true

    // A mid-flip digit change is vanishingly rare (one flip per minute), but
    // handle it correctly instead of skipping a glyph.
    property bool requireRestart: false

    // Prepares the four half-layers and (re)starts the SequentialAnimation.
    function startFlip() {
        priv.oldValue  = staticBottom.aDigit  // what the user currently sees
        priv.newValue  = card.value           // where we are going
        priv.animating = true
        requireRestart = false

        flapTop.aDigit      = priv.oldValue
        flapTop.visible     = true
        flapTopRot.angle    = 0
        flapBottom.aDigit   = priv.newValue
        flapBottom.visible  = true
        flapBottomRot.angle = 90              // edge-on → invisible to viewer

        flipAnim.restart()
    }

    // Jumps the layer stack to the resting state (used when a second change
    // interrupted a flip — snap to the end and start the next one cleanly).
    function completeFlip() {
        flipAnim.stop()
        staticBottom.aDigit = card.value
        staticTop.aDigit    = card.value
        flapTop.visible     = false
        flapTopRot.angle    = 0
        flapBottom.visible  = false
        flapBottomRot.angle = 90
        priv.animating      = false
        if (requireRestart) {
            requireRestart = false
            startFlip()
        }
    }

    // =========================================================================
    //  THE FLIP — SequentialAnimation of RotationAnimations, per spec.
    //  Phase 1: old top half folds down over the seam (accelerating like a
    //           falling steam gauge flap)        0° → 90°,  Easing.InQuad
    //  Phase 2: new bottom half swings into place (decelerating with a tiny
    //           mechanical settle)               90° →  0°,  Easing.OutBack
    // =========================================================================
    SequentialAnimation {
        id: flipAnim

        RotationAnimation {
            target: flapTopRot
            property: "angle"
            from: 0
            to: 90
            duration: Math.round(card.theme.flipDuration * 0.56)
            easing.type: Easing.InQuad        // gravity: starts slow, accelerates
        }
        RotationAnimation {
            target: flapBottomRot
            property: "angle"
            from: 90
            to: 0
            duration: Math.round(card.theme.flipDuration * 0.44)
            easing.type: Easing.OutBack       // eases in and snaps with a soft settle
            easing.overshoot: 0.45            // keep subtle — premium, not bouncy
        }
        ScriptAction {
            script: card.completeFlip()
        }
    }

    // =========================================================================
    //  Internal building block: one card half.
    //  A half is a clipping window (width × height/2) onto a full-size card
    //  face, translated so the glyph aligns across the seam.
    // =========================================================================
    component Half: Item {
        id: halfRoot

        property string aDigit: "0"           // glyph rendered in THIS half
        property bool   isTop: true           // which half of the card we are

        width:  card.cardWidth
        height: card.cardHeight / 2
        clip: true                            // the cut: top half shows [0 · h/2]

        // Full-size card face; the bottom half shifts it up by half a card so
        // the same glyph pixels line up across the seam.
        Item {
            width:  card.cardWidth
            height: card.cardHeight
            y: halfRoot.isTop ? 0 : -card.cardHeight / 2

            // Card face: deep grey → black, subtle vertical sheen (Fliqlo look).
            Rectangle {
                anchors.fill: parent
                radius: card.cornerRadius     // only outer corners survive the
                gradient: Gradient {          // clip, the seam edge stays square
                    GradientStop { position: 0.0;  color: card.theme.cardColorTop }
                    GradientStop { position: 0.48; color: card.theme.cardColorMid }
                    GradientStop { position: 0.52; color: card.theme.cardColorMid }
                    GradientStop { position: 1.0;  color: card.theme.cardColorBottom }
                }
            }

            // The glyph, centred on the FULL card so the seam splits it.
            Text {
                anchors.centerIn: parent
                text: halfRoot.aDigit
                color: card.theme.digitColor
                font.family: card.theme.digitFontFamily
                font.pixelSize: Math.round(card.cardHeight * card.theme.digitScale)
                // Bebas Neue ships a single weight — synthesising faux-bold on
                // top of it gets blurry. Only ask for DemiBold when we had to
                // fall back to a non-condensed system font.
                font.weight: card.theme.digitFontFamily === "Bebas Neue"
                             ? Font.Normal : Font.DemiBold
                renderType: Text.NativeRendering  // crisp at giant sizes; the
                                                  // texture is cached, so the
                                                  // flip animates pixels on the
                                                  // GPU, not glyph rasterisation
                textFormat: Text.PlainText
            }
        }
    }

    // =========================================================================
    //  LAYERS (see header comment for the full map)
    // =========================================================================

    // 0) Drop shadow ----------------------------------------------------------
    //    Rendered from an invisible plate; the visible card leaves this as a
    //    pure blurred silhouette. Static → MultiEffect renders it once.
    Rectangle {
        id: shadowPlate
        anchors.fill: parent
        radius: card.cornerRadius
        color: "#000000"
        visible: false                        // only lives to be the effect's source
    }
    MultiEffect {
        x: -card.shadowPad
        y: -card.shadowPad
        width:  card.width  + 2 * card.shadowPad
        height: card.height + 2 * card.shadowPad
        source: shadowPlate
        shadowEnabled: true
        shadowColor: "#a0000000"
        shadowOpacity: 1.0
        shadowBlur: 1.0                       // 1.0 × blurMax → px radius
        blurMax: card.shadowPad               // gaussian spread of the shadow
        shadowVerticalOffset: Math.round(card.cardHeight * 0.018)
        shadowHorizontalOffset: 0
    }

    // 1) Static top half — always the CURRENT digit. Binding updates it the
    //    moment `value` changes; flapTop still covers it, so the flip reveal
    //    reads correctly while phase 1 runs.
    Half {
        id: staticTop
        isTop: true
        aDigit: card.value
    }

    // 2) Static bottom half — the OLD digit while a flip runs (until the new
    //    flap lands on it), the CURRENT digit at rest.
    Half {
        id: staticBottom
        isTop: false
        y: card.cardHeight / 2
        aDigit: priv.animating ? priv.oldValue : card.value
    }

    // 3) Top flap — shows the OLD top half and folds away (phase 1). Hidden at
    //    rest. Rotation origin is its bottom edge = the seam/hinge.
    Half {
        id: flapTop
        isTop: true
        visible: false
        z: 3
        transform: Rotation {
            id: flapTopRot
            origin.x: flapTop.width  / 2
            origin.y: flapTop.height          // hinge at the seam
            axis { x: 1; y: 0; z: 0 }
            angle: 0
        }
        // Darkening gloss — sells the fold under orthographic projection.
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: flapTopRot.angle / 90 * 0.55
        }
    }

    // 4) Bottom flap — shows the NEW bottom half swinging in (phase 2). Hidden
    //    at rest. Rotation origin is its top edge = the seam/hinge.
    Half {
        id: flapBottom
        isTop: false
        y: card.cardHeight / 2
        visible: false
        z: 4
        transform: Rotation {
            id: flapBottomRot
            origin.x: flapBottom.width / 2
            origin.y: 0                        // hinge at the seam
            axis { x: 1; y: 0; z: 0 }
            angle: 90
        }
        // Slightly brighter while swinging toward the viewer.
        Rectangle {
            anchors.fill: parent
            color: "#ffffff"
            opacity: flapBottomRot.angle / 90 * 0.06
        }
    }

    // 5) The seam — hinge line splitting the two halves, always sharp on top.
    Rectangle {
        z: 5
        x: 0
        y: (card.cardHeight - height) / 2
        width: card.cardWidth
        height: card.seamThickness
        color: card.theme.seamColor
        opacity: 0.85
    }
}
