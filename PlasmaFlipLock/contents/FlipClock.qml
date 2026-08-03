/*
    PlasmaFlipLock — flip-clock lock screen for KScreenLocker (Plasma 6 / Wayland)
    SPDX-License-Identifier: GPL-2.0-or-later

    FlipClock.qml
    =============
    The complete HH:MM flip clock: four FlipDigit cards + a colon card.

    Time source: `org.kde.plasma.clock` Clock — the same KDE clock service
    the stock Plasma 6 lock screen uses. With `trackSeconds: false` it wakes
    up aligned to the minute boundary (no per-second churn, low CPU), which
    is exactly what a seconds-less flip clock needs.

    Digits are pushed into the FlipDigit children as plain property bindings;
    a FlipDigit only animates when its `value` actually changes, so at most
    3 cards flip per minute (and 0 cards flip when e.g. 12:30 → 12:31 keeps
    the hour and the tens-of-minutes digit).
*/

import QtQuick
import org.kde.plasma.clock as PlasmaClock   // KDE clock service (ships with Plasma 6)

Item {
    id: clockRoot

    // ---- public API -------------------------------------------------------
    required property Theme theme

    // Card height in px. Set by LockScreenUi (≈ 45 % of screen height).
    property int cardHeight: 460

    // The current time, exported so LockScreenUi can render the date strings
    // from the very same clock tick (no second time source running).
    readonly property date currentTime: timeSource.dateTime

    implicitWidth:  clockRow.implicitWidth
    implicitHeight: cardHeight

    // ---- time source -------------------------------------------------------
    PlasmaClock.Clock {
        id: timeSource
        trackSeconds: false    // seconds are not displayed — don't wake for them
    }

    // ---- digit extraction (24-hour, zero-padded, e.g. "07:04") -------------
    readonly property string timeString: Qt.formatDateTime(currentTime, "HH:mm")
    readonly property string h0: timeString.charAt(0)
    readonly property string h1: timeString.charAt(1)
    readonly property string m0: timeString.charAt(3)
    readonly property string m1: timeString.charAt(4)

    // ---- derived geometry ----------------------------------------------------
    readonly property int cardW: Math.round(cardHeight * theme.cardAspect)
    readonly property int cardGap: Math.max(6, Math.round(cardHeight * theme.gapFactor))
    readonly property int cornerR: Math.max(6, Math.round(cardHeight * theme.cardRadiusFactor))

    // =========================================================================
    //  H : M
    // =========================================================================
    Row {
        id: clockRow
        anchors.centerIn: parent
        height: clockRoot.cardHeight
        spacing: clockRoot.cardGap

        FlipDigit {
            theme: clockRoot.theme
            cardWidth: clockRoot.cardW
            cardHeight: clockRoot.cardHeight
            value: clockRoot.h0
        }
        FlipDigit {
            theme: clockRoot.theme
            cardWidth: clockRoot.cardW
            cardHeight: clockRoot.cardHeight
            value: clockRoot.h1
        }

        // ------------------------------------------------------------------
        //  ":" colon card — slim black card, two white pips, split by a seam,
        //  matching the digit cards' materials (Fliqlo style, static).
        // ------------------------------------------------------------------
        Item {
            id: colonCard
            width: Math.round(clockRoot.cardHeight * clockRoot.theme.colonWidthFactor)
            height: clockRoot.cardHeight

            Rectangle {
                anchors.fill: parent
                radius: clockRoot.cornerR
                gradient: Gradient {
                    GradientStop { position: 0.0;  color: clockRoot.theme.cardColorTop }
                    GradientStop { position: 0.48; color: clockRoot.theme.cardColorMid }
                    GradientStop { position: 0.52; color: clockRoot.theme.cardColorMid }
                    GradientStop { position: 1.0;  color: clockRoot.theme.cardColorBottom }
                }
            }
            // Hinge seam, same as the digit cards.
            Rectangle {
                x: 0
                y: (colonCard.height - height) / 2
                width: colonCard.width
                height: Math.max(2, Math.round(colonCard.height * clockRoot.theme.seamFactor))
                color: clockRoot.theme.seamColor
                opacity: 0.85
            }
            // Two pips, centred in the top and bottom halves.
            Repeater {
                model: 2
                delegate: Rectangle {
                    readonly property real d: Math.max(6, Math.round(colonCard.height * 0.075))
                    width: d
                    height: d
                    radius: d / 2
                    color: clockRoot.theme.digitColor
                    x: (colonCard.width - d) / 2
                    y: colonCard.height * (index === 0 ? 0.325 : 0.675) - d / 2
                }
            }
        }

        FlipDigit {
            theme: clockRoot.theme
            cardWidth: clockRoot.cardW
            cardHeight: clockRoot.cardHeight
            value: clockRoot.m0
        }
        FlipDigit {
            theme: clockRoot.theme
            cardWidth: clockRoot.cardW
            cardHeight: clockRoot.cardHeight
            value: clockRoot.m1
        }
    }
}
