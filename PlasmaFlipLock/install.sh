#!/usr/bin/env bash
#===============================================================================
#  PlasmaFlipLock — install.sh
#===============================================================================
#  Installs the PlasmaFlipLock flip-clock lock screen for KDE Plasma 6.
#
#  Two modes:
#
#   DEFAULT / --system   Patches the lockscreen contents inside the ACTIVE
#                        Plasma shell package (usually
#                        /usr/share/plasma/shells/org.kde.plasma.desktop/
#                        contents/lockscreen). The stock files are backed up
#                        first and can be restored with uninstall.sh.
#                        Authentication (PAM/kcheckpass) is NOT touched —
#                        only QML files are replaced.
#                        Needs write access to /usr/share → run with sudo.
#
#   --user               Zero-system-touch mode: copies the whole shell
#                        package to ~/.local/share/plasma/shells/<id>.fliplock,
#                        replaces only its contents/lockscreen, and points
#                        plasmashellrc [Shell] ShellPackage at the copy.
#                        NOTE: the desktop shell will use the copied package
#                        after the next plasmashell restart — the copy is
#                        identical to the original except for the lockscreen,
#                        so the desktop looks and behaves the same.
#
#  Rollback: ./uninstall.sh    (restores the newest backup / the old shell id)
#
#  Test before locking for real:
#     kscreenlocker_greet --testing
#===============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
SRC_DIR="$SCRIPT_DIR/contents"
MODE="system"
FORCE_SHELL_ID=""

# --- logging ------------------------------------------------------------------
info() { printf '\033[1;34m[i]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[✓]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[✗]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: $0 [--system] [--user] [--shell <package-id>]
  --system          Patch the active shell package in place (default).
  --user            Rootless: install a copied shell package in ~/.local/share
                    and point plasmashellrc at it.
  --shell <id>      Override the detected shell package id (default: value of
                    plasmashellrc [Shell] ShellPackage, else org.kde.plasma.desktop).
EOF
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --system) MODE="system" ;;
        --user)   MODE="user" ;;
        --shell)  shift; FORCE_SHELL_ID="${1:-}" ;;
        -h|--help) usage ;;
        *) die "Unknown option: $1 (try --help)" ;;
    esac
    shift
done

# --- home of the invoking user, even when run through sudo --------------------
INVOKING_HOME="${HOME}"
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    INVOKING_HOME="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
fi
STATE_DIR="$INVOKING_HOME/.local/share/plasmafliplock"
mkdir -p "$STATE_DIR"

[ -f "$SRC_DIR/LockScreen.qml" ]    || die "contents/LockScreen.qml missing — run this from the PlasmaFlipLock directory."
[ -f "$SRC_DIR/LockScreenUi.qml" ]  || die "contents/LockScreenUi.qml missing — incomplete package?"

# --- 1) detect the shell package ----------------------------------------------
SHELL_ID="${FORCE_SHELL_ID}"
if [ -z "$SHELL_ID" ]; then
    SHELL_ID="$(kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage 2>/dev/null || true)"
fi
SHELL_ID="${SHELL_ID:-org.kde.plasma.desktop}"
info "Active shell package id: $SHELL_ID"

PKG_DIR=""
for cand in \
    "$INVOKING_HOME/.local/share/plasma/shells/$SHELL_ID" \
    /usr/local/share/plasma/shells/"$SHELL_ID" \
    /usr/share/plasma/shells/"$SHELL_ID"; do
    if [ -d "$cand" ]; then PKG_DIR="$cand"; break; fi
done
[ -n "$PKG_DIR" ] || die "Shell package '$SHELL_ID' not found in the standard kpackage roots."
info "Package path: $PKG_DIR"

TARGET="$PKG_DIR/contents/lockscreen"

# --- 2) sanity: Plasma 6 + kscreenlocker ---------------------------------------
if ! command -v kwriteconfig6 >/dev/null 2>&1; then
    warn "kwriteconfig6 not found — is this really KDE Plasma 6?"
fi
GREETER_BIN="$(command -v kscreenlocker_greet 2>/dev/null || true)"
[ -z "$GREETER_BIN" ] && GREETER_BIN="/usr/libexec/kscreenlocker_greet"
[ -x "$GREETER_BIN" ] || warn "kscreenlocker_greet not found in PATH — testing instructions may need the full path ($GREETER_BIN)."

