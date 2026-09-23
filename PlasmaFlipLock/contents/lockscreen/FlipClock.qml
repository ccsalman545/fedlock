/* A minute-aligned 24-hour HH:MM clock. */
import QtQuick

Item {
    id: root

    property var theme
    property int cardHeight: 300
    property date currentTime: new Date()

    readonly property string timeText: Qt.locale().toString(currentTime, "HH:mm")
    readonly property int cardWidth: Math.round(cardHeight * 0.66)
    readonly property int cardGap: Math.max(6, Math.round(cardHeight * 0.045))
    readonly property int separatorWidth: Math.max(24, Math.round(cardHeight * 0.19))

    implicitWidth: clockRow.implicitWidth
    implicitHeight: cardHeight

    function refreshTime() {
        currentTime = new Date()
    }

    function scheduleNextMinute() {
        const now = new Date()
        const untilNextMinute = 60000 - now.getSeconds() * 1000 - now.getMilliseconds()
        minuteTimer.interval = Math.max(250, untilNextMinute)
        minuteTimer.restart()
    }

    Timer {
        id: minuteTimer
        repeat: false
        onTriggered: {
            root.refreshTime()
            root.scheduleNextMinute()
        }
    }

    Component.onCompleted: {
        refreshTime()
        scheduleNextMinute()
    }

    Row {
        id: clockRow
        anchors.centerIn: parent
        spacing: root.cardGap
        height: root.cardHeight

        FlipDigit {
            theme: root.theme
            value: root.timeText.charAt(0)
            cardWidth: root.cardWidth
            cardHeight: root.cardHeight
        }
        FlipDigit {
            theme: root.theme
            value: root.timeText.charAt(1)
            cardWidth: root.cardWidth
            cardHeight: root.cardHeight
        }

        Item {
            id: separator
            width: root.separatorWidth
            height: root.cardHeight

            Column {
                anchors.centerIn: parent
                spacing: Math.max(12, Math.round(root.cardHeight * 0.075))

                Rectangle {
                    width: Math.max(7, Math.round(root.cardHeight * 0.030))
                    height: width
                    radius: width / 2
                    color: root.theme.accent
                    opacity: 0.88
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.28; duration: root.theme.separatorPulseMs / 2; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.88; duration: root.theme.separatorPulseMs / 2; easing.type: Easing.InOutSine }
                    }
                }
                Rectangle {
                    width: Math.max(7, Math.round(root.cardHeight * 0.030))
                    height: width
                    radius: width / 2
                    color: root.theme.accent
                    opacity: 0.88
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        PauseAnimation { duration: root.theme.separatorPulseMs / 4 }
                        NumberAnimation { to: 0.28; duration: root.theme.separatorPulseMs / 2; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.88; duration: root.theme.separatorPulseMs / 2; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        FlipDigit {
            theme: root.theme
            value: root.timeText.charAt(3)
            cardWidth: root.cardWidth
            cardHeight: root.cardHeight
        }
        FlipDigit {
            theme: root.theme
            value: root.timeText.charAt(4)
            cardWidth: root.cardWidth
            cardHeight: root.cardHeight
        }
    }
}
