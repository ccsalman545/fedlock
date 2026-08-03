# fedlock — PlasmaFlipLock

A complete custom KDE Plasma 6 lock screen (KScreenLocker) for Fedora 44 /
Wayland: blurred wallpaper, a huge Fliqlo-style flip clock, date, battery
status, and a glassmorphism password panel — on top of KDE's untouched
authentication backend.

**Everything lives in [`PlasmaFlipLock/`](PlasmaFlipLock/) — see
[`PlasmaFlipLock/README.md`](PlasmaFlipLock/README.md)** for features,
installation (`sudo ./install.sh`), testing
(`kscreenlocker_greet --testing`), configuration and rollback.

Quick start:

```bash
cd PlasmaFlipLock
chmod +x install.sh
sudo ./install.sh
kscreenlocker_greet --testing
```
