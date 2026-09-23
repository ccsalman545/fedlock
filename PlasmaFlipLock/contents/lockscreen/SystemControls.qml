/* Small lock-screen status and power affordances. */
import QtQuick

Item {
    id: root

    property var theme
    property bool capsLockOn: false
    property bool sleepAvailable: false
    signal sleepRequested()

    implicitWidth: controls.implicitWidth
    implicitHeight: controls.implicitHeight

    Row {
        id: controls
        spacing: 8

        Repeater {
            model: [
                {
                    "label": "CAPS LOCK",
                    "active": true,
                    "visible": root.capsLockOn,
                    "action": "status"
                },
                {
                    "label": "Sleep",
                    "active": false,
                    "visible": root.sleepAvailable,
                    "action": "sleep"
                }
            ]

            delegate: Item {
                required property var modelData
                visible: modelData.visible
                width: visible ? chip.implicitWidth : 0
                height: visible ? chip.implicitHeight : 0

                Rectangle {
                    id: chip
                    implicitWidth: label.implicitWidth + 28
                    implicitHeight: 34
                    radius: height / 2
                    color: modelData.active ? root.theme.accentContainer : root.theme.surfaceContainer
                    border.width: 1
                    border.color: root.theme.outlineVariant
                    scale: mouse.pressed ? 0.96 : (mouse.containsMouse ? 1.025 : 1.0)
                    Behavior on scale {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: modelData.label
                        color: root.theme.secondaryText
                        font.family: root.theme.bodyFont
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    enabled: modelData.action === "sleep"
                    hoverEnabled: enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.sleepRequested()
                }
            }
        }
    }
}
