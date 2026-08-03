/*
    PlasmaFlipLock — flip-clock lock screen for KScreenLocker (Plasma 6 / Wayland)
    SPDX-License-Identifier: GPL-2.0-or-later

    LockScreen.qml  —  ENTRY POINT
    ==============================
    kscreenlocker_greet resolves the lock screen through the "lockscreenmainscript"
    definition of the active Plasma shell package, which maps to:
        <shell package>/contents/lockscreen/LockScreen.qml
    (see libplasma: src/plasma/packagestructure/shell/shellpackage.cpp)

    Root-object contract expected by the greeter (greeterapp.cpp):
        - view->rootObject() gets QQmlProperty writes for:
              "locked"      — true once the lock is fully engaged
              "viewVisible" — true right after the first frame hit the screen
        - if THIS file fails to load, the greeter falls back to its built-in
          emergency lock screen (qrc:/fallbacktheme/LockScreen.qml), so a
          broken edit never locks you out of unlocking.
        - the (optional) wallpaper item is parented to THIS item at z = -1000
          and anchored to fill it.

    This wrapper keeps the exact property names the stock lock screen uses so
    external tooling keeps working, and forwards everything into LockScreenUi.
*/

import QtQuick

Item {
    id: lockScreenRoot

    // ---- properties written by kscreenlocker_greet --------------------------
    property bool viewVisible: false      // set true after the first swapped frame
    property bool locked: false           // set true when the lock is engaged
    property bool debug: false            // kscreenlocker tooling convention

    // ---- stock lock screen compatibility surface ----------------------------
    property alias notification: lockUi.notification
    signal clearPassword()
    signal notificationRepeated()

    implicitWidth: 800    // only used when shown in a window (testing)
    implicitHeight: 600

    // RTL support identical to upstream
    LayoutMirroring.enabled: Application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    LockScreenUi {
        id: lockUi
        anchors.fill: parent

        // The whole UI keys its entrance animation off this.
        viewVisible: lockScreenRoot.viewVisible || lockScreenRoot.debug
    }

    // Bubble the repeated-notification event up to external listeners.
    Connections {
        target: lockUi
        function onNotificationRepeated() {
            lockScreenRoot.notificationRepeated()
        }
    }

    onClearPassword: lockUi.resetExternal()
}
