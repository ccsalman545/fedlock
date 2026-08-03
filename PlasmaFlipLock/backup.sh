#!/usr/bin/env bash
#===============================================================================
#  PlasmaFlipLock — backup.sh
#===============================================================================
#  Creates a timestamped backup of the CURRENT lock screen QML (the
#  lockscreen directory of the active Plasma shell package) plus the relevant
#  user configuration, so PlasmaFlipLock can be cleanly rolled back at any
#  time — even after a Fedora upgrade replaced package files.
#
#  Usage:
#     ./backup.sh                     # backup active shell package's lockscreen
#     ./backup.sh /path/to/lockscreen # backup an explicit directory
#
#  Backups go to:  ~/.local/share/plasmafliplock/backups/<timestamp>/
#
#  Nothing is modified — this script only READS system files and WRITES to
#  the user's home directory.
#===============================================================================
set -euo pipefail

STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/plasmafliplock"
BACKUP_ROOT="$STATE_DIR/backups"

# --- tiny logging helpers -----------------------------------------------------
info() { printf '\033[1;34m[i]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[!]\033[0m %s\n' "$*" >&2; }

# --- where is the active shell package? --------------------------------------
detect_lockscreen_dir() {
    local shell_id pkg_dir
    shell_id="$(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage 2>/dev/null || true)"
    shell_id="${shell_id:-org.kde.plasma.desktop}"
    for pkg_dir in \
        "$HOME/.local/share/plasma/shells/$shell_id" \
        /usr/local/share/plasma/shells/"$shell_id" \
        /usr/share/plasma/shells/"$shell_id"; do
        if [ -d "$pkg_dir" ]; then
            printf '%s\n' "$pkg_dir/contents/lockscreen"
            return 0
        fi
    done
    return 1
}

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
    TARGET="$(detect_lockscreen_dir)" || {
        err "Could not locate the active shell package (plasmashellrc [Shell] ShellPackage)."
        exit 1
    }
fi

if [ ! -d "$TARGET" ]; then
    err "Nothing to back up: '$TARGET' does not exist."
    exit 1
fi

TS="$(date +%Y%m%d-%H%M%S)"
DEST="$BACKUP_ROOT/$TS"
mkdir -p "$DEST"

cp -a "$TARGET" "$DEST/lockscreen"

# Config that may matter for rollback debugging / restoration.
[ -f "$HOME/.config/plasmashellrc" ]   && cp -a "$HOME/.config/plasmashellrc"   "$DEST/" || true
[ -f "$HOME/.config/kscreenlockerrc" ] && cp -a "$HOME/.config/kscreenlockerrc" "$DEST/" || true

cat > "$DEST/INFO" <<EOF
PlasmaFlipLock backup
created : $(date -Is)
target  : $TARGET
host    : $(hostname 2>/dev/null || echo unknown)
plasma  : $(plasmashell --version 2>/dev/null || echo unknown)
EOF

# keep the newest path in a stable place for uninstall.sh
mkdir -p "$STATE_DIR"
printf '%s\n' "$DEST" > "$STATE_DIR/latest-backup"

info "Backup created:"
info "  $DEST"
info "(contains: lockscreen/ + plasmashellrc/kscreenlockerrc if present)"
