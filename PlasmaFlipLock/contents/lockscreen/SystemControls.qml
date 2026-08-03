/* Compact Material 3 system affordances. Actions are intentionally signals: the
   greeter/host remains the sole authority for system power operations. */
import QtQuick

Item {
    id: root
    property var theme
    property bool capsLockOn: false
    property string keyboardLayout: Qt.inputMethod.locale.name || "Keyboard"
    signal sleepRequested()
    signal restartRequested()
    signal shutdownRequested()
    signal accessibilityRequested()

    implicitWidth: controls.implicitWidth
    implicitHeight: controls.implicitHeight

    Row {
        id: controls
        spacing: 8
        Repeater {
            model: [
                { "label": root.capsLockOn ? "CAPS" : "Caps", "active": root.capsLockOn, "action": "caps" },
                { "label": root.keyboardLayout, "active": false, "action": "keyboard" },
                { "label": "Accessibility", "active": false, "action": "accessibility" },
                { "label": "Power", "active": false, "action": "power" }
            ]
            delegate: Item {
                required property var modelData
                width: chip.implicitWidth
                height: chip.implicitHeight
                Rectangle {
                    id: chip
                    implicitWidth: label.implicitWidth + 28
                    implicitHeight: 34
                    radius: height / 2
                    color: modelData.active ? root.theme.accentContainer : root.theme.surfaceContainer
                    border.width: 1
                    border.color: root.theme.outlineVariant
                    scale: mouse.pressed ? 0.96 : (mouse.containsMouse ? 1.025 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    Text { id: label; anchors.centerIn: parent; text: modelData.label; color: root.theme.secondaryText; font.family: root.theme.bodyFont; font.pixelSize: 12; font.weight: Font.Medium }
                }
                MouseArea {
                    id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.action === "accessibility") root.accessibilityRequested()
                        else if (modelData.action === "power") powerMenu.opened = !powerMenu.opened
                    }
                }
            }
        }
    }

    Rectangle {
        id: powerMenu
        property bool opened: false
        visible: opacity > 0
        opacity: opened ? 1 : 0
        x: Math.max(0, root.width - width)
        y: root.height + 10
        width: 172; height: 126; radius: 20
        color: root.theme.surfaceContainerHigh
        border.width: 1; border.color: root.theme.outlineVariant
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Column {
            anchors.fill: parent; anchors.margins: 8; spacing: 2
            Repeater {
                model: [{ label: "Sleep", signal: "sleep" }, { label: "Restart", signal: "restart" }, { label: "Shut down", signal: "shutdown" }]
                delegate: Rectangle {
                    required property var modelData
                    width: parent.width; height: 34; radius: 12; color: itemMouse.containsMouse ? root.theme.surfaceHover : "transparent"
                    Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; color: root.theme.primaryText; font.family: root.theme.bodyFont; font.pixelSize: 13 }
                    MouseArea { id: itemMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { powerMenu.opened = false; if (modelData.signal === "sleep") root.sleepRequested(); else if (modelData.signal === "restart") root.restartRequested(); else root.shutdownRequested() } }
                }
            }
        }
    }
}
