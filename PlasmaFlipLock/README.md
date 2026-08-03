# PlasmaFlipLock

**Created by Muhammed Salman (CC).** A deliberately small, user-scoped KDE
Plasma 6.7 Look-and-Feel package with a premium flip-clock lock screen.

## What was verified before writing the package

The checkout used for development is a Debian 12 container with no KDE
session, no installed Plasma packages, and none of `plasma-apply-lookandfeel`,
`kpackagetool6`, or `kscreenlocker_greet`. Therefore a live Fedora/Plasma
verification could not be performed here and is not claimed.

The current upstream Plasma 6.7.3 sources were cross-checked online:

- Look-and-Feel packages use root `metadata.json` with
  `"KPackageStructure": "Plasma/LookAndFeel"`, a `KPlugin` object, and
  `"X-Plasma-APIVersion": "2"`.
- The current lockscreen context property is `authenticator`.
- Stock Plasma 6.7 authentication calls
  `authenticator.startAuthenticating()` when the UI is visible and
  `authenticator.respond(password)` for a submitted secret. It listens to
  `onFailed(kind)`, `onSucceeded()`, `onInfoMessageChanged`,
  `onErrorMessageChanged`, `onPromptChanged`, and
  `onPromptForSecretChanged`.
- The current command forms are
  `kpackagetool6 --type Plasma/LookAndFeel --install|--upgrade <directory>`
  and `plasma-apply-lookandfeel --apply <package-id>`; the preview flag is
  `kscreenlocker_greet --testing`. The installer checks `--testing` in the
  target binary's own `--help` output before launching it.

### Important Plasma 6.7 packaging caveat

Upstream Plasma 6.7.3 currently loads the in-session lockscreen from the
active `Plasma/Shell` package (`org.kde.plasma.desktop`), while the global
Look-and-Feel format still defines `contents/lockscreen/LockScreen.qml` for
distros/themes that wire that path. The requested package is kept in the
correct user Look-and-Feel location and is never installed into `/usr/share`.
`install.sh` detects whether the target has a stock Look-and-Feel lockscreen;
it refuses `--apply` when the hook is absent unless
`--allow-unwired` is explicitly supplied. This avoids silently claiming that a
package can replace a greeter path that the target Plasma build does not read.

If the target's live investigation shows only a shell-package lockscreen, the
safe next step is to decide explicitly whether a separate user shell-package
adapter is acceptable. This project does **not** patch the distribution shell
package or silently change the active shell.

## Package layout

```text
PlasmaFlipLock/
├── metadata.json
├── install.sh
├── uninstall.sh
├── README.md
└── contents/lockscreen/
    ├── LockScreen.qml       # greeter entry point and auth presentation glue
    ├── Theme.qml            # design/performance tokens
    ├── AmbientBackground.qml
    ├── AuroraBlob.qml
    ├── FlipClock.qml
    ├── FlipDigit.qml
    ├── FlipHalf.qml
    ├── BatteryStatus.qml
    ├── PasswordField.qml
    └── assets/{lock,arrow}.svg
```

The package has no video, wallpaper bitmap, custom PAM code, verifier, or
password storage.

## Safe install and preview

Run these commands **on the target Plasma session**, not from this checkout's
non-KDE container:

```bash
cd PlasmaFlipLock
chmod +x install.sh uninstall.sh
./install.sh
```

The first command installs/upgrades the package at:

```text
~/.local/share/plasma/look-and-feel/com.muhammedsalman.fedlock/
```

It records the active `LookAndFeelPackage` from `kdeglobals` before the first
installation and prints the exact one-line rollback command. It does not apply
the theme or lock the session.

If the installer reports that a Look-and-Feel lockscreen hook exists, apply it
only after reading the recovery instructions:

```bash
./install.sh --apply
```

The script requires the user to type `APPLY`. Before doing so, know this
recovery route:

1. Switch to a text VT with **Ctrl+Alt+F3** (or F4).
2. Log in and run `loginctl list-sessions`.
3. Run `loginctl unlock-session <id>`; if the greeter itself is wedged, use
   `pkill -x kscreenlocker_greet` and then repair/rollback.

Do **not** use `loginctl lock-session` or Meta+L yet. First preview in the
non-locking test window:

```bash
./install.sh --preview
# equivalent command after the installer verifies it:
kscreenlocker_greet --testing
```

