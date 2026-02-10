#!/bin/bash
set -euo pipefail

# private-ai-client uninstall script
# Removes only client-side changes made by install.sh
# Leaves Tailscale, Homebrew, and pipx untouched
# Source: client/specs/SCRIPTS.md lines 14-18

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Banner
echo "================================================"
echo "  private-ai-client Uninstall Script"
echo "  Removes client-side changes and configuration"
echo "================================================"
echo ""

# Track what was actually removed
REMOVED_ITEMS=()
REMOVAL_FAILURES=()

# Step 1: Remove Aider
info "Removing Aider..."
if command -v pipx &> /dev/null; then
    if pipx list 2>/dev/null | grep -q aider-chat; then
        if pipx uninstall aider-chat > /dev/null 2>&1; then
            info "✓ Aider removed"
            REMOVED_ITEMS+=("Aider (via pipx)")
        else
            warn "Failed to uninstall Aider (continuing anyway)"
            REMOVAL_FAILURES+=("Aider (pipx uninstall failed)")
        fi
    else
        info "Aider not installed via pipx, skipping"
    fi
else
    warn "pipx not found, skipping Aider removal"
fi

# Step 2: Remove shell profile sourcing lines
info "Cleaning shell profile(s)..."

MARKER_START="# >>> private-ai-client >>>"
MARKER_END="# <<< private-ai-client <<<"
REMOVED_COUNT=0

# Clean both zsh and bash profiles (user may have switched shells)
for PROFILE in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [[ -f "$PROFILE" ]]; then
        if grep -q "$MARKER_START" "$PROFILE"; then
            # Remove everything between markers (inclusive)
            # Use sed with temporary file for portability
            sed -i.bak "/$MARKER_START/,/$MARKER_END/d" "$PROFILE"
            rm -f "$PROFILE.bak"
            info "✓ Cleaned: $PROFILE"
            REMOVED_COUNT=$((REMOVED_COUNT + 1))
        fi
    fi
done

if [[ $REMOVED_COUNT -gt 0 ]]; then
    REMOVED_ITEMS+=("Shell profile modifications ($REMOVED_COUNT file(s))")
else
    info "No shell profile modifications found, skipping"
fi

# Step 3: Delete ~/.private-ai-client directory
info "Removing configuration directory..."
CLIENT_DIR="$HOME/.private-ai-client"
if [[ -d "$CLIENT_DIR" ]]; then
    rm -rf "$CLIENT_DIR"
    info "✓ Removed: $CLIENT_DIR"
    REMOVED_ITEMS+=("Configuration directory ($CLIENT_DIR)")
else
    info "Configuration directory not found, skipping"
fi

# Summary
echo ""
echo "================================================"
echo "  Uninstall Complete!"
echo "================================================"
echo ""

# Show what was actually removed
if [[ ${#REMOVED_ITEMS[@]} -gt 0 ]]; then
    info "Successfully removed:"
    for item in "${REMOVED_ITEMS[@]}"; do
        echo "  - $item"
    done
    echo ""
else
    info "Nothing was removed (clean system or already uninstalled)"
    echo ""
fi

# Show any failures
if [[ ${#REMOVAL_FAILURES[@]} -gt 0 ]]; then
    warn "Removal failures:"
    for failure in "${REMOVAL_FAILURES[@]}"; do
        echo "  - $failure"
    done
    echo ""
fi

info "Preserved (as expected):"
echo "  - Tailscale"
echo "  - Homebrew"
echo "  - pipx"
echo "  - Python"
echo ""

# Terminal reload reminder (inside summary box)
if [[ ${#REMOVED_ITEMS[@]} -gt 0 ]]; then
    info "Important:"
    echo "  Close and reopen your terminal, or run: exec \$SHELL"
    echo "  (Changes will take effect in new terminal sessions)"
fi

echo "================================================"
echo ""
