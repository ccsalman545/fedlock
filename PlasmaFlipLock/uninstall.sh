#!/usr/bin/env bash
# Reapply the Look-and-Feel package recorded by install.sh, then remove Fedlock.
set -euo pipefail

readonly PACKAGE_ID="com.muhammedsalman.fedlock"
readonly DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly PACKAGE_DIR="$DATA_HOME/plasma/look-and-feel/$PACKAGE_ID"
readonly STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/fedlock/previous-look-and-feel"

info() { printf '\033[1;34m[i]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[✓]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[✗]\033[0m %s\n' "$*" >&2; exit 1; }

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat <<'EOF'
Usage: ./uninstall.sh

Reapply the Look-and-Feel ID recorded before Fedlock was first installed and
remove the user-scoped package. It never edits system files.
EOF
    exit 0
fi

command -v plasma-apply-lookandfeel >/dev/null 2>&1 || die "Required command not found: plasma-apply-lookandfeel"
command -v kpackagetool6 >/dev/null 2>&1 || die "Required command not found: kpackagetool6"
[[ -f "$STATE_FILE" ]] || die "No rollback record found at $STATE_FILE"

previous_id="$(sed -n 's/^PREVIOUS_ID=//p' "$STATE_FILE" | head -n 1)"
[[ -n "$previous_id" ]] || die "Rollback record does not contain PREVIOUS_ID"
[[ "$previous_id" != "$PACKAGE_ID" ]] || die "Rollback record points at Fedlock itself; refusing to remove it"

info "Reapplying previous Look-and-Feel: $previous_id"
plasma-apply-lookandfeel --apply "$previous_id"
ok "Restored $previous_id"

# Use KPackage's official remove operation first. The explicit path fallback is
# limited to the exact user package directory created by this project.
if ! kpackagetool6 --type Plasma/LookAndFeel --remove "$PACKAGE_ID"; then
    warn "KPackage remove reported an error; removing only $PACKAGE_DIR as a fallback."
fi
if [[ -d "$PACKAGE_DIR" ]]; then
    rm -rf -- "$PACKAGE_DIR"
fi
rm -f -- "$STATE_FILE"
rmdir --ignore-fail-on-non-empty "$(dirname "$STATE_FILE")" 2>/dev/null || true
ok "Removed $PACKAGE_ID"
printf '\nOne-line rollback command (if needed later):\n  plasma-apply-lookandfeel --apply %s\n' "$previous_id"
