#!/usr/bin/env bash
# Install or upgrade the user-scoped Fedlock Plasma/Shell package.
#
# Plasma 6.7 loads the lock screen from the active Plasma/Shell package, not
# from a Plasma/LookAndFeel package.  Installing is deliberately separate from
# selecting the shell package:
#
#   ./install.sh                 # install/upgrade, do not select it
#   ./install.sh --apply         # confirm recovery instructions, then select it
#   ./install.sh --preview       # run kscreenlocker_greet --testing
#   ./install.sh --apply --preview
#
# Created by Muhammed Salman (CC).
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PACKAGE_ID="com.muhammedsalman.fedlock"
readonly PACKAGE_TYPE="Plasma/Shell"
readonly DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly PACKAGE_ROOT="$DATA_HOME/plasma/shells"
readonly PACKAGE_DIR="$PACKAGE_ROOT/$PACKAGE_ID"
readonly STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/fedlock"
readonly STATE_FILE="$STATE_ROOT/previous-shell"
readonly SOURCE_DIR="$SCRIPT_DIR"
readonly DEFAULT_SHELL="org.kde.plasma.desktop"

apply_shell=0
preview=0

info() { printf '\033[1;34m[i]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[✓]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[✗]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Install or upgrade the user-scoped Fedlock Plasma/Shell package. With no
option this does not change the active shell package.

Options:
  --apply            After installing, interactively confirm recovery knowledge
                     and select Fedlock for the lock-screen shell.
  --preview          Run the verified kscreenlocker_greet --testing preview.
  -h, --help         Show this help.

Safe workflow:
  ./install.sh
  ./install.sh --apply
  ./install.sh --preview
  # only after the preview works: lock normally

The active shell setting is stored in plasmashellrc. The installer records its
previous value only when --apply is confirmed; ./uninstall.sh restores it if
Fedlock is still selected.
EOF
}

while (($#)); do
    case "$1" in
        --apply)   apply_shell=1 ;;
        --preview) preview=1 ;;
        -h|--help) usage; exit 0 ;;
        *)          die "Unknown option '$1' (use --help)." ;;
    esac
    shift
done

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_command kpackagetool6
require_command kreadconfig6
kpackage_help="$(kpackagetool6 --help 2>&1 || true)"
grep -q -- '--type' <<<"$kpackage_help" || die "kpackagetool6 --help did not advertise --type"
grep -q -- '--install' <<<"$kpackage_help" || die "kpackagetool6 --help did not advertise --install"
grep -q -- '--upgrade' <<<"$kpackage_help" || die "kpackagetool6 --help did not advertise --upgrade"

if ((apply_shell)); then
    require_command kwriteconfig6
fi

validate_source() {
    [[ -f "$SOURCE_DIR/metadata.json" ]] || die "metadata.json is missing."
    [[ -f "$SOURCE_DIR/contents/lockscreen/LockScreen.qml" ]] || die "contents/lockscreen/LockScreen.qml is missing."
    grep -Eq '"KPackageStructure"[[:space:]]*:[[:space:]]*"Plasma/Shell"' "$SOURCE_DIR/metadata.json" \
        || die "metadata.json is not a Plasma/Shell package."
    grep -Eq '"X-Plasma-FallbackPackage"[[:space:]]*:[[:space:]]*"org\.kde\.plasma\.desktop"' "$SOURCE_DIR/metadata.json" \
        || die "metadata.json must fall back to org.kde.plasma.desktop."
    [[ "$SOURCE_DIR" != "$PACKAGE_DIR" ]] || die "Run this script from the source checkout, not the installed package."
}
validate_source

