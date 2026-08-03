/*
    PlasmaFlipLock — flip-clock lock screen for KScreenLocker (Plasma 6 / Wayland)
    SPDX-License-Identifier: GPL-2.0-or-later

    Theme.qml
    =========
    Central design-token store. Everything visual (colors, sizes, motion
    timings) and every user-facing feature toggle lives here so the whole
    lock screen reads consistently and can be re-themed from ONE file.

    How it is used:
      - LockScreenUi.qml instantiates this once and injects it into every
        child component (FlipClock, FlipDigit, BatteryWidget, PasswordPanel).
      - The most common settings can ALSO be overridden without editing files,
        via kscreenlockerrc "[Greeter][LnF]" keys (see config/main.xml and
        LockScreenUi.qml; `applyConfigOverrides()` there). Per-user override
        example:
            kwriteconfig6 --file kscreenlockerrc --group Greeter \
                          --group LnF --key showWeather true

    NOTE: This is an INSTANTIABLE QtObject (not a pragma-singleton) so the
    lock screen QML stays a plain directory copy of files — nothing needs to
    be registered in a QML import path.
*/

import QtQuick

QtObject {
    id: theme

    // ==================================================================
    //  LAYOUT  (all "factor" values are fractions of the screen height,
    //  so 1920x1080 and 1366x768 land on the same proportions)
    // ==================================================================

    // Clock: occupies ~45 % of the screen height as requested.
    //   1080p:  0.45 * 1080 = 486 px card height
    //   768p:   0.45 *  768 = 346 px card height
    property real clockHeightFactor: 0.45

    // Optional user multiplier (0.75 … 1.2). Also overridable via config.
    property real clockScale: 1.0

    // Digit glyph size relative to card height.
    //   1080p: 486 * 0.5 = 243 px  ≈ the requested ~240 px tall digits.
    property real digitScale: 0.50

    // Card width / card height. Flip-clock cards are taller than wide.
    property real cardAspect: 0.72

    // Width of the ":" separator cell relative to card height.
    property real colonWidthFactor: 0.26

    // Gap between cards relative to card height.
    property real gapFactor: 0.055

    // Corner rounding of the flip cards (px at 1080p, scaled with cards).
    property real cardRadiusFactor: 0.045      // * cardHeight  (≈ 22 px at 1080p)

    // Text blocks under the clock, as fractions of screen height.
    property real dayNameFactor: 0.032         // "TUESDAY"          ≈ 34 px @1080p
    property real dateFactor:    0.023         // "3 August 2026"    ≈ 25 px @1080p
    property real statusFactor:  0.018         // battery / weather  ≈ 19 px @1080p

    // ==================================================================
    //  COLORS — monochrome "black card / white digit" Fliqlo look
    // ==================================================================

    // Flip card face (near-black with a faint vertical sheen).
    property color cardColorTop:    "#242428"
    property color cardColorMid:    "#131316"
    property color cardColorBottom: "#0a0a0c"
    property color seamColor:       "#000000"   // the horizontal hinge line
    property color digitColor:      "#f4f4f6"   // the flip glyphs

    // Text outside the cards. Alpha-tuned white for a premium layered look.
    property color textPrimary:   "#ffffff"
    property color textSecondary: Qt.rgba(1, 1, 1, 0.72)
    property color textTertiary:  Qt.rgba(1, 1, 1, 0.48)

    // Accent (used sparingly: charging bolt, focused login button ring).
    property color accent: "#8ab4ff"     // soft glass-blue
    property color boltColor: "#ffc14d"  // charging ⚡
    property color danger: "#ff6b5e"     // failed-attempt hint

    // Dim layer painted over the (blurred) wallpaper so the clock pops.
    property color dimColor: Qt.rgba(0, 0, 0, 0.42)
    // Extra vignette edge dim.
    property color vignetteColor: Qt.rgba(0, 0, 0, 0.55)

    // ==================================================================
    //  GLASS (password panel)
    // ==================================================================
    // The panel is translucent and floats over the *already blurred*
    // wallpaper below, which is what produces the frosted-glass effect
    // (true per-pixel backdrop blur at this spot would render the exact
    // same blurred wallpaper + tint — visually identical, but heavier).
    property real  glassOpacity:       0.16   // white fill alpha
    property real  glassBorderOpacity: 0.30   // 1 px rim highlight alpha
    property color glassTint: "#ffffff"
    property real  panelHeightPx: 62          // px at 1080p (scaled by screen)
    property real  panelRadiusFactor: 0.5     // 0.5 * height → perfect pill

    // ==================================================================
    //  MOTION — timings are tuned to feel mechanical but quick.
    //  "No unnecessary animations": fade-in once, flip only on change.
    // ==================================================================
    property int flipDuration:    560        // total flip ms (2 phases)
    property int fadeInDuration:  750        // whole-screen fade on lock
    property int panelFadeDelay:  200        // panel fades slightly after bg
    property int panelFadeDuration: 550
    property int rejectShakeDuration: 320    // failed-password shake

    // ==================================================================
    //  FEATURES / SETTINGS (each overrideable from kscreenlockerrc —
    //  see contents/config/main.xml)
    // ==================================================================
    property bool   showBattery: true
    property bool   showWeather: false        // opt-in per requirements
    // Weather dataengine source string, "" = disabled. Format "provider|City",
    // e.g. "bbcukmet|London", "noaa|New York". To find a valid source string,
    // add the Weather Report widget on the desktop and configure a location
    // once — the same engine config applies here.
    property string weatherSource: ""
    property bool   blurWallpaper: true       // GPU blur of lock-screen wallpaper

    // ==================================================================
    //  FONTS
    // ==================================================================
    // The bundled Bebas Neue (SIL OFL, contents/assets/fonts) gives the
    // tall, condensed numerals that make the Fliqlo look work. LockScreenUi
    // resolves this at runtime and falls back gracefully if the font file
    // is missing: Oswald → system font, slightly bolder to compensate.
    property string digitFontFamily: "Bebas Neue"
    property string textFontFamily: ""        // "" → whatever the OS gives us

    // Derived helper: seam thickness relative to card height.
    property real seamFactor: 0.007           // ≈ 3 px at 1080p
}
