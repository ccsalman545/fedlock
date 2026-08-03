/*
    Presentation-only password field.

    This component never verifies a password. It emits submitted(text); the
    greeter-owned LockScreen.qml forwards that text to authenticator.respond().
*/
import QtQuick

Item {
    id: root

    property var theme
    property bool busy: false
    // Set by the lockscreen pointer tracker; bounded to a subtle 3 degree tilt.
    property real pointerRatio: 0
    property alias password: passwordInput.text

    signal submitted(string password)

    implicitWidth: 560
    implicitHeight: 72

    function forceFocus() {
        passwordInput.forceActiveFocus()
    }

    function clearPassword() {
        passwordInput.clear()
    }

    function reject() {
        shakeAnimation.restart()
    }

    transform: [
        Translate { id: shakeTransform },
        Rotation { origin.x: root.width / 2; origin.y: root.height / 2; axis { x: 0; y: 1; z: 0 }; angle: root.pointerRatio * 3; Behavior on angle { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } } }
    ]

    Rectangle {
        id: focusRing
        anchors.fill: parent
        radius: root.theme.largeCorner
        color: root.theme.surfaceContainerHigh
        border.width: 1
        border.color: passwordInput.activeFocus ? root.theme.accent : Qt.rgba(1, 1, 1, 0.22)
        opacity: passwordInput.activeFocus ? 1.0 : 0.82
        Behavior on opacity { NumberAnimation { duration: 160 } }
    }

    // The faint ring breathes only while the field has focus.
    Rectangle {
        id: focusGlow
        anchors.fill: focusRing
        anchors.margins: -3
        radius: height / 2 + 3
        color: "transparent"
        border.width: 2
        border.color: root.theme.accent
        opacity: 0
    }

    SequentialAnimation {
        id: focusPulse
        // Two short focus cues are enough; do not animate a focused field forever.
        loops: 2
        NumberAnimation { target: focusGlow; property: "opacity"; from: 0.10; to: 0.30; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { target: focusGlow; property: "opacity"; from: 0.30; to: 0.10; duration: 900; easing.type: Easing.InOutSine }
    }

    SequentialAnimation {
        id: shakeAnimation
        NumberAnimation { target: shakeTransform; property: "x"; to: -10; duration: 55; easing.type: Easing.OutQuad }
        NumberAnimation { target: shakeTransform; property: "x"; to: 10; duration: 95; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeTransform; property: "x"; to: -5; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeTransform; property: "x"; to: 0; duration: 60; easing.type: Easing.OutQuad }
    }

    Image {
        id: lockIcon
        x: Math.round(root.height * 0.32)
        width: Math.round(root.height * 0.34)
        height: width
        anchors.verticalCenter: parent.verticalCenter
        source: Qt.resolvedUrl("assets/lock.svg")
        opacity: 0.82
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    TextInput {
        id: passwordInput
        x: Math.round(root.height * 0.90)
        width: Math.max(40, root.width - x - submitButton.width - Math.round(root.height * 1.18))
        height: root.height * 0.72
        anchors.verticalCenter: parent.verticalCenter
        enabled: !root.busy
        focus: false
        color: root.theme.primaryText
        selectionColor: Qt.rgba(0.62, 0.91, 0.88, 0.45)
        selectedTextColor: root.theme.primaryText
        font.family: root.theme.bodyFont
        font.pixelSize: Math.max(14, Math.round(root.height * 0.27))
        echoMode: TextInput.Password
        passwordCharacter: "•"
        passwordMaskDelay: -1
        cursorVisible: activeFocus
        renderType: TextInput.NativeRendering
        verticalAlignment: TextInput.AlignVCenter
        onAccepted: root.submitted(text)
        onActiveFocusChanged: {
            if (activeFocus) {
                focusPulse.restart()
            } else {
                focusPulse.stop()
                focusGlow.opacity = 0
            }
        }
    }

    Text {
        x: passwordInput.x
        width: passwordInput.width
        height: passwordInput.height
        anchors.verticalCenter: parent.verticalCenter
        visible: passwordInput.text.length === 0
        text: "Enter password"
        color: root.theme.mutedText
        font.family: root.theme.bodyFont
        font.pixelSize: passwordInput.font.pixelSize
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
    }

    Item {
        id: submitButton
        width: root.height * 0.70
        height: width
        anchors.right: parent.right
        anchors.rightMargin: root.height * 0.16
        anchors.verticalCenter: parent.verticalCenter
        opacity: root.busy ? 0.34 : (passwordInput.text.length > 0 ? 1.0 : 0.36)

        Rectangle {
            anchors.fill: parent
            radius: root.theme.largeCorner
            color: root.theme.accent
        }
        Image {
            anchors.centerIn: parent
            width: parent.width * 0.48
            height: width
            source: Qt.resolvedUrl("assets/arrow.svg")
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
        MouseArea {
            anchors.fill: parent
            enabled: !root.busy && passwordInput.text.length > 0
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.submitted(passwordInput.text)
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: passwordInput.forceActiveFocus()
    }
}