#===============================================================================
install_files_into() {
    # $1 = destination lockscreen dir. Installs our contents there atomically.
    local dest="$1"
    local parent; parent="$(dirname "$dest")"
    local staging="$parent/.lockscreen.plasmafliplock.new"
    local olddir="$parent/.lockscreen.plasmafliplock.old"

    rm -rf "$staging" "$olddir"
    mkdir -p "$staging"
    cp -r "$SRC_DIR/." "$staging/"

    # predictable permissions, world-readable, no exec bits
    find "$staging" -type d -exec chmod 755 {} +
    find "$staging" -type f -exec chmod 644 {} +

    if [ -d "$dest" ]; then
        mv "$dest" "$olddir"
    fi
    mv "$staging" "$dest"
    rm -rf "$olddir"
}

#===============================================================================
if [ "$MODE" = "system" ]; then
    #---------------------------------------------------------------------------
    info "Mode: system (patch the active shell package)"
    if [ ! -w "$PKG_DIR/contents" ]; then
        die "No write permission to $PKG_DIR — re-run as root:  sudo $0"
    fi

    # fresh backup (always, even if one exists)
    "$SCRIPT_DIR/backup.sh" "$TARGET"

    install_files_into "$TARGET"
    ok "PlasmaFlipLock installed into $TARGET"

    cat > "$STATE_DIR/install.manifest" <<EOF
MODE=system
SHELL_ID=$SHELL_ID
PKG_DIR=$PKG_DIR
TARGET=$TARGET
DATE=$(date -Is)
EOF
    # clean up legacy state of the other mode (if any)
    rm -f "$STATE_DIR/user-mode-shell-id" 2>/dev/null || true

#===============================================================================
else   # --user mode ------------------------------------------------------------
    #---------------------------------------------------------------------------
    info "Mode: user (rootless copy of the shell package)"
    CUSTOM_ID="${SHELL_ID}.fliplock"
    DEST="$INVOKING_HOME/.local/share/plasma/shells/$CUSTOM_ID"

    # If the *source* package is our own previous copy, re-copy from a
    # pristine system package to avoid compounding edits.
    SRC_PKG="$PKG_DIR"
    case "$PKG_DIR" in
        *.fliplock)
            warn "Current shell package is already a .fliplock copy."
            BASE_ID="${SHELL_ID%.fliplock}"
            for cand in /usr/local/share/plasma/shells/"$BASE_ID" \
                        /usr/share/plasma/shells/"$BASE_ID"; do
                if [ -d "$cand" ]; then SRC_PKG="$cand"; break; fi
            done
            CUSTOM_ID="$SHELL_ID"
            DEST="$INVOKING_HOME/.local/share/plasma/shells/$CUSTOM_ID"
            ;;
    esac

    info "Copying $SRC_PKG → $DEST"
    rm -rf "$DEST"
    mkdir -p "$(dirname "$DEST")"
    cp -r "$SRC_PKG" "$DEST"

    # give the copy its own package id so both can coexist
    if [ -f "$DEST/metadata.json" ] && command -v python3 >/dev/null 2>&1; then
        SHELL_ID="$CUSTOM_ID" python3 - "$DEST/metadata.json" <<'PY'
import json, os, sys
p = sys.argv[1]
m = json.load(open(p))
m.setdefault("KPlugin", {})["Id"] = os.environ["SHELL_ID"]
json.dump(m, open(p, "w"), indent=4, ensure_ascii=False)
PY
    fi

    install_files_into "$DEST/contents/lockscreen"
    ok "PlasmaFlipLock contents installed into $DEST/contents/lockscreen"

    kwriteconfig6 --file plasmashellrc --group Shell --key ShellPackage "$CUSTOM_ID"
    ok "plasmashellrc [Shell] ShellPackage = $CUSTOM_ID"

    cat > "$STATE_DIR/install.manifest" <<EOF
MODE=user
SHELL_ID=$CUSTOM_ID
PREV_SHELL_ID=${SHELL_ID%.fliplock}
PKG_DIR=$DEST
TARGET=$DEST/contents/lockscreen
DATE=$(date -Is)
EOF

    warn "The desktop shell will pick up the copied package after the next"
    warn "plasmashell restart (its contents are identical except the lock screen)."
    warn "The NEW LOCK SCREEN works immediately — no restart needed for it."
fi

#===============================================================================
cat <<EOF

$(ok) Done.
─────────────────────────────────────────────────────────────────────────────
 TEST IT NOW (does not lock your session):

     kscreenlocker_greet --testing

   A window with the new lock screen opens. Type your real password and hit
   Enter to confirm it unlocks (or simply close the window).
   To test against a specific package copy instead:
     kscreenlocker_greet --testing --shell $SHELL_ID

 Then lock normally (Meta+L / Leave→Lock). Roll back any time with:

     $SCRIPT_DIR/uninstall.sh
─────────────────────────────────────────────────────────────────────────────
EOF