Type the real password in the preview and verify that the stock authenticator
accepts it. Close the preview or press Ctrl+C. Only after this succeeds should
you lock the real session and test one complete type-password/unlock cycle.

`--allow-unwired` exists only for investigation on a Plasma build whose
Look-and-Feel package has no stock lockscreen hook. It does not make upstream
shell-package Plasma 6.7 use this file.

## Updating and reverting

After editing QML, run:

```bash
./install.sh                 # copies and registers an upgrade
./install.sh --preview       # preview again; no real lock
```

The package is not applied automatically on update. Reapply explicitly with
`./install.sh --apply` after checking the preview.

The normal rollback is:

```bash
./uninstall.sh
```

It reapplies the ID recorded before the first Fedlock install and removes only
the user package. The one-line rollback command printed by the installer has
the same form, for example:

```bash
plasma-apply-lookandfeel --apply org.kde.breeze.desktop
```

No `sudo` is used or needed. No system QML file is overwritten.

## Authentication boundary

`LockScreen.qml` does not verify passwords. It only mirrors the current Plasma
6.7 greeter hooks:

```qml
authenticator.startAuthenticating()
authenticator.respond(password)
```

`Connections` handles the stock failure/success and prompt-message signals.
Nonzero `failed(kind)` values are ignored so fingerprint/smart-card events do
not clear or shake a password field. A prompted `onSucceeded()` calls
`Qt.quit()`, which is the greeter's existing successful-unlock path. PAM,
kcheckpass, rate limiting, and the authenticator object are not replaced,
wrapped, or bypassed.

## Performance decisions

- The clock updates once at the minute boundary; it does not run a per-second
  timer. Only changed digits run the split-flap animation.
- Flip faces are flat rectangles. The flap halves use a `Rotation` transform
  and `NumberAnimation`; there is no shader effect in the clock path.
- The ambient base gradient is static. Two modest-size aurora blobs are
  `FastBlur`-cached once with `layer.enabled: true`; the approximately 30 Hz
  timer changes only their position/opacity. There is no live full-screen
  backdrop blur or continuously recomputed frosted effect.
- Ambient motion pauses after three minutes by default (`Theme.qml`), which is
  a deliberate laptop power-saving trade-off. Set `ambientPauseAfterMs` to
  `0` if continuous motion is preferred, accepting the extra wakeups.
- The password focus ring and failed-attempt shake are short, local animations;
  they do not run continuously. The frosted pill is a translucent surface over
  the cached ambient scene, not a per-pixel backdrop blur.
- Theme assets are two tiny SVGs; there is no video or large bitmap texture.

## Files to inspect while troubleshooting

Start with the target machine's own files and output, as requested:

```bash
find /usr/share/plasma/look-and-feel -iname 'LockScreen.qml' -print
find /usr/share/plasma/shells -path '*/contents/lockscreen/LockScreen.qml' -print
plasma-apply-lookandfeel --help
kpackagetool6 --help
kscreenlocker_greet --help
```

Then run the preview with QML diagnostics if needed:

```bash
QT_LOGGING_RULES='*.debug=true' kscreenlocker_greet --testing
```

The command must remain the non-locking `--testing` mode until the preview is
known-good.

## Qt 6 / Material 3 update

The Qt 6 formatting overloads put the locale **before** the format string. All
clock formatting now uses the Qt 6-safe forms:

```qml
Qt.formatTime(currentTime, Qt.locale(), "HH:mm")
Qt.formatDate(currentTime, Qt.locale(), "dddd")
Qt.formatDate(currentTime, Qt.locale(), "d MMMM yyyy")
```

This fixes the `Cannot convert argument 1 ... to QLocale` diagnostics and makes
the digit, weekday, and date bindings render using the session locale. No
Qt 5-only `Qt.format*` argument ordering remains in the package.

The visual layer was also consolidated around Material 3 tokens in `Theme.qml`:
large 28px surfaces, tonal glass containers, Inter/Google Sans fallbacks,
Material-style short easing, a restrained pointer tilt, and cached aurora
parallax. `SystemControls.qml` supplies battery-adjacent keyboard/accessibility
and a power-action affordance. Its sleep/restart/shutdown requests are signals,
not shell commands: a lock theme must never bypass Plasma's host-authorized
power path. Connect them only where the target greeter exposes its approved
power action API.