has_graphical_session() {
    [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" || \
       "${XDG_SESSION_TYPE:-}" == "wayland" || "${XDG_SESSION_TYPE:-}" == "x11" ]]
}

require_graphical_session() {
    has_graphical_session && return 0
    warn "No graphical session was detected. This action is intended for a KDE session."
    die "Run --apply/--preview from the target Plasma session."
}

read_active_shell() {
    kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage 2>/dev/null || true
}

is_package_id() {
    [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]
}

read_previous_shell() {
    [[ -f "$STATE_FILE" ]] || return 0
    sed -n 's/^PREVIOUS_ID=//p' "$STATE_FILE" | head -n 1
}

record_previous_shell() {
    local previous_id="$1"
    mkdir -p "$STATE_ROOT"
    umask 077
    cat >"$STATE_FILE" <<EOF
PREVIOUS_ID=$previous_id
PACKAGE_ID=$PACKAGE_ID
PACKAGE_TYPE=$PACKAGE_TYPE
PACKAGE_DIR=$PACKAGE_DIR
RECORDED_AT=$(date -Is)
EOF
}

locate_greeter() {
    local greeter_bin
    greeter_bin="$(command -v kscreenlocker_greet 2>/dev/null || true)"
    if [[ -n "$greeter_bin" ]]; then
        printf '%s\n' "$greeter_bin"
        return 0
    fi

    local greeter_root
    for greeter_root in /usr/libexec /usr/lib /usr/lib64 /libexec; do
        [[ -d "$greeter_root" ]] || continue
        greeter_bin="$(find "$greeter_root" -maxdepth 3 -type f -name kscreenlocker_greet -perm -111 -print -quit 2>/dev/null || true)"
        if [[ -n "$greeter_bin" ]]; then
            printf '%s\n' "$greeter_bin"
            return 0
        fi
    done
    return 1
}

install_package() {
    mkdir -p "$PACKAGE_ROOT"
    [[ ! -L "$PACKAGE_DIR" ]] || die "Refusing to use a symlink at $PACKAGE_DIR."
    if [[ -d "$PACKAGE_DIR" ]]; then
        if kpackagetool6 --type "$PACKAGE_TYPE" --upgrade "$SOURCE_DIR"; then
            ok "Upgraded $PACKAGE_ID"
        else
            warn "Upgrade was not registered; trying a fresh package install."
            kpackagetool6 --type "$PACKAGE_TYPE" --install "$SOURCE_DIR"
            ok "Installed $PACKAGE_ID"
        fi
    else
        kpackagetool6 --type "$PACKAGE_TYPE" --install "$SOURCE_DIR"
        ok "Installed $PACKAGE_ID"
    fi

    [[ -f "$PACKAGE_DIR/metadata.json" ]] \
        || die "kpackagetool6 did not install the package at $PACKAGE_DIR."
    [[ -f "$PACKAGE_DIR/contents/lockscreen/LockScreen.qml" ]] \
        || die "The installed package is missing its lock-screen entry point."
}

install_package

printf '\nInstalled shell package:\n  %s\n' "$PACKAGE_DIR"
printf 'Fallback shell package: %s\n' "$DEFAULT_SHELL"
printf 'Rollback/removal:\n  %s/uninstall.sh\n' "$SCRIPT_DIR"
printf 'Preview (non-locking; do this before any real lock):\n  kscreenlocker_greet --testing\n\n'

if ((apply_shell)); then
    require_graphical_session
    if [[ ! -t 0 ]]; then
        die "--apply requires an interactive terminal so recovery instructions are acknowledged."
    fi

    cat <<'EOF'
Fedlock is a Plasma/Shell package. Selecting it changes the shell package
setting in plasmashellrc; it does not replace PAM or store a password. If the
lock-screen UI is broken, switch to Ctrl+Alt+F3 (or F4), log in, identify the
session with loginctl list-sessions, then run loginctl unlock-session <id>. If
necessary, restore the previous shell with ./uninstall.sh and kill only the
offending greeter with pkill -x kscreenlocker_greet.

Preview with kscreenlocker_greet --testing before using Meta+L or
loginctl lock-session.
EOF
    printf 'Type APPLY to continue: '
    read -r confirmation
    [[ "$confirmation" == "APPLY" ]] || die "Not applied. The package remains installed for preview or later use."

    previous_id="$(read_previous_shell)"
    if [[ -z "$previous_id" ]]; then
        previous_id="$(read_active_shell)"
        [[ -n "$previous_id" ]] || previous_id="${PLASMA_DEFAULT_SHELL:-$DEFAULT_SHELL}"
        is_package_id "$previous_id" || die "The current ShellPackage value is not a valid package ID."
        [[ "$previous_id" != "$PACKAGE_ID" ]] || die "Fedlock is already selected but no rollback record exists."
        record_previous_shell "$previous_id"
        info "Recorded previous shell package: $previous_id"
    else
        is_package_id "$previous_id" || die "Rollback record contains an invalid package ID."
        [[ "$previous_id" != "$PACKAGE_ID" ]] || die "Rollback record points at Fedlock itself; refusing to apply."
        info "Keeping previously recorded rollback package: $previous_id"
    fi

    kwriteconfig6 --file plasmashellrc --group Shell --key ShellPackage "$PACKAGE_ID"
    [[ "$(read_active_shell)" == "$PACKAGE_ID" ]] \
        || die "Could not select $PACKAGE_ID in plasmashellrc."
    ok "Selected $PACKAGE_ID for the Plasma lock-screen shell."
    info "The next kscreenlocker_greet process will use Fedlock; no real lock was started."
fi

if ((preview)); then
    require_graphical_session
    greeter_bin="$(locate_greeter || true)"
    [[ -n "$greeter_bin" ]] || die "Could not locate kscreenlocker_greet."
    greeter_help="$("$greeter_bin" --help 2>&1 || true)"
    grep -q -- '--testing' <<<"$greeter_help" \
        || die "This kscreenlocker_greet does not advertise --testing; refusing to launch a preview."

    if [[ "$(read_active_shell)" != "$PACKAGE_ID" ]]; then
        warn "Fedlock is not the active ShellPackage; this preview will use the active shell."
        warn "Run ./install.sh --apply first if you want to preview Fedlock."
    fi
    info "Launching the non-locking preview. Close the window or press Ctrl+C to exit."
    "$greeter_bin" --testing
fi
