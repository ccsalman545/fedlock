/*
    Fedlock Premium Flip
    Design tokens are deliberately kept in one small object so the visual
    layer can be tuned without touching the authentication plumbing.

    Created by Muhammed Salman (CC).
*/
import QtQuick

QtObject {
    // Deep teal -> navy -> purple ambient palette.
    readonly property color backgroundTop: "#071b2a"
    readonly property color backgroundMiddle: "#101432"
    readonly property color backgroundBottom: "#170e2d"
    readonly property color auroraTeal: "#26d2be"
    readonly property color auroraBlue: "#496dff"
    readonly property color auroraPurple: "#a04dff"

    readonly property color cardTop: "#303842"
    readonly property color cardBottom: "#111821"
    readonly property color cardEdge: Qt.rgba(1, 1, 1, 0.13)
    readonly property color hinge: Qt.rgba(0.01, 0.03, 0.06, 0.92)
    readonly property color digit: "#f4f7fb"

    readonly property color primaryText: "#f7f8ff"
    readonly property color secondaryText: Qt.rgba(0.91, 0.94, 1.0, 0.76)
    readonly property color mutedText: Qt.rgba(0.89, 0.93, 1.0, 0.56)
    readonly property color accent: "#9ee9e0"
    readonly property color warning: "#ffb3a6"

    // Motion: ambientMotionTimer runs at about 30 Hz and stops after three
    // minutes by default. Set pauseAmbientAfterMs to 0 for continuous motion.
    readonly property int ambientPauseAfterMs: 180000
    readonly property int ambientTickMs: 33
    readonly property int flipDurationMs: 620
    readonly property int separatorPulseMs: 1700

    readonly property real cardRadius: 0.075
    readonly property real digitSize: 0.53
}
