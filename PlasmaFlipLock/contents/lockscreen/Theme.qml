/* Material 3 tokens with a cool Plasma aurora palette. */
import QtQuick

QtObject {
    readonly property string displayFont: "Inter, Google Sans, Noto Sans"
    readonly property string bodyFont: "Inter, Google Sans, Noto Sans"
    readonly property color backgroundTop: "#071b2a"
    readonly property color backgroundMiddle: "#101432"
    readonly property color backgroundBottom: "#170e2d"
    readonly property color auroraTeal: "#26d2be"
    readonly property color auroraBlue: "#496dff"
    readonly property color auroraPurple: "#a04dff"
    readonly property color cardTop: "#3a4552"
    readonly property color cardBottom: "#121923"
    readonly property color cardEdge: Qt.rgba(1, 1, 1, 0.18)
    readonly property color hinge: Qt.rgba(0.01, 0.03, 0.06, 0.94)
    readonly property color digit: "#f7f9ff"
    readonly property color primaryText: "#f7f8ff"
    readonly property color secondaryText: Qt.rgba(0.91, 0.94, 1.0, 0.78)
    readonly property color mutedText: Qt.rgba(0.89, 0.93, 1.0, 0.58)
    readonly property color accent: "#9ee9e0"
    readonly property color accentContainer: "#174d49"
    readonly property color warning: "#ffb3a6"
    readonly property color surfaceContainer: Qt.rgba(20, 29, 43, 0.68)
    readonly property color surfaceContainerHigh: Qt.rgba(31, 42, 59, 0.94)
    readonly property color surfaceHover: Qt.rgba(255, 255, 255, 0.10)
    readonly property color outlineVariant: Qt.rgba(230, 240, 255, 0.18)
    readonly property int ambientPauseAfterMs: 180000
    readonly property int ambientTickMs: 33
    readonly property int flipDurationMs: 620
    readonly property int separatorPulseMs: 1700
    readonly property real cardRadius: 0.075
    readonly property real digitSize: 0.53
    readonly property int largeCorner: 28
}
