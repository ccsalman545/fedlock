/*
    One mechanical split-flap digit.

    Only the two transient flap items are transformed. The digit faces are
    flat rectangles, and the Rotation + NumberAnimation pair is GPU-friendly.
    There is no shader effect in this animation path.
*/
import QtQuick

Item {
    id: root

    property var theme
    property string value: "0"
    property int cardWidth: 180
    property int cardHeight: 300

    implicitWidth: cardWidth
    implicitHeight: cardHeight
    width: cardWidth
    height: cardHeight

    QtObject {
        id: state
        property bool initialized: false
        property bool flipping: false
        property string oldValue: "0"
        property string nextValue: "0"
    }

    function startFlip() {
        if (state.flipping) {
            flipSequence.stop()
            state.flipping = false
        }

        state.oldValue = state.nextValue
        state.nextValue = root.value
        state.flipping = true
        topRotation.angle = 0
        bottomRotation.angle = 90
        flipSequence.restart()
    }

    onValueChanged: {
        if (!state.initialized) {
            state.nextValue = value
            return
        }
        if (value !== state.nextValue) {
            startFlip()
        }
    }

    Component.onCompleted: {
        state.nextValue = value
        state.oldValue = value
        state.initialized = true
    }

    // Resting faces. The old bottom remains underneath while the new flap
    // swings in, so the seam reads as a real hinge rather than a cross-fade.
    FlipHalf {
        id: staticTop
        theme: root.theme
        topHalf: true
        digit: state.nextValue
        cardWidth: root.cardWidth
        cardHeight: root.cardHeight
    }

    FlipHalf {
        id: staticBottom
        y: root.cardHeight / 2
        theme: root.theme
        topHalf: false
        digit: state.flipping ? state.oldValue : state.nextValue
        cardWidth: root.cardWidth
        cardHeight: root.cardHeight
    }

    FlipHalf {
        id: topFlap
        z: 3
        visible: state.flipping
        theme: root.theme
        topHalf: true
        digit: state.oldValue
        cardWidth: root.cardWidth
        cardHeight: root.cardHeight
        layer.enabled: true
        layer.smooth: true
        transform: Rotation {
            id: topRotation
            origin.x: topFlap.width / 2
            origin.y: topFlap.height
            axis { x: 1; y: 0; z: 0 }
            angle: 0
        }
    }

    FlipHalf {
        id: bottomFlap
        z: 4
        y: root.cardHeight / 2
        visible: state.flipping
        theme: root.theme
        topHalf: false
        digit: state.nextValue
        cardWidth: root.cardWidth
        cardHeight: root.cardHeight
        layer.enabled: true
        layer.smooth: true
        transform: Rotation {
            id: bottomRotation
            origin.x: bottomFlap.width / 2
            origin.y: 0
            axis { x: 1; y: 0; z: 0 }
            angle: 90
        }
    }

    // The hinge is always on top of all moving faces.
    Rectangle {
        z: 5
        x: 0
        y: root.cardHeight / 2 - height / 2
        width: root.cardWidth
        height: Math.max(2, Math.round(root.cardHeight * 0.010))
        color: root.theme.hinge
    }

    SequentialAnimation {
        id: flipSequence

        NumberAnimation {
            target: topRotation
            property: "angle"
            from: 0
            to: -90
            duration: Math.round(root.theme.flipDurationMs * 0.56)
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: bottomRotation
            property: "angle"
            from: 90
            to: 0
            duration: Math.round(root.theme.flipDurationMs * 0.44)
            easing.type: Easing.OutCubic
        }
        ScriptAction {
            script: {
                state.flipping = false
                topRotation.angle = 0
                bottomRotation.angle = 90
            }
        }
    }
}
