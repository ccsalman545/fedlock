/*
    Low-cost ambient background.

    The base gradient is static. Two small, cached FastBlur blobs are moved by
    a 30 Hz timer; only x/y/opacity change after their one-time render. The
    timer pauses after the configured timeout to avoid burning battery while a
    laptop is left locked. Set pauseAfterMs to 0 in Theme.qml to keep moving.
*/
import QtQuick

Item {
    id: root

    property var theme
    property bool animate: true
    property int pauseAfterMs: 180000
    property int tickMs: 33
    property real phase: 0.0
    property int activeMs: 0

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.theme.backgroundTop }
            GradientStop { position: 0.52; color: root.theme.backgroundMiddle }
            GradientStop { position: 1.0; color: root.theme.backgroundBottom }
        }
    }

    // The blobs are deliberately smaller than the screen to limit cached
    // texture memory on an Intel HD 620.
    AuroraBlob {
        id: tealBlob
        width: Math.max(260, root.width * 0.60)
        height: Math.max(220, root.height * 0.50)
        x: -width * 0.20 + Math.sin(root.phase * 6.283 + 0.2) * root.width * 0.12
        y: root.height * 0.02 + Math.cos(root.phase * 6.283) * root.height * 0.07
        blobColor: root.theme.auroraTeal
        intensity: 0.25
        opacity: 0.92 + Math.sin(root.phase * 6.283 + 0.4) * 0.08
        blurRadius: 52
    }

    AuroraBlob {
        id: violetBlob
        width: Math.max(280, root.width * 0.58)
        height: Math.max(230, root.height * 0.55)
        x: root.width * 0.53 + Math.cos(root.phase * 6.283 + 1.1) * root.width * 0.13
        y: root.height * 0.42 + Math.sin(root.phase * 6.283 + 1.4) * root.height * 0.10
        blobColor: root.theme.auroraPurple
        intensity: 0.22
        opacity: 0.90 + Math.cos(root.phase * 6.283 + 0.7) * 0.10
        blurRadius: 58
    }

    // A static blue wash adds depth without another effect pass.
    Rectangle {
        anchors.fill: parent
        color: root.theme.auroraBlue
        opacity: 0.045
    }

    // Simple edge falloff; no per-frame blur or shader.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.30) }
            GradientStop { position: 0.18; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 0.78; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.38) }
        }
    }

    Timer {
        id: motionTimer
        interval: root.tickMs
        repeat: true
        running: root.visible && root.animate
        onTriggered: {
            if (root.pauseAfterMs > 0 && root.activeMs >= root.pauseAfterMs) {
                stop()
                return
            }
            root.activeMs += root.tickMs
            root.phase = (root.phase + root.tickMs / 30000.0) % 1.0
        }
    }

    onVisibleChanged: {
        if (visible && animate) {
            activeMs = 0
            phase = 0.0
            motionTimer.restart()
        } else {
            motionTimer.stop()
        }
    }
}
