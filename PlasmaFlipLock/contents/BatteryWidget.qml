/*
    PlasmaFlipLock — flip-clock lock screen for KScreenLocker (Plasma 6 / Wayland)
    SPDX-License-Identifier: GPL-2.0-or-later

    BatteryWidget.qml
    =================
    The small status strip under the date:
        [▮ 82% · Charging]   •   21°          (weather part is optional)

    BATTERY — uses BatteryControlModel from org.kde.plasma.private.battery,
    the very same model the STOCK Plasma 6 lock screen uses (it ships with
    plasma-workspace, so it is always present wherever the lock screen runs):
        hasInternalBatteries : bool   — strip hides itself on desktops
        percent              : 0..100
        pluggedIn            : bool   — AC power attached
        state                : enum   — NoCharge / Charging / Discharging /
                                        FullyCharged

    WEATHER — optional (Theme.showWeather / kscreenlockerrc "[Greeter][LnF]"
    showWeather=true). The legacy "weather" DATAENGINE (org.kde.plasma.
    plasma5support) is used if — and only if — it exists on the system; the
    DataSource object is created DYNAMICALLY via Qt.createQmlObject inside
    try/catch, so systems without that engine (Plasma ≥ 6.4 removed the old
    weather dataengine) simply show no weather instead of failing to load
    the whole lock screen. Source string format: "provider|City",
    e.g. "bbcukmet|London".

    The battery glyph is hand-drawn vector QML (rounded rect + fill + nub +
    lightning bolt) — no icon theme lookups, scales cleanly at any size.
*/

import QtQuick
import org.kde.plasma.private.battery as PrivateBattery

