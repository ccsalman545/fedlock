# PlasmaFlipLock

**Created by Muhammed Salman (CC).** Fedlock is a small, user-scoped KDE
Plasma 6 **Plasma/Shell** package with a mechanical flip clock, an ambient
background, battery status, and a password pill.

## Why this is a Plasma/Shell package

On Plasma 6.7, `kscreenlocker_greet` obtains the lock-screen entry point from
the active shell package (`plasmashellrc`, `[Shell] ShellPackage`). A
`Plasma/LookAndFeel` package is not the lock-screen entry point on that
layout. The original version of this project installed a Look-and-Feel package
and then tried to apply it with `plasma-apply-lookandfeel`; that could make the
package look installed while the greeter continued loading Breeze. Fedlock now
uses the package type that the greeter actually loads:

```text
~/.local/share/plasma/shells/com.muhammedsalman.fedlock/
```

The package contains only `contents/lockscreen/LockScreen.qml` and its local
components. `X-Plasma-FallbackPackage` points to
`org.kde.plasma.desktop`, so the normal desktop shell supplies every shell
file Fedlock does not replace.

This is still a shell-package override. It is intentionally not a global
theme and does not modify `/usr/share`, PAM, kcheckpass, or the system shell.

## Safe install and preview

Run these commands in the target Plasma session:

```bash
cd PlasmaFlipLock
chmod +x install.sh uninstall.sh
./install.sh                 # install/upgrade only; does not select it
./install.sh --apply         # acknowledge recovery instructions, then select it
./install.sh --preview       # non-locking kscreenlocker_greet --testing
```

`--apply` writes only the user setting
`plasmashellrc/[Shell]/ShellPackage`. Before doing so, it records the previous
shell package in `~/.local/state/fedlock/previous-shell`. The installer never
starts a real lock. If a shell restart is needed for the desktop itself,
log out and back in; the next `kscreenlocker_greet` process reads the selected
shell package.

The preview must be run before `Meta+L` or `loginctl lock-session`:

```bash
./install.sh --preview
# equivalent command after --apply:
kscreenlocker_greet --testing
```

If `--preview` is run without `--apply`, it warns and shows whichever shell is
currently active. That is intentional: installing a package must not silently
change the lock screen.

### Recovery route

Before typing `APPLY`, know the escape route if a lock-screen UI is broken:

1. Switch to a text VT with **Ctrl+Alt+F3** (or F4).
2. Log in and run `loginctl list-sessions`.
3. Restore the previous shell with `./uninstall.sh`.
4. If the greeter itself is wedged, use `pkill -x kscreenlocker_greet`, then
   run `loginctl unlock-session <id>` if necessary.

No `sudo` is used or needed.

## Updating and reverting

After changing QML:

```bash
./install.sh
./install.sh --preview
```

The package is not selected automatically during an update. Re-run
`./install.sh --apply` after checking the preview if the selection was removed.

To restore the shell selected before Fedlock and remove the package:

```bash
./uninstall.sh
```

If the user selected another shell after applying Fedlock, `uninstall.sh` does
not overwrite that newer choice; it only removes Fedlock. It removes only the
exact user package directory as a fallback if the KPackage remove operation
fails.

## Authentication boundary

`LockScreen.qml` is presentation glue. It forwards the password to the
`authenticator` object owned by `kscreenlocker`:

```qml
authenticator.startAuthenticating()
authenticator.respond(password)
```

The UI listens to Plasma 6's `onFailed`, `onSucceeded`,
`onInfoMessageChanged`, `onErrorMessageChanged`, `onPromptChanged`, and
`onPromptForSecretChanged` hooks. PAM, rate limiting, password verification,
fingerprint/smart-card handling, and the authenticator object remain owned by
Plasma. No password is stored or compared by this package.

A successful password-authenticated response calls `Qt.quit()` through the
normal greeter path. Passwordless authentication exposes a separate Unlock
button, matching Plasma's current behavior. Failed attempts clear the field
after the authenticator's grace period.

The Sleep affordance delegates to Plasma's `SessionManagement` API. It does
not run a shell command. Unsupported or unconnected power actions are not
shown as clickable controls.

The clock and date use Qt 6's locale object's custom-format overload,
`Qt.locale().toString(value, format)`. This keeps localized weekday and month
names while avoiding the incompatible argument ordering of the global
`Qt.formatDate` and `Qt.formatTime` helpers.

## Performance choices

- The clock updates at the minute boundary; it does not run a per-second timer.
  Only changed digits run the split-flap animation.
- Flip faces are flat rectangles. The flap halves use a `Rotation` transform
  and `NumberAnimation`; there is no shader effect in the clock path.
- The ambient base gradient is static. Two modest cached aurora blobs move at
  approximately 30 Hz, and motion pauses after three minutes by default.
- The password focus ring and failed-attempt shake are short local animations.
  There is no full-screen live backdrop blur.
- Assets are tiny SVGs; there is no video or large bitmap texture.

Set `ambientPauseAfterMs` to `0` in `Theme.qml` if continuous ambient motion is
preferred, accepting the extra wakeups.

## Package layout

```text
PlasmaFlipLock/
├── metadata.json                         # Plasma/Shell package metadata
├── install.sh
├── uninstall.sh
├── README.md
└── contents/lockscreen/
    ├── LockScreen.qml                    # greeter entry point and auth glue
    ├── Theme.qml
    ├── AmbientBackground.qml
    ├── AuroraBlob.qml
    ├── FlipClock.qml
    ├── FlipDigit.qml
    ├── FlipHalf.qml
    ├── BatteryStatus.qml
    ├── PasswordField.qml
    ├── SystemControls.qml
    └── assets/{lock,arrow,eye-open,eye-closed}.svg
```

## Local verification

The repository checkout is not a KDE session, so a live greeter preview cannot
be run here. Validate the package on the target machine with:

```bash
find /usr/share/plasma/shells -path '*/contents/lockscreen/LockScreen.qml' -print
kpackagetool6 --help
kscreenlocker_greet --help
kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage
```

The installer checks the package type, install/upgrade support, package files,
and the greeter's `--testing` flag before performing the corresponding action.
