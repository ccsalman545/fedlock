# fedlock — PlasmaFlipLock

A user-scoped KDE Plasma 6.7 Look-and-Feel KPackage by **Muhammed Salman
(CC)**. It provides a premium mechanical flip clock, an inexpensive teal/navy/
purple ambient background, battery status, and a frosted password pill while
leaving kscreenlocker's authentication backend untouched.

See [`PlasmaFlipLock/README.md`](PlasmaFlipLock/README.md) for the live-machine
investigation, package layout, safe install/preview workflow, rollback, and
performance notes.

```bash
cd PlasmaFlipLock
./install.sh                 # install/upgrade only; does not apply
./install.sh --apply         # explicit safety acknowledgement, then apply
./install.sh --preview       # non-locking kscreenlocker_greet --testing
```

The repository's current checkout is not a KDE session, so no live lock-screen
preview was run here. Run the commands above on the target Fedora Plasma
machine after the installer has verified its local APIs and flags.
