#!/usr/bin/env bash
# Install or upgrade the user-scoped Fedlock Plasma/LookAndFeel package.
#
# The default action only installs/registers the package. Applying a global
# theme and starting the non-locking greeter preview are explicit actions:
#
#   ./install.sh                 # install/upgrade, do not apply
#   ./install.sh --apply         # confirm recovery knowledge, then apply
#   ./install.sh --preview       # run kscreenlocker_greet --testing
#   ./install.sh --apply --preview
#
# Created by Muhammed Salman (CC).
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly PACKAGE_ID="com.muhammedsalman.fedlock"
readonly PACKAGE_TYPE="Plasma/LookAndFeel"
readonly DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly PACKAGE_ROOT="$DATA_HOME/plasma/look-and-feel"
readonly PACKAGE_DIR="$PACKAGE_ROOT/$PACKAGE_ID"
readonly STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/fedlock"
readonly STATE_FILE="$STATE_ROOT/previous-look-and-feel"
readonly SOURCE_DIR="$SCRIPT_DIR"

apply_theme=0
preview=0
allow_unwired=0

info() { printf '\033[1;34m[i]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[✓]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[✗]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Install or upgrade the user-scoped Fedlock KPackage. With no option this does
not change the active theme.

Options:
  --apply            After installing, interactively confirm recovery knowledge
                     and apply com.muhammedsalman.fedlock.
  --preview          Run the verified kscreenlocker_greet --testing preview.
  --allow-unwired    Permit --apply when this distro has no stock
                     contents/lockscreen/LockScreen.qml in a Look-and-Feel
                     package. This is only for investigation; Plasma 6.7's
                     upstream shell-package layout may ignore this package.
  -h, --help         Show this help.

Safe workflow:
  ./install.sh
  ./install.sh --apply
  ./install.sh --preview
  # only after the preview works: lock normally
EOF
}

while (($#)); do
    case "$1" in
        --apply)         apply_theme=1 ;;
        --preview)       preview=1 ;;
        --allow-unwired) allow_unwired=1 ;;
        -h|--help)       usage; exit 0 ;;
        *)               die "Unknown option '$1' (use --help)." ;;
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
if ((apply_theme)); then
    require_command plasma-apply-lookandfeel
    plasma_help="$(plasma-apply-lookandfeel --help 2>&1 || true)"
    grep -q -- '--apply' <<<"$plasma_help" || die "plasma-apply-lookandfeel --help did not advertise --apply"
fi

if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" && ("${XDG_SESSION_TYPE:-}" != "wayland") ]]; then
    warn "No graphical session was detected. This script is intended for the target KDE session."
    warn "Nothing has been applied; run it from the Fedora Plasma 6.7 session."
    exit 2
fi

if [[ ! -f "$SOURCE_DIR/metadata.json" || ! -f "$SOURCE_DIR/contents/lockscreen/LockScreen.qml" ]]; then
    die "This directory is not a complete KPackage: metadata.json or LockScreen.qml is missing."
fi

# Read the active package before the first install. On later edits, retain the
# original package from the state file rather than recording Fedlock as its own
# rollback target.
read_active_package() {
    kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage 2>/dev/null || true
}

previous_id=""
if [[ -f "$STATE_FILE" ]]; then
    previous_id="$(sed -n 's/^PREVIOUS_ID=//p' "$STATE_FILE" | head -n 1)"
fi
if [[ -z "$previous_id" ]]; then
    previous_id="$(read_active_package)"
    if [[ -z "$previous_id" ]]; then
        # Breeze is Plasma's documented default, but make the assumption
        # visible instead of pretending the config key was present.
        previous_id="org.kde.breeze.desktop"
        warn "LookAndFeelPackage is not set in kdeglobals; recording the Plasma default $previous_id."
    fi
    mkdir -p "$STATE_ROOT"
    umask 077
    cat > "$STATE_FILE" <<EOF
PREVIOUS_ID=$previous_id
PACKAGE_ID=$PACKAGE_ID
PACKAGE_DIR=$PACKAGE_DIR
RECORDED_AT=$(date -Is)
EOF
    info "Recorded active Look-and-Feel package: $previous_id"
else
    info "Keeping previously recorded rollback package: $previous_id"
fi

# Keep the package at the path requested by the user. kpackagetool6 owns the
# initial install; subsequent edits are copied in and registered as upgrades.
if [[ -d "$PACKAGE_DIR" ]]; then
    cp -a "$SOURCE_DIR/." "$PACKAGE_DIR/"
    if kpackagetool6 --type "$PACKAGE_TYPE" --upgrade "$PACKAGE_DIR"; then
        ok "Upgraded $PACKAGE_ID at $PACKAGE_DIR"
    else
        warn "Upgrade was not registered; trying a fresh KPackage install."
        kpackagetool6 --type "$PACKAGE_TYPE" --install "$SOURCE_DIR"
        ok "Installed $PACKAGE_ID"
    fi
