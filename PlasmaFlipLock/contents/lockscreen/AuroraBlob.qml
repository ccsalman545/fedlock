/*
   Qt 6-only aurora primitive.  This deliberately avoids Qt5Compat.GraphicalEffects:
   a handful of cached translucent discs approximates a soft bloom without a
   full-screen or continuously recomputed Gaussian-blur pass.
*/
import QtQuick

Item {
    id: root
    property color blobColor: "#35d8c5"
    property real intensity: 0.30
    // Kept as a public tuning property for callers; softness is baked in layers.
    property real blurRadius: 54
    layer.enabled: true
    layer.smooth: true

    Repeater {
        model: 4
        delegate: Rectangle {
            required property int index
            readonly property real inset: index * Math.min(root.width, root.height) * 0.075
            anchors.fill: parent
            anchors.margins: inset
            radius: Math.min(width, height) / 2
            color: root.blobColor
            // Smaller layers are brighter; together they create a low-cost bloom.
            opacity: root.intensity * (0.13 + index * 0.07)
            antialiasing: true
        }
    }
}
