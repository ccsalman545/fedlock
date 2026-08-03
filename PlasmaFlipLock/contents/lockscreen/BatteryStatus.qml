/* Battery presentation using Plasma's current power-management data source. */
import QtQuick
import org.kde.plasma.plasma5support as P5Support

Item {
    id: root

    property var theme
    property real pixelSize: 16
    readonly property var battery: powerSource.data["Battery"]
    readonly property var acAdapter: powerSource.data["AC Adapter"]

    function getValue(source, key, fallback) {
        if (source !== null && source !== undefined && source[key] !== undefined)
            return source[key]
        return fallback
    }

    readonly property bool hasBattery: !!getValue(battery, "Has Battery", false)
                                      || !!getValue(battery, "Has Cumulative", false)
    readonly property int percent: Math.max(0, Math.min(100, Number(getValue(battery, "Percent", 0))))
    readonly property bool pluggedIn: !!getValue(acAdapter, "Plugged in", false)
    readonly property bool charging: pluggedIn && percent < 100
    readonly property string stateText: charging ? "Charging" : (pluggedIn ? "Charged" : "On battery")

    visible: hasBattery
    width: row.implicitWidth
    height: visible ? Math.max(20, root.pixelSize * 1.35) : 0
    implicitWidth: row.implicitWidth
    implicitHeight: visible ? Math.max(20, root.pixelSize * 1.35) : 0

    P5Support.DataSource {
        id: powerSource
        engine: "powermanagement"
        connectedSources: ["Battery", "AC Adapter"]
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Math.max(8, Math.round(root.height * 0.34))

        Item {
            width: Math.max(23, Math.round(root.pixelSize * 1.20))
            height: Math.max(14, Math.round(root.pixelSize * 0.66))
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: batteryBody
                x: 0
                y: 0
                width: parent.width - batteryTip.width - 2
                height: parent.height
                radius: Math.max(3, height * 0.22)
                color: "transparent"
                border.width: 1
                border.color: root.theme.secondaryText
            }
            Rectangle {
                x: batteryBody.x + 3
                y: batteryBody.y + 3
                width: Math.max(0, (batteryBody.width - 6) * root.percent / 100)
                height: Math.max(2, batteryBody.height - 6)
                radius: Math.max(1, height * 0.18)
                color: root.theme.accent
            }
            Rectangle {
                id: batteryTip
                x: batteryBody.width + 2
                y: (parent.height - height) / 2
                width: 3
                height: Math.max(5, parent.height * 0.34)
                radius: 1.5
                color: root.theme.secondaryText
            }
            Text {
                anchors.centerIn: batteryBody
                visible: root.charging
                text: "⚡"
                color: root.theme.backgroundMiddle
                font.pixelSize: Math.max(9, Math.round(parent.height * 0.62))
                font.weight: Font.Bold
                renderType: Text.NativeRendering
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.percent + "% · " + root.stateText
            color: root.theme.secondaryText
            font.family: "DejaVu Sans"
            font.pixelSize: Math.max(12, Math.round(root.pixelSize))
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
        }
    }
}
