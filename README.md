# fedlock

`PlasmaFlipLock/` contains Fedlock, a user-scoped KDE Plasma 6 lock-screen
package with a restrained mechanical flip clock and ambient background.

Fedlock is packaged as `Plasma/Shell`, because Plasma 6.7's
`kscreenlocker_greet` loads the lock screen from the active shell package. It
is not a `Plasma/LookAndFeel` package and it does not use
`plasma-apply-lookandfeel`.

```bash
cd PlasmaFlipLock
./install.sh                 # install/upgrade only; does not activate
./install.sh --apply         # confirm recovery instructions, then activate
./install.sh --preview       # non-locking kscreenlocker_greet --testing
./uninstall.sh               # restore the previous shell and remove Fedlock
```

The installer is designed for the target KDE Plasma session. It installs to
`~/.local/share/plasma/shells/`, writes the user `plasmashellrc` shell setting
only after explicit confirmation, and never modifies system files or the PAM
authentication backend.

The repository checkout is not a KDE session, so no live lock-screen preview
was run here. See [`PlasmaFlipLock/README.md`](PlasmaFlipLock/README.md) for
packaging details, authentication boundaries, recovery instructions, and
performance notes.
