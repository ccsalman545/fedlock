#!/usr/bin/env bash
# Restore the shell selected before Fedlock was applied, then remove it.
set -euo pipefail

readonly PACKAGE_ID="com.muhammedsalman.fedlock"
readonly PACKAGE_TYPE="Plasma/Shell"
readonly DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly PACKAGE_DIR="$DATA_HOME/plasma/shells/$PACKAGE_ID"
readonly STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/fedlock/previous-shell"

info() { printf '\033[1;34m[i]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[✓]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[✗]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage: ./uninstall.sh

Remove the user-scoped Fedlock Plasma/Shell package. If Fedlock is still the
active shell package, restore the shell ID recorded by install.sh first. If
the user selected another shell after applying Fedlock, that choice is left
alone.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi
[[ $# -eq 0 ]] || die "Unknown option '$1' (use --help)."

command -v kpackagetool6 >/dev/null 2>&1 || die "Required command not found: kpackagetool6"
command -v kreadconfig6 >/dev/null 2>&1 || die "Required command not found: kreadconfig6"

read_active_shell() {
    kreadconfig6 --file plasmashellrc --group Shell --key ShellPackage 2>/dev/null || true
}

is_package_id() {
    [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]
}

previous_id=""
if [[ -f "$STATE_FILE" ]]; then
    previous_id="$(sed -n 's/^PREVIOUS_ID=//p' "$STATE_FILE" | head -n 1)"
    [[ -n "$previous_id" ]] || die "Rollback record does not contain PREVIOUS_ID."
    is_package_id "$previous_id" || die "Rollback record contains an invalid package ID."
    [[ "$previous_id" != "$PACKAGE_ID" ]] || die "Rollback record points at Fedlock itself; refusing to remove it."
fi

active_id="$(read_active_shell)"
if [[ -n "$previous_id" && "$active_id" == "$PACKAGE_ID" ]]; then
    command -v kwriteconfig6 >/dev/null 2>&1 || die "Required command not found: kwriteconfig6"
    info "Restoring previous shell package: $previous_id"
    kwriteconfig6 --file plasmashellrc --group Shell --key ShellPackage "$previous_id"
    [[ "$(read_active_shell)" == "$previous_id" ]] || die "Could not restore $previous_id in plasmashellrc."
    ok "Restored $previous_id"
elif [[ -n "$previous_id" && "$active_id" != "$PACKAGE_ID" ]]; then
    warn "The active shell is '$active_id', not Fedlock; leaving that user choice unchanged."
fi

# Use KPackage's official remove operation first. The explicit fallback is
# limited to this project's exact user package directory.
[[ ! -L "$PACKAGE_DIR" ]] || die "Refusing to remove a symlink at $PACKAGE_DIR."
if ! kpackagetool6 --type "$PACKAGE_TYPE" --remove "$PACKAGE_ID"; then
    warn "KPackage remove reported an error; removing only $PACKAGE_DIR as a fallback."
fi
if [[ -d "$PACKAGE_DIR" ]]; then
    rm -rf -- "$PACKAGE_DIR"
fi
[[ ! -e "$PACKAGE_DIR" ]] || die "Could not remove $PACKAGE_DIR."

if [[ -f "$STATE_FILE" ]]; then
    rm -f -- "$STATE_FILE"
    rmdir --ignore-fail-on-non-empty "$(dirname "$STATE_FILE")" 2>/dev/null || true
fi
ok "Removed $PACKAGE_ID"
