#!/usr/bin/env bash
#===============================================================================
#  PlasmaFlipLock — uninstall.sh
#===============================================================================
#  Restores the stock lock screen.
#
#    - system mode install: puts the newest backup of the shell package's
#      original contents/lockscreen back in place (needs the same root
#      privileges with which it was installed).
#    - user mode install:   points plasmashellrc back at the original shell
#      package id and deletes the copied package from ~/.local/share.
#
#  If no backup can be found, it tells you how to restore the files from the
#  distribution package (Fedora: sudo dnf reinstall plasma-desktop).
#===============================================================================
set -euo pipefail

info() { printf '\033[1;34m[i]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[✓]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[✗]\033[0m %s\n' "$*" >&2; exit 1; }

# --- home of the invoking user (sudo-safe) --------------------------------------
INVOKING_HOME="${HOME}"
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    INVOKING_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
fi
STATE_DIR="$INVOKING_HOME/.local/share/plasmafliplock"
MANIFEST="$STATE_DIR/install.manifest"
LATEST_BACKUP_FILE="$STATE_DIR/latest-backup"

MODE=""; SHELL_ID=""; PREV_SHELL_ID=""; PKG_DIR=""; TARGET=""
if [ -f "$MANIFEST" ]; then
    # shellcheck disable=SC1090
    . "$MANIFEST"
    info "Found install record ($MODE mode, installed $([ -n "${DATE:-}" ] && echo "$DATE" || echo 'earlier'))"
else
    warn "No install manifest found — using best-effort defaults."
    SHELL_ID="$(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage 2>/dev/null || true)"
    SHELL_ID="${SHELL_ID:-org.kde.plasma.desktop}"
    MODE="system"
    for cand in \
        "$INVOKING_HOME/.local/share/plasma/shells/$SHELL_ID" \
        /usr/local/share/plasma/shells/"$SHELL_ID" \
        /usr/share/plasma/shells/"$SHELL_ID"; do
        if [ -d "$cand" ]; then PKG_DIR="$cand"; break; fi
    done
    TARGET="$PKG_DIR/contents/lockscreen"
fi

failsafe_hint() {
    cat <<EOF
$(warn) Automatic restore was not possible.
    Restore the stock lock screen from the Fedora package instead:

        sudo dnf reinstall plasma-desktop

    If your session IS CURRENTLY LOCKED with a broken UI:
      1. Switch to a text console:   Ctrl+Alt+F3
      2. Log in, then run:           loginctl unlock-session
      3. Switch back (usually Ctrl+Alt+F2 or F1) and fix the files as above.
EOF
}

#===============================================================================
if [ "$MODE" = "user" ]; then
    #---------------------------------------------------------------------------
    ORIG="${PREV_SHELL_ID:-org.kde.plasma.desktop}"
    info "Restoring shell package pointer: $ORIG"
    kwriteconfig6 --file plasmashellrc --group Shell --key ShellPackage "$ORIG" \
        || die "Could not write plasmashellrc"
    if [ -n "$PKG_DIR" ] && [ -d "$PKG_DIR" ]; then
        case "$PKG_DIR" in
            *.fliplock)
                rm -rf "$PKG_DIR"
                ok "Removed copied package $PKG_DIR"
                ;;
            *)
                warn "Not removing $PKG_DIR (not a .fliplock copy) — inspect manually."
                ;;
        esac
    fi
    rm -f "$MANIFEST"
    ok "Rollback complete. Restart plasmashell (or log out/in) to apply fully."

#===============================================================================
else
    #---------------------------------------------------------------------------
    [ -n "$TARGET" ] || { failsafe_hint; exit 1; }

    BACKUP=""
    if [ -f "$LATEST_BACKUP_FILE" ]; then
        B="$(cat "$LATEST_BACKUP_FILE")"
        [ -d "$B/lockscreen" ] && BACKUP="$B/lockscreen"
    fi
    if [ -z "$BACKUP" ]; then
        # fall back to the newest backup directory we can find
        NEWEST="$(ls -1dt "$STATE_DIR"/backups/*/lockscreen 2>/dev/null | head -n 1 || true)"
        [ -n "$NEWEST" ] && BACKUP="$NEWEST"
    fi
    [ -n "$BACKUP" ] || { failsafe_hint; exit 1; }

    info "Restoring from backup: $BACKUP"
    if [ ! -w "$(dirname "$TARGET")" ]; then
        die "No write permission to $(dirname "$TARGET") — re-run with sudo."
    fi

    rm -rf "$TARGET.fliplock-restore"
    cp -r "$BACKUP" "$TARGET.fliplock-restore"
    rm -rf "$TARGET"
    mv "$TARGET.fliplock-restore" "$TARGET"
    find "$TARGET" -type d -exec chmod 755 {} +
    find "$TARGET" -type f -exec chmod 644 {} +

    rm -f "$MANIFEST"
    ok "Restored $TARGET"
    info "Verify with:  kscreenlocker_greet --testing"
fi
