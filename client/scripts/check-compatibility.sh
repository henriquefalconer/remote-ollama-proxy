#!/bin/bash
set -euo pipefail

# check-compatibility.sh
# Verify Claude Code and Ollama versions are tested together
# Source: client/specs/VERSION_MANAGEMENT.md lines 66-131
# Exit codes: 0=compatible, 1=tool not found, 2=mismatch, 3=unknown

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Compatibility matrix (update as new versions are tested)
declare -A COMPATIBLE_VERSIONS=(
    ["2.1.38"]="0.5.4"  # Claude Code 2.1.38 works with Ollama 0.5.4
    ["2.1.39"]="0.5.5"  # Claude Code 2.1.39 works with Ollama 0.5.5
)

# Banner
echo "=== Claude Code + Ollama Compatibility Checker ==="
echo ""

# Step 1: Check Claude Code installation
if command -v claude &> /dev/null; then
    # Get Claude Code version
    CLAUDE_VERSION=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "unknown")

    if [[ "$CLAUDE_VERSION" != "unknown" ]]; then
        echo -e "${GREEN}✓${NC} Claude Code installed: v${CLAUDE_VERSION}"
    else
        echo -e "${YELLOW}⚠${NC} Claude Code installed but version not detected"
        echo ""
        echo "Run: claude --version"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} Claude Code not found"
    echo ""
    echo "Install Claude Code first:"
    echo "  npm install -g @anthropic-ai/claude-code"
    echo ""
    exit 1
fi

# Step 2: Check Ollama server reachability
# Load environment if available
ENV_FILE="$HOME/.ai-client/env"
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
fi

# Determine Ollama server URL
if [[ -n "${ANTHROPIC_BASE_URL:-}" ]]; then
    OLLAMA_SERVER="$ANTHROPIC_BASE_URL"
elif [[ -n "${OLLAMA_API_BASE:-}" ]]; then
    OLLAMA_SERVER="$OLLAMA_API_BASE"
else
    OLLAMA_SERVER="http://localhost:11434"
fi

# Try to get Ollama version from server
OLLAMA_RESPONSE=$(curl -sf "${OLLAMA_SERVER}/api/version" 2>/dev/null || echo "")

if [[ -n "$OLLAMA_RESPONSE" ]]; then
    OLLAMA_VERSION=$(echo "$OLLAMA_RESPONSE" | jq -r '.version' 2>/dev/null || echo "unknown")

    if [[ "$OLLAMA_VERSION" != "unknown" && "$OLLAMA_VERSION" != "null" ]]; then
        echo -e "${GREEN}✓${NC} Ollama server reachable: v${OLLAMA_VERSION}"
    else
        echo -e "${YELLOW}⚠${NC} Ollama server reachable but version not detected"
        echo ""
        echo "Check: ${OLLAMA_SERVER}/api/version"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} Ollama server unreachable: ${OLLAMA_SERVER}"
    echo ""
    echo "Ensure server is running and accessible"
    echo "Check:"
    echo "  • Server is online: ssh server 'ollama serve'"
    echo "  • WireGuard VPN is connected: wg show"
    echo "  • Server IP is correct in ~/.ai-client/env"
    echo ""
    exit 1
fi

echo ""

# Step 3: Check compatibility
if [[ -n "${COMPATIBLE_VERSIONS[$CLAUDE_VERSION]:-}" ]]; then
    EXPECTED_OLLAMA="${COMPATIBLE_VERSIONS[$CLAUDE_VERSION]}"

    if [[ "$OLLAMA_VERSION" == "$EXPECTED_OLLAMA" ]]; then
        # Perfect match
        echo -e "${GREEN}✓ COMPATIBLE${NC}"
        echo "Claude Code v${CLAUDE_VERSION} works with Ollama v${OLLAMA_VERSION}"
        echo ""
        exit 0
    else
        # Version mismatch
        echo -e "${YELLOW}⚠ VERSION MISMATCH${NC}"
        echo "Claude Code v${CLAUDE_VERSION} is tested with Ollama v${EXPECTED_OLLAMA}"
        echo "But your server has v${OLLAMA_VERSION}"
        echo ""

        # Determine if upgrade or downgrade needed
        if [[ "$OLLAMA_VERSION" < "$EXPECTED_OLLAMA" ]]; then
            echo "Recommendation: Update Ollama on server to v${EXPECTED_OLLAMA}"
            echo "  On the server, run: brew upgrade ollama"
        else
            echo "Recommendation: Your Ollama is newer than tested"
            echo "  Option 1: Test current setup (may work)"
            echo "  Option 2: Downgrade Ollama to v${EXPECTED_OLLAMA}"
            echo "    On the server, run: brew uninstall ollama && brew install ollama@${EXPECTED_OLLAMA}"
        fi
        echo ""
        exit 2
    fi
else
    # Unknown compatibility
    echo -e "${YELLOW}⚠ UNKNOWN COMPATIBILITY${NC}"
    echo "Claude Code v${CLAUDE_VERSION} has not been tested with Ollama"
    echo ""
    echo "Proceed with caution. Test basic functionality:"
    echo "  claude-ollama"
    echo ""
    echo "If it works, add to compatibility matrix:"
    echo "  Edit client/scripts/check-compatibility.sh"
    echo "  Add: [\"${CLAUDE_VERSION}\"]=\"${OLLAMA_VERSION}\""
    echo ""
    exit 3
fi
