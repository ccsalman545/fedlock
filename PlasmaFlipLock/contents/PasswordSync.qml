/*
    PlasmaFlipLock — flip-clock lock screen for KScreenLocker (Plasma 6 / Wayland)
    SPDX-License-Identifier: GPL-2.0-or-later

    PasswordSync.qml (QML singleton — see qmldir)
    =============================================
    Multi-monitor glue. On a locked session the greeter creates ONE QQuickView
    per screen, but only the view under the pointer has keyboard focus — so a
    password typed there would not appear in the other views' fields.

    Because every view shares one QML engine (PlasmaQuick::globalEngine), a
    singleton is the perfect shared store: each PasswordPanel binds its text
    to `PasswordSync.password` and pushes its own edits back into it.

    (Identical idea and behaviour as the stock lock screen's PasswordSync.)
*/

pragma Singleton
import QtQuick

QtObject {
    property string password: ""
}
