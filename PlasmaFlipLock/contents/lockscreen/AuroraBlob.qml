/*
    One cached aurora blob.

    The source shape and FastBlur never change after construction. The parent
    moves this complete, already-rendered item, so ambient motion does not
    re-run a blur on every frame. A small cache is used instead of a full-screen
    wallpaper texture.
*/
import QtQuick
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property color blobColor: "#35d8c5"
    property real intensity: 0.30
    property real blurRadius: 54

    // Keep the finished effect in one scene-graph texture while its parent
    // translates. This is intentionally not a live backdrop blur.
    layer.enabled: true
    layer.smooth: true

    Item {
        id: shapeSource
        anchors.fill: parent
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: Math.max(width, height) * 0.50
            color: root.blobColor
            opacity: root.intensity
        }
    }

    FastBlur {
        anchors.fill: shapeSource
        source: shapeSource
        radius: root.blurRadius
        cached: true
        transparentBorder: true
    }
}