Item {
    id: strip

    // ---- public API ---------------------------------------------------
    required property Theme theme
    property real pixelSize: 19          // label size; controls icon size too

    implicitWidth:  stripRow.implicitWidth
    implicitHeight: stripRow.implicitHeight

    // Only visible when there is actually something to report.
    visible: (theme.showBattery && hasBattery) || (theme.showWeather && weatherValid)

    // ==================================================================
    //  BATTERY DATA (proven greeter-compatible model from plasma-workspace)
    // ==================================================================
    PrivateBattery.BatteryControlModel { id: batteryControl }

    readonly property bool   hasBattery:   batteryControl.hasInternalBatteries === true
    readonly property int    percent:      hasBattery ? batteryControl.percent : -1
    readonly property bool   charging:     hasBattery && batteryControl.state === PrivateBattery.BatteryControlModel.Charging
    readonly property bool   fullyCharged: hasBattery && batteryControl.state === PrivateBattery.BatteryControlModel.FullyCharged

    // ==================================================================
    //  OPTIONAL WEATHER DATA (legacy dataengine, created only when enabled
    //  and only if the engine exists — see file header)
    // ==================================================================
    property var weatherDs: null
    Item { id: weatherHelper; visible: false }

    function createWeatherSource() {
        destroyWeatherSource()
        if (!theme.showWeather || theme.weatherSource.trim().length === 0)
            return
        try {
            weatherDs = Qt.createQmlObject(
`import QtQuick
import org.kde.plasma.plasma5support as P5Support
P5Support.DataSource {
    engine: "weather"
    interval: 1800000
}`,
            weatherHelper, "PlasmaFlipLockWeather")
            weatherDs.connectedSources = [theme.weatherSource]
        } catch (e) {
            weatherDs = null                // engine/module not available — fine
        }
    }
    function destroyWeatherSource() {
        if (weatherDs) {
            weatherDs.destroy()
            weatherDs = null
        }
    }

    Connections {
        target: strip.theme
        function onShowWeatherChanged()   { strip.createWeatherSource() }
        function onWeatherSourceChanged() { strip.createWeatherSource() }
    }
    Component.onCompleted: createWeatherSource()

    readonly property var    wx: (weatherDs && weatherDs.data[theme.weatherSource])
                                 ? weatherDs.data[theme.weatherSource] : ({})
    readonly property real   temperature: wx["Temperature"] !== undefined ? Number(wx["Temperature"]) : NaN
    readonly property bool   weatherValid: !isNaN(temperature)

    // ==================================================================
    //  UI
    // ==================================================================
    Row {
        id: stripRow
        anchors.centerIn: parent
        spacing: Math.round(strip.pixelSize * 0.7)

        // ------------------------------------------------------------------
        //  Battery: icon + "82% · Charging"
        // ------------------------------------------------------------------
        Item {
            id: battIcon
            visible: strip.theme.showBattery && strip.hasBattery
            width:  visible ? Math.round(strip.pixelSize * 2.3) : 0
            height: visible ? Math.round(strip.pixelSize * 1.15) : 0

            readonly property int  pad:       Math.max(2, Math.round(strip.pixelSize * 0.12))
            readonly property color rim:      Qt.rgba(1, 1, 1, 0.55)
            readonly property int   nubWidth: Math.max(2, Math.round(height * 0.16))

            // Body outline
            Rectangle {
                id: batBody
                x: 0
                y: 0
                width: battIcon.width - battIcon.nubWidth - 1
                height: battIcon.height
                radius: Math.round(height * 0.24)
                color: "transparent"
                border.color: battIcon.rim
                border.width: Math.max(1, Math.round(strip.pixelSize / 13))
            }
            // Charge fill (clipped inside the outline by padding)
            Rectangle {
                x: batBody.x + battIcon.pad
                y: batBody.y + battIcon.pad
                height: batBody.height - 2 * battIcon.pad
                width: Math.max(0, (batBody.width - 2 * battIcon.pad)
                                 * Math.min(100, Math.max(0, strip.percent)) / 100)
                radius: Math.max(1, batBody.radius - battIcon.pad)
                color: "#f4f4f6"
                opacity: 0.92
            }
            // Positive nub on the right side
            Rectangle {
                x: batBody.width + 1
                y: (battIcon.height - height) / 2
                width: battIcon.nubWidth
                height: Math.round(battIcon.height * 0.36)
                radius: 1.5
                color: battIcon.rim
            }
            // Lightning bolt while charging (drawn once per state change)
            Canvas {
                id: bolt
                visible: strip.charging
                width: Math.round(batBody.height * 0.62)
                height: width
                anchors.centerIn: batBody
                onVisibleChanged: if (visible) requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const w = width, h = height
                    ctx.fillStyle = strip.theme.boltColor
                    ctx.beginPath()
                    ctx.moveTo(0.58 * w, 0.02 * h)
                    ctx.lineTo(0.26 * w, 0.56 * h)
                    ctx.lineTo(0.46 * w, 0.56 * h)
                    ctx.lineTo(0.40 * w, 0.98 * h)
                    ctx.lineTo(0.74 * w, 0.42 * h)
                    ctx.lineTo(0.53 * w, 0.42 * h)
                    ctx.closePath()
                    ctx.fill()
                }
            }
        }

        // Battery text
        Text {
            id: battLabel
            visible: battIcon.visible
            anchors.verticalCenter: parent.verticalCenter
            font.family: strip.theme.textFontFamily
            font.pixelSize: strip.pixelSize
            color: strip.theme.textSecondary
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
            text: {
                if (!visible || strip.percent < 0)
                    return ""
                var s = strip.percent + "%"
                if (strip.charging)     s += " · Charging"
                if (strip.fullyCharged) s += " · Charged"
                return s
            }
        }

        // Dot separator between battery and weather
        Text {
            visible: battIcon.visible && weatherLabel.visible
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: strip.pixelSize
            color: strip.theme.textTertiary
            text: "•"
        }

        // Optional weather text ("21°")
        Text {
            id: weatherLabel
            visible: strip.theme.showWeather && strip.weatherValid
            anchors.verticalCenter: parent.verticalCenter
            font.family: strip.theme.textFontFamily
            font.pixelSize: strip.pixelSize
            color: strip.theme.textSecondary
            renderType: Text.NativeRendering
            textFormat: Text.PlainText
            text: strip.weatherValid ? (Math.round(strip.temperature) + "°") : ""
        }
    }
}