else
    kpackagetool6 --type "$PACKAGE_TYPE" --install "$SOURCE_DIR"
    # Some distro builds resolve XDG data directories differently. Make the
    # requested path explicit if the tool did not create it there, then index
    # it with the normal upgrade operation.
    if [[ ! -d "$PACKAGE_DIR" ]]; then
        mkdir -p "$PACKAGE_DIR"
        cp -a "$SOURCE_DIR/." "$PACKAGE_DIR/"
        kpackagetool6 --type "$PACKAGE_TYPE" --upgrade "$PACKAGE_DIR"
    fi
    ok "Installed $PACKAGE_ID at $PACKAGE_DIR"
fi

# Determine whether this distro still ships a stock Look-and-Feel lockscreen.
# Plasma 6.7 upstream moved the default entry point to Plasma/Shell; do not
# silently claim that a global theme can replace it when the hook is absent.
lookfeel_lockscreen=""
for lookfeel_root in \
    "$HOME/.local/share/plasma/look-and-feel" \
    /usr/local/share/plasma/look-and-feel \
    /usr/share/plasma/look-and-feel; do
    [[ -d "$lookfeel_root" ]] || continue
    while IFS= read -r candidate; do
        [[ "$candidate" == "$PACKAGE_DIR/contents/lockscreen/LockScreen.qml" ]] && continue
        lookfeel_lockscreen="$candidate"
        break 2
    done < <(find "$lookfeel_root" -path '*/contents/lockscreen/LockScreen.qml' -type f 2>/dev/null)
done

if [[ -n "$lookfeel_lockscreen" ]]; then
    info "A Look-and-Feel lockscreen hook is present: $lookfeel_lockscreen"
else
    warn "No stock Look-and-Feel contents/lockscreen/LockScreen.qml was found."
    warn "Upstream Plasma 6.7.3 loads the lockscreen from the active Plasma/Shell package."
    warn "The KPackage is valid and remains installed, but --apply may not change the greeter on this layout."
    if ((apply_theme)) && (( ! allow_unwired )); then
        die "Refusing to apply an unwired lockscreen. Re-run --apply --allow-unwired only to investigate."
    fi
fi

printf '\nRollback (reapply the package recorded before Fedlock):\n  plasma-apply-lookandfeel --apply %s\n' "$previous_id"
printf 'Full package removal: %s/uninstall.sh\n' "$SCRIPT_DIR"
printf 'Preview (non-locking; do this before any real lock):\n  %s\n\n' 'kscreenlocker_greet --testing'

if ((apply_theme)); then
    if [[ ! -t 0 ]]; then
        die "--apply requires an interactive terminal so recovery instructions are acknowledged."
    fi
    cat <<'EOF'
Before applying, confirm that you know the escape route if a lock-screen UI is
broken: switch to Ctrl+Alt+F3 (or F4), log in, identify the session with
loginctl list-sessions, then run loginctl unlock-session <id>. If necessary,
kill only the offending greeter with pkill -x kscreenlocker_greet. Preview with
kscreenlocker_greet --testing before using Meta+L or loginctl lock-session.
EOF
    printf 'Type APPLY to continue: '
    read -r confirmation
    [[ "$confirmation" == "APPLY" ]] || die "Not applied. The package remains installed for preview or later use."

    plasma-apply-lookandfeel --apply "$PACKAGE_ID"
    ok "Applied $PACKAGE_ID with plasma-apply-lookandfeel."
    info "No real lock was started by this script. Run the preview command above now."
fi

if ((preview)); then
    greeter_bin="$(command -v kscreenlocker_greet 2>/dev/null || true)"
    if [[ -z "$greeter_bin" ]]; then
        for greeter_root in /usr/libexec /usr/lib /usr/lib64 /libexec; do
            [[ -d "$greeter_root" ]] || continue
            greeter_bin="$(find "$greeter_root" -maxdepth 3 -type f -name kscreenlocker_greet -perm -111 -print -quit 2>/dev/null || true)"
            [[ -n "$greeter_bin" ]] && break
        done
    fi
    [[ -n "$greeter_bin" ]] || die "Could not locate kscreenlocker_greet; use find /usr -name kscreenlocker_greet."
    greeter_help="$("$greeter_bin" --help 2>&1 || true)"
    grep -q -- '--testing' <<<"$greeter_help" || die "This kscreenlocker_greet does not advertise --testing; refusing to launch a preview."
    info "Launching the non-locking preview. Close the window or press Ctrl+C to exit."
    "$greeter_bin" --testing
fi
