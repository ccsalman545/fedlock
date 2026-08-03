/* A clipped top or bottom half of one flat flip card. */
import QtQuick

Item {
    id: root

    property var theme
    property bool topHalf: true
    property string digit: "0"
    property int cardWidth: 180
    property int cardHeight: 300

    width: root.cardWidth
    height: root.cardHeight / 2
    clip: true

    Rectangle {
        width: root.cardWidth
        height: root.cardHeight
        y: root.topHalf ? 0 : -root.cardHeight / 2
        radius: Math.max(6, root.cardHeight * root.theme.cardRadius)
        border.width: 1
        border.color: root.theme.cardEdge
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.theme.cardTop }
            GradientStop { position: 0.47; color: root.theme.cardBottom }
            GradientStop { position: 1.0; color: "#0b1118" }
        }

        // Static highlights give the cached faces a physical, anti-aliased sheen.
        Rectangle {
            width: parent.width
            height: Math.max(2, parent.height * 0.11)
            radius: parent.radius
            color: Qt.rgba(1, 1, 1, root.topHalf ? 0.055 : 0.018)
        }
        Text {
            anchors.centerIn: parent
            text: root.digit
            color: root.theme.digit
            font.family: root.theme.displayFont
            font.pixelSize: Math.max(30, Math.round(root.cardHeight * root.theme.digitSize))
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
        }
    }
}
