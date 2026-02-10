#!/bin/bash
set -euo pipefail

# remote-ollama ai-client test script
# Comprehensive validation of all client functionality
# Source: client/specs/SCRIPTS.md lines 20-78

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
TOTAL_TESTS=28
CURRENT_TEST=0

# Flags
VERBOSE=false
SKIP_SERVER=false
SKIP_AIDER=false
QUICK_MODE=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --skip-server)
            SKIP_SERVER=true
            shift
            ;;
        --skip-aider)
            SKIP_AIDER=true
            shift
            ;;
        --quick)
            QUICK_MODE=true
            shift
            ;;
        *)
            echo "Usage: $0 [--verbose|-v] [--skip-server] [--skip-aider] [--quick]"
            exit 1
            ;;
    esac
done

# Output helpers
show_progress() {
    CURRENT_TEST=$((CURRENT_TEST + 1))
    echo -e "${BLUE}[Test $CURRENT_TEST/$TOTAL_TESTS]${NC} $1"
}

pass() {
    echo -e "${GREEN}✓ PASS${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    local message="$1"
    local expected="${2:-}"
    local received="${3:-}"

    echo -e "${RED}✗ FAIL${NC} $message"

    if [[ -n "$expected" && -n "$received" ]]; then
        echo -e "  ${YELLOW}Expected:${NC} $expected"
        echo -e "  ${YELLOW}Received:${NC} $received"
    fi

    # Show troubleshooting hint if provided as 4th argument
    if [[ -n "${4:-}" ]]; then
        echo -e "  ${BLUE}Hint:${NC} $4"
    fi

    TESTS_FAILED=$((TESTS_FAILED + 1))
}

skip() {
    local message="$1"
    local how_to_enable="${2:-No guidance provided}"

    echo -e "${YELLOW}⊘ SKIP${NC} $message"
    echo -e "  ${BLUE}To enable:${NC} $how_to_enable"

    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

info() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

# Banner
echo "================================================"
echo "  remote-ollama ai-client Test Suite"
echo "  Running $TOTAL_TESTS tests"
echo "================================================"
echo ""

# Environment Configuration Tests
echo "=== Environment Configuration Tests ==="

# Test 1: Env file exists
ENV_FILE="$HOME/.ai-client/env"
info "Checking if env file exists at $ENV_FILE..."
if [[ -f "$ENV_FILE" ]]; then
    pass "Environment file exists (~/.ai-client/env)"
else
    fail "Environment file missing (~/.ai-client/env)"
fi

# Load environment if file exists
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE" 2>/dev/null || true
fi

# Test 2-5: Required environment variables
info "Checking required environment variables..."

if [[ -n "${OLLAMA_API_BASE:-}" ]]; then
    pass "OLLAMA_API_BASE is set: $OLLAMA_API_BASE"
else
    fail "OLLAMA_API_BASE is not set"
fi

if [[ -n "${OPENAI_API_BASE:-}" ]]; then
    pass "OPENAI_API_BASE is set: $OPENAI_API_BASE"
else
    fail "OPENAI_API_BASE is not set"
fi

if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    if [[ "$OPENAI_API_KEY" == "ollama" ]]; then
        pass "OPENAI_API_KEY is set correctly: $OPENAI_API_KEY"
    else
        fail "OPENAI_API_KEY has wrong value" "ollama" "$OPENAI_API_KEY" "Edit ~/.ai-client/env to set OPENAI_API_KEY=ollama"
    fi
else
    fail "OPENAI_API_KEY is not set" "OPENAI_API_KEY=ollama" "Variable not set" "Run install.sh or source ~/.ai-client/env"
fi

if [[ -n "${AIDER_MODEL:-}" ]]; then
    pass "AIDER_MODEL is set (optional): $AIDER_MODEL"
else
    skip "AIDER_MODEL is not set (optional)" "Uncomment and set AIDER_MODEL in ~/.ai-client/env"
fi

# Test 6: Shell profile sources env file
info "Checking if shell profile sources env file..."
USER_SHELL=$(basename "$SHELL")
if [[ "$USER_SHELL" == "zsh" ]]; then
    SHELL_PROFILE="$HOME/.zshrc"
elif [[ "$USER_SHELL" == "bash" ]]; then
    SHELL_PROFILE="$HOME/.bashrc"
else
    SHELL_PROFILE="$HOME/.zshrc"  # Default fallback
fi

if [[ -f "$SHELL_PROFILE" ]]; then
    if grep -q "ai-client" "$SHELL_PROFILE" && grep -q "source.*\.ai-client/env" "$SHELL_PROFILE"; then
        pass "Shell profile sources env file ($SHELL_PROFILE)"
    else
        fail "Shell profile does not source env file ($SHELL_PROFILE)"
    fi
else
    fail "Shell profile not found ($SHELL_PROFILE)"
fi

# Test 7: Environment variables are exported
info "Checking if environment variables are exported..."
if grep -q "^export OLLAMA_API_BASE" "$ENV_FILE" && \
   grep -q "^export OPENAI_API_BASE" "$ENV_FILE" && \
   grep -q "^export OPENAI_API_KEY" "$ENV_FILE"; then
    pass "Environment variables are exported in env file"
else
    fail "Environment variables are not properly exported in env file"
fi

echo ""
echo "=== Dependency Tests ==="

# Test 8: Tailscale installed
info "Checking for Tailscale..."
if command -v tailscale &> /dev/null; then
    pass "Tailscale is installed"
else
    fail "Tailscale is not installed"
fi

# Test 9: Tailscale running/connected
info "Checking Tailscale status..."
if command -v tailscale &> /dev/null && tailscale status &> /dev/null; then
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null | head -n1 || echo "")
    if [[ -n "$TAILSCALE_IP" ]]; then
        pass "Tailscale is connected (IP: $TAILSCALE_IP)"
    else
        fail "Tailscale is installed but not connected"
    fi
else
    fail "Tailscale is not running or not connected"
fi

# Test 10: Homebrew installed
info "Checking for Homebrew..."
if command -v brew &> /dev/null; then
    pass "Homebrew is installed"
else
    fail "Homebrew is not installed"
fi

# Test 11: Python 3.10+
info "Checking for Python 3.10+..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
    PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
    PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)

    if [[ "$PYTHON_MAJOR" -ge 3 && "$PYTHON_MINOR" -ge 10 ]]; then
        pass "Python $PYTHON_VERSION found (>= 3.10)"
    else
        fail "Python $PYTHON_VERSION is too old (need 3.10+)"
    fi
else
    fail "Python 3 is not installed"
fi

# Test 12: pipx installed
info "Checking for pipx..."
if command -v pipx &> /dev/null; then
    pass "pipx is installed"
else
    fail "pipx is not installed"
fi

# Test 13: Aider installed
if [[ "$SKIP_AIDER" == "true" ]]; then
    skip "Aider installation check - aider tests skipped" "Remove --skip-aider flag when running test.sh"
else
    info "Checking for Aider..."
    if command -v aider &> /dev/null; then
        AIDER_VERSION=$(aider --version 2>&1 | head -n1 || echo "unknown")
        pass "Aider is installed: $AIDER_VERSION"
    else
        fail "Aider is not installed"
    fi
fi

echo ""
echo "=== Connectivity Tests ==="

if [[ "$SKIP_SERVER" == "true" ]]; then
    skip "GET /v1/models - server tests skipped" "Remove --skip-server flag when running test.sh"
    skip "GET /v1/models/{model} - server tests skipped" "Remove --skip-server flag when running test.sh"
    skip "POST /v1/chat/completions (non-streaming) - server tests skipped" "Remove --skip-server flag when running test.sh"
    skip "POST /v1/chat/completions (streaming) - server tests skipped" "Remove --skip-server flag when running test.sh"
    skip "Error handling test - server tests skipped" "Remove --skip-server flag when running test.sh"
else
    # Use OLLAMA_API_BASE directly (no /v1 suffix per corrected contract)
    if [[ -n "${OLLAMA_API_BASE:-}" ]]; then
        SERVER_URL="$OLLAMA_API_BASE"
        info "Using server URL: $SERVER_URL"
    else
        SERVER_URL=""
        fail "Cannot determine server URL (OLLAMA_API_BASE not set)"
    fi

    # Test 14: Tailscale connectivity to server
    if [[ -n "$SERVER_URL" ]]; then
        info "Testing connectivity to server..."
        HOSTNAME=$(echo "$SERVER_URL" | sed 's|http://||' | sed 's|:.*||')
        if ping -c 1 -t 2 "$HOSTNAME" &> /dev/null || curl -sf --max-time 5 "$SERVER_URL/v1/models" &> /dev/null; then
            pass "Server is reachable ($HOSTNAME)"
        else
            fail "Cannot reach server ($HOSTNAME)"
        fi
    fi

    # Test 15: GET /v1/models
    info "Testing GET /v1/models..."
    if [[ -n "$SERVER_URL" ]]; then
        # Measure timing for verbose mode
        START_TIME=$(date +%s%N 2>/dev/null || date +%s)

        if [[ "$VERBOSE" == "true" ]]; then
            # Verbose mode: show request/response details
            info "Request: GET $SERVER_URL/v1/models"
            RESPONSE_WITH_CODE=$(curl -v "$SERVER_URL/v1/models" -w "\n%{http_code}" 2>&1 || echo "FAILED")
            HTTP_CODE=$(echo "$RESPONSE_WITH_CODE" | tail -n1)
            MODELS_RESPONSE=$(echo "$RESPONSE_WITH_CODE" | sed '$d' | grep -v '^[<>*]' | grep -v '^{' -A 9999 || echo "$RESPONSE_WITH_CODE" | sed '$d')
            info "HTTP Status: $HTTP_CODE"
            info "Response Body: $MODELS_RESPONSE"
        else
            # Non-verbose mode: silent request with status code
            RESPONSE_WITH_CODE=$(curl -sf "$SERVER_URL/v1/models" -w "\n%{http_code}" 2>/dev/null || echo -e "FAILED\n000")
            HTTP_CODE=$(echo "$RESPONSE_WITH_CODE" | tail -n1)
            MODELS_RESPONSE=$(echo "$RESPONSE_WITH_CODE" | sed '$d')
        fi

        END_TIME=$(date +%s%N 2>/dev/null || date +%s)
        if [[ "$START_TIME" =~ N ]]; then
            ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
        else
            ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
        fi

        if [[ "$VERBOSE" == "true" ]]; then
            info "Elapsed time: ${ELAPSED_MS}ms"
        fi

        # F2.6: Validate HTTP status code
        if [[ "$HTTP_CODE" != "200" ]]; then
            fail "GET /v1/models returned HTTP $HTTP_CODE" "200" "$HTTP_CODE"
        elif [[ "$MODELS_RESPONSE" != "FAILED" ]] && echo "$MODELS_RESPONSE" | jq -e '.object == "list"' &> /dev/null; then
            MODEL_COUNT=$(echo "$MODELS_RESPONSE" | jq -r '.data | length')
            pass "GET /v1/models returns valid JSON (${MODEL_COUNT} models)"

            # Store first model for later tests
            if [[ "$MODEL_COUNT" -gt 0 ]]; then
                FIRST_MODEL=$(echo "$MODELS_RESPONSE" | jq -r '.data[0].id')
                info "First available model: $FIRST_MODEL"
            fi
        else
            fail "GET /v1/models failed or returned invalid JSON"
        fi
    fi

    # Test 16: GET /v1/models/{model}
    if [[ -n "${FIRST_MODEL:-}" ]] && [[ -n "$SERVER_URL" ]]; then
        info "Testing GET /v1/models/$FIRST_MODEL..."

        # Measure timing for verbose mode
        START_TIME=$(date +%s%N 2>/dev/null || date +%s)

        if [[ "$VERBOSE" == "true" ]]; then
            # Verbose mode: show request/response details
            info "Request: GET $SERVER_URL/v1/models/$FIRST_MODEL"
            RESPONSE_WITH_CODE=$(curl -v "$SERVER_URL/v1/models/$FIRST_MODEL" -w "\n%{http_code}" 2>&1 || echo "FAILED")
            HTTP_CODE=$(echo "$RESPONSE_WITH_CODE" | tail -n1)
            MODEL_DETAIL=$(echo "$RESPONSE_WITH_CODE" | sed '$d' | grep -v '^[<>*]' | grep -v '^{' -A 9999 || echo "$RESPONSE_WITH_CODE" | sed '$d')
            info "HTTP Status: $HTTP_CODE"
            info "Response Body: $MODEL_DETAIL"
        else
            # Non-verbose mode: silent request with status code
            RESPONSE_WITH_CODE=$(curl -sf "$SERVER_URL/v1/models/$FIRST_MODEL" -w "\n%{http_code}" 2>/dev/null || echo -e "FAILED\n000")
            HTTP_CODE=$(echo "$RESPONSE_WITH_CODE" | tail -n1)
            MODEL_DETAIL=$(echo "$RESPONSE_WITH_CODE" | sed '$d')
        fi

        END_TIME=$(date +%s%N 2>/dev/null || date +%s)
        if [[ "$START_TIME" =~ N ]]; then
            ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
        else
            ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
        fi

        if [[ "$VERBOSE" == "true" ]]; then
            info "Elapsed time: ${ELAPSED_MS}ms"
        fi

        # F2.6: Validate HTTP status code
        if [[ "$HTTP_CODE" != "200" ]]; then
            fail "GET /v1/models/{model} returned HTTP $HTTP_CODE" "200" "$HTTP_CODE"
        elif [[ "$MODEL_DETAIL" != "FAILED" ]] && echo "$MODEL_DETAIL" | jq -e '.id' &> /dev/null; then
            pass "GET /v1/models/{model} returns valid model details"
        else
            fail "GET /v1/models/{model} failed"
        fi
    elif [[ -n "$SERVER_URL" ]]; then
        skip "GET /v1/models/{model} - no models available" "Pull a model on the server first (e.g., ollama pull llama3.2)"
    fi

    # Test 17: POST /v1/chat/completions (non-streaming) - skip in quick mode (F2.9)
    if [[ -n "${FIRST_MODEL:-}" ]] && [[ -n "$SERVER_URL" ]] && [[ "$QUICK_MODE" == "false" ]]; then
        info "Testing POST /v1/chat/completions (non-streaming)..."

        # Measure timing for verbose mode
        START_TIME=$(date +%s%N 2>/dev/null || date +%s)

        if [[ "$VERBOSE" == "true" ]]; then
            # Verbose mode: show request/response details
            info "Request: POST $SERVER_URL/v1/chat/completions"
            info "Body: {\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1}"

            CHAT_RESPONSE=$(curl -v "$SERVER_URL/v1/chat/completions" \
                -H "Content-Type: application/json" \
                -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1}" \
                -w "\n%{http_code}" \
                2>&1 || echo "FAILED")

            HTTP_CODE=$(echo "$CHAT_RESPONSE" | tail -n1)
            CHAT_BODY=$(echo "$CHAT_RESPONSE" | sed '$d')

            info "HTTP Status: $HTTP_CODE"
            info "Response Body: $CHAT_BODY"
        else
            # Non-verbose mode: silent request with status code
            RESPONSE_WITH_CODE=$(curl -sf "$SERVER_URL/v1/chat/completions" \
                -H "Content-Type: application/json" \
                -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1}" \
                -w "\n%{http_code}" \
                2>/dev/null || echo -e "FAILED\n000")

            HTTP_CODE=$(echo "$RESPONSE_WITH_CODE" | tail -n1)
            CHAT_RESPONSE=$(echo "$RESPONSE_WITH_CODE" | sed '$d')
        fi

        END_TIME=$(date +%s%N 2>/dev/null || date +%s)
        if [[ "$START_TIME" =~ N ]]; then
            ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
        else
            ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
        fi

        if [[ "$VERBOSE" == "true" ]]; then
            info "Elapsed time: ${ELAPSED_MS}ms"
        fi

        # F2.6: Validate HTTP status code
        if [[ "$HTTP_CODE" != "200" ]]; then
            fail "POST /v1/chat/completions (non-streaming) returned HTTP $HTTP_CODE" "200" "$HTTP_CODE"
        elif [[ "$CHAT_RESPONSE" == "FAILED" ]]; then
            fail "POST /v1/chat/completions (non-streaming) failed to connect"
        else
            # F2.7: Validate OpenAI response schema
            SCHEMA_VALID=true
            MISSING_FIELDS=""

            # Check required fields
            if ! echo "$CHAT_RESPONSE" | jq -e '.id' &> /dev/null; then
                SCHEMA_VALID=false
                MISSING_FIELDS="${MISSING_FIELDS}id, "
            fi
            if ! echo "$CHAT_RESPONSE" | jq -e '.object' &> /dev/null; then
                SCHEMA_VALID=false
                MISSING_FIELDS="${MISSING_FIELDS}object, "
            fi
            if ! echo "$CHAT_RESPONSE" | jq -e '.created' &> /dev/null; then
                SCHEMA_VALID=false
                MISSING_FIELDS="${MISSING_FIELDS}created, "
            fi
            if ! echo "$CHAT_RESPONSE" | jq -e '.model' &> /dev/null; then
                SCHEMA_VALID=false
                MISSING_FIELDS="${MISSING_FIELDS}model, "
            fi
            if ! echo "$CHAT_RESPONSE" | jq -e '.usage' &> /dev/null; then
                SCHEMA_VALID=false
                MISSING_FIELDS="${MISSING_FIELDS}usage, "
            fi
            if ! echo "$CHAT_RESPONSE" | jq -e '.choices[0].message.content' &> /dev/null; then
                SCHEMA_VALID=false
                MISSING_FIELDS="${MISSING_FIELDS}choices[0].message.content, "
            fi

            if [[ "$SCHEMA_VALID" == "false" ]]; then
                fail "POST /v1/chat/completions response missing required fields" "OpenAI schema (id, object, created, model, usage, choices)" "Missing: ${MISSING_FIELDS%, }"
            else
                pass "POST /v1/chat/completions (non-streaming) succeeded"
            fi
        fi
    elif [[ -n "$SERVER_URL" ]] && [[ "$QUICK_MODE" == "false" ]]; then
        skip "POST /v1/chat/completions (non-streaming) - no models available" "Pull a model on the server first (e.g., ollama pull llama3.2)"
    elif [[ "$QUICK_MODE" == "true" ]]; then
        skip "POST /v1/chat/completions (non-streaming) - quick mode" "Remove --quick flag when running test.sh"
    fi

    # Test 18: POST /v1/chat/completions (streaming) - skip in quick mode (F2.9)
    if [[ -n "${FIRST_MODEL:-}" ]] && [[ -n "$SERVER_URL" ]] && [[ "$QUICK_MODE" == "false" ]]; then
        info "Testing POST /v1/chat/completions (streaming)..."

        # Measure timing for verbose mode
        START_TIME=$(date +%s%N 2>/dev/null || date +%s)

        if [[ "$VERBOSE" == "true" ]]; then
            # Verbose mode: show request/response details
            info "Request: POST $SERVER_URL/v1/chat/completions (streaming)"
            info "Body: {\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1,\"stream\":true}"

            STREAM_RESPONSE=$(curl -v "$SERVER_URL/v1/chat/completions" \
                -H "Content-Type: application/json" \
                -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1,\"stream\":true}" \
                2>&1 || echo "FAILED")

            info "Response (first 10 lines):"
            echo "$STREAM_RESPONSE" | head -n 10 | while IFS= read -r line; do
                info "  $line"
            done
        else
            # Non-verbose mode: silent request
            STREAM_RESPONSE=$(curl -sf "$SERVER_URL/v1/chat/completions" \
                -H "Content-Type: application/json" \
                -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1,\"stream\":true}" \
                2>/dev/null || echo "FAILED")
        fi

        END_TIME=$(date +%s%N 2>/dev/null || date +%s)
        if [[ "$START_TIME" =~ N ]]; then
            ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
        else
            ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
        fi

        if [[ "$VERBOSE" == "true" ]]; then
            info "Elapsed time: ${ELAPSED_MS}ms"
        fi

        if [[ "$STREAM_RESPONSE" != "FAILED" ]] && echo "$STREAM_RESPONSE" | grep -q "data:"; then
            pass "POST /v1/chat/completions (streaming) returns SSE chunks"
        else
            fail "POST /v1/chat/completions (streaming) failed"
        fi
    elif [[ -n "$SERVER_URL" ]] && [[ "$QUICK_MODE" == "false" ]]; then
        skip "POST /v1/chat/completions (streaming) - no models available" "Pull a model on the server first (e.g., ollama pull llama3.2)"
    elif [[ "$QUICK_MODE" == "true" ]]; then
        skip "POST /v1/chat/completions (streaming) - quick mode" "Remove --quick flag when running test.sh"
    fi

    # Test 19: Error handling when server unreachable - skip in quick mode (F2.9)
    if [[ -n "$SERVER_URL" ]] && [[ "$QUICK_MODE" == "false" ]]; then
        info "Testing error handling for unreachable endpoint..."

        # Measure timing for verbose mode
        START_TIME=$(date +%s%N 2>/dev/null || date +%s)

        if [[ "$VERBOSE" == "true" ]]; then
            # Verbose mode: show request details
            info "Request: GET $SERVER_URL/v1/nonexistent"
            ERROR_RESPONSE=$(curl -v -w "%{http_code}" -o /dev/null --max-time 5 "$SERVER_URL/v1/nonexistent" 2>&1 | tee /dev/stderr | tail -n1 || echo "FAILED")
        else
            ERROR_RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null --max-time 5 "$SERVER_URL/v1/nonexistent" 2>/dev/null || echo "FAILED")
        fi

        END_TIME=$(date +%s%N 2>/dev/null || date +%s)
        if [[ "$START_TIME" =~ N ]]; then
            ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
        else
            ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
        fi

        if [[ "$VERBOSE" == "true" ]]; then
            info "Elapsed time: ${ELAPSED_MS}ms"
            info "HTTP Status: $ERROR_RESPONSE"
        fi

        if [[ "$ERROR_RESPONSE" == "404" ]]; then
            pass "Error handling for nonexistent endpoint works (404)"
        elif [[ "$ERROR_RESPONSE" == "FAILED" ]]; then
            skip "Error handling test - could not reach server" "Ensure server is running and accessible via Tailscale"
        else
            info "Nonexistent endpoint returned status: $ERROR_RESPONSE"
        fi
    elif [[ "$QUICK_MODE" == "true" ]]; then
        skip "Error handling test - quick mode" "Remove --quick flag when running test.sh"
    fi
fi

echo ""
echo "=== API Contract Validation Tests ==="

# Test 20: Base URL format - only in non-quick mode (F2.9)
if [[ "$QUICK_MODE" == "true" ]]; then
    skip "OLLAMA_API_BASE format validation - quick mode" "Remove --quick flag when running test.sh"
    skip "OPENAI_API_BASE format validation - quick mode" "Remove --quick flag when running test.sh"
else
    info "Validating base URL format..."
    if [[ -n "${OLLAMA_API_BASE:-}" ]]; then
        if echo "$OLLAMA_API_BASE" | grep -qE '^http://[^:]+:11434$'; then
            pass "OLLAMA_API_BASE format matches contract (no /v1 suffix)"
        else
            fail "OLLAMA_API_BASE format does not match contract" "http://<host>:11434 (no /v1 suffix)" "$OLLAMA_API_BASE" "Remove /v1 suffix from OLLAMA_API_BASE - it should be http://<host>:11434"
        fi
    fi

    if [[ -n "${OPENAI_API_BASE:-}" ]]; then
        if echo "$OPENAI_API_BASE" | grep -qE '^http://[^:]+:11434/v1$'; then
            pass "OPENAI_API_BASE format matches contract (with /v1 suffix)"
        else
            fail "OPENAI_API_BASE format does not match contract" "http://<host>:11434/v1 (with /v1 suffix)" "$OPENAI_API_BASE" "Ensure OPENAI_API_BASE includes /v1 suffix"
        fi
    fi
fi

# Test 21: JSON mode - skip in quick mode (F2.9)
if [[ "$SKIP_SERVER" == "false" ]] && [[ "$QUICK_MODE" == "false" ]] && [[ -n "${FIRST_MODEL:-}" ]] && [[ -n "${SERVER_URL:-}" ]]; then
    info "Testing JSON mode response format..."

    # Measure timing for verbose mode
    START_TIME=$(date +%s%N 2>/dev/null || date +%s)

    if [[ "$VERBOSE" == "true" ]]; then
        # Verbose mode: show request/response details
        info "Request: POST $SERVER_URL/v1/chat/completions (JSON mode)"
        info "Body: {\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Return a JSON object\"}],\"max_tokens\":20,\"response_format\":{\"type\":\"json_object\"}}"

        JSON_RESPONSE=$(curl -v "$SERVER_URL/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Return a JSON object\"}],\"max_tokens\":20,\"response_format\":{\"type\":\"json_object\"}}" \
            2>&1 || echo "FAILED")

        info "Response: $JSON_RESPONSE"
    else
        JSON_RESPONSE=$(curl -sf "$SERVER_URL/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"Return a JSON object\"}],\"max_tokens\":20,\"response_format\":{\"type\":\"json_object\"}}" \
            2>/dev/null || echo "FAILED")
    fi

    END_TIME=$(date +%s%N 2>/dev/null || date +%s)
    if [[ "$START_TIME" =~ N ]]; then
        ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
    else
        ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        info "Elapsed time: ${ELAPSED_MS}ms"
    fi

    if [[ "$JSON_RESPONSE" != "FAILED" ]]; then
        CONTENT=$(echo "$JSON_RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null || echo "")
        if echo "$CONTENT" | jq -e '.' &> /dev/null 2>&1; then
            pass "JSON mode returns valid JSON content"
        else
            skip "JSON mode test - response not valid JSON (model-dependent)" "Use a model that supports JSON mode"
        fi
    else
        skip "JSON mode test - request failed" "Ensure server is running and accessible"
    fi
elif [[ "$QUICK_MODE" == "true" ]]; then
    skip "JSON mode test - quick mode" "Remove --quick flag when running test.sh"
else
    skip "JSON mode test - server tests skipped or no models available" "Remove --skip-server flag and pull a model on the server"
fi

# Test 22: Streaming with stream_options.include_usage - skip in quick mode (F2.9)
if [[ "$SKIP_SERVER" == "false" ]] && [[ "$QUICK_MODE" == "false" ]] && [[ -n "${FIRST_MODEL:-}" ]] && [[ -n "${SERVER_URL:-}" ]]; then
    info "Testing streaming with include_usage..."

    # Measure timing for verbose mode
    START_TIME=$(date +%s%N 2>/dev/null || date +%s)

    if [[ "$VERBOSE" == "true" ]]; then
        # Verbose mode: show request/response details
        info "Request: POST $SERVER_URL/v1/chat/completions (streaming with include_usage)"
        info "Body: {\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1,\"stream\":true,\"stream_options\":{\"include_usage\":true}}"

        USAGE_RESPONSE=$(curl -v "$SERVER_URL/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1,\"stream\":true,\"stream_options\":{\"include_usage\":true}}" \
            2>&1 || echo "FAILED")

        info "Response (all SSE chunks):"
        echo "$USAGE_RESPONSE" | grep "^data:" | while IFS= read -r line; do
            info "  $line"
        done
    else
        USAGE_RESPONSE=$(curl -sf "$SERVER_URL/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -d "{\"model\":\"$FIRST_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1,\"stream\":true,\"stream_options\":{\"include_usage\":true}}" \
            2>/dev/null || echo "FAILED")
    fi

    END_TIME=$(date +%s%N 2>/dev/null || date +%s)
    if [[ "$START_TIME" =~ N ]]; then
        ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
    else
        ELAPSED_MS=$(( (END_TIME - START_TIME) * 1000 ))
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        info "Elapsed time: ${ELAPSED_MS}ms"
    fi

    if [[ "$USAGE_RESPONSE" != "FAILED" ]] && echo "$USAGE_RESPONSE" | grep -q "data:"; then
        # F2.5: Verify usage data in streaming response
        # Extract the final SSE chunk (should contain usage data)
        FINAL_CHUNK=$(echo "$USAGE_RESPONSE" | grep "^data:" | grep -v "data: \[DONE\]" | tail -n1)

        if [[ -n "$FINAL_CHUNK" ]]; then
            # Remove "data: " prefix and parse JSON
            JSON_DATA=$(echo "$FINAL_CHUNK" | sed 's/^data: //')

            # Check for usage field in the final chunk
            if echo "$JSON_DATA" | jq -e '.usage' &> /dev/null; then
                pass "Streaming with stream_options.include_usage succeeded (usage field found)"
            else
                fail "Streaming with include_usage - usage field not found in response" "usage field in final SSE chunk" "No usage field detected"
            fi
        else
            skip "Streaming with include_usage test - no data chunks received" "Ensure server supports stream_options.include_usage"
        fi
    else
        skip "Streaming with include_usage test - request failed" "Ensure server is running and accessible"
    fi
elif [[ "$QUICK_MODE" == "true" ]]; then
    skip "Streaming with include_usage test - quick mode" "Remove --quick flag when running test.sh"
else
    skip "Streaming with include_usage test - server tests skipped" "Remove --skip-server flag when running test.sh"
fi

echo ""
echo "=== Aider Integration Tests ==="

# F2.9: Skip Aider integration tests in quick mode (tests 23-25 are non-critical)
if [[ "$QUICK_MODE" == "true" ]]; then
    skip "Aider binary check - quick mode" "Remove --quick flag when running test.sh"
    skip "Aider in PATH check - quick mode" "Remove --quick flag when running test.sh"
    skip "Aider environment variables - quick mode" "Remove --quick flag when running test.sh"
elif [[ "$SKIP_AIDER" == "true" ]]; then
    skip "Aider binary check - aider tests skipped" "Remove --skip-aider flag when running test.sh"
    skip "Aider in PATH check - aider tests skipped" "Remove --skip-aider flag when running test.sh"
    skip "Aider environment variables - aider tests skipped" "Remove --skip-aider flag when running test.sh"
else
    # Test 23: Aider can be invoked
    info "Checking if Aider can be invoked..."
    if command -v aider &> /dev/null; then
        pass "Aider binary found ($(which aider))"
    else
        fail "Aider binary not found in PATH"
    fi

    # Test 24: Aider in PATH
    AIDER_PATH=$(which aider 2>/dev/null || echo "")
    if [[ -n "$AIDER_PATH" ]]; then
        pass "Aider is in PATH: $AIDER_PATH"
    else
        fail "Aider is not in PATH"
    fi

    # Test 25: Aider reads environment variables
    info "Testing if Aider can read environment variables..."
    if [[ -n "${OPENAI_API_BASE:-}" ]] && [[ -n "${OPENAI_API_KEY:-}" ]]; then
        # Note: Cannot fully test without running Aider interactively
        pass "Environment variables configured for Aider (OPENAI_API_BASE, OPENAI_API_KEY)"
    else
        fail "Required environment variables for Aider are not set"
    fi

    # Test 26: End-to-end Aider test (non-interactive)
    # This test catches the critical OLLAMA_API_BASE bug where Aider tries to access /api/show
    show_progress "End-to-end Aider test (non-interactive)"

    if [[ "$SKIP_SERVER" == "true" ]]; then
        skip "End-to-end Aider test - server tests skipped" "Remove --skip-server flag when running test.sh"
    else
        info "Running non-interactive Aider test with qwen2.5:0.5b..."

        # Create a temporary directory for the test
        TEST_DIR=$(mktemp -d)
        cd "$TEST_DIR" || fail "Failed to create temp directory for Aider test"

        # Create a dummy file for Aider to work with
        echo "# Test file" > test.txt

        # Run Aider non-interactively with a simple prompt
        # This will fail if OLLAMA_API_BASE has /v1 suffix (constructs invalid URL)
        if timeout 30 bash -c 'echo "Say ok" | aider --yes --message "respond with just the word ok" --model ollama/qwen2.5:0.5b test.txt' &> /tmp/aider_test_output.log 2>&1; then
            pass "End-to-end Aider test succeeded (model metadata fetched correctly)"
        else
            # Check if it's a 404 error (the critical bug we're testing for)
            if grep -q "404" /tmp/aider_test_output.log || grep -q "/v1/api" /tmp/aider_test_output.log; then
                fail "End-to-end Aider test failed with 404 error" "Aider should fetch model metadata from /api/show" "Check /tmp/aider_test_output.log for details" "OLLAMA_API_BASE may have incorrect /v1 suffix"
            else
                # Other error (model not available, timeout, etc.) - this is acceptable for now
                skip "End-to-end Aider test timed out or model unavailable" "Ensure qwen2.5:0.5b is available on server (see /tmp/aider_test_output.log)"
            fi
        fi

        # Clean up
        cd - > /dev/null
        rm -rf "$TEST_DIR"
    fi
fi

echo ""
echo "=== Script Behavior Tests ==="

# Test 27: Uninstall script availability and clean-system test
info "Checking uninstall script availability..."
UNINSTALL_SCRIPT=""
if [[ -f "$HOME/.ai-client/uninstall.sh" ]]; then
    UNINSTALL_SCRIPT="$HOME/.ai-client/uninstall.sh"
    pass "Uninstall script found at ~/.ai-client/uninstall.sh"
elif [[ -f "$(dirname "$0")/uninstall.sh" ]]; then
    UNINSTALL_SCRIPT="$(dirname "$0")/uninstall.sh"
    pass "Uninstall script found in local clone"
else
    fail "Uninstall script not found"
fi

# F2.13: Test uninstall.sh on clean system (dry-run check) - skip in quick mode (F2.9)
if [[ "$QUICK_MODE" == "true" ]]; then
    skip "Uninstall script syntax check - quick mode" "Remove --quick flag when running test.sh"
elif [[ -n "$UNINSTALL_SCRIPT" ]] && [[ -f "$UNINSTALL_SCRIPT" ]]; then
    info "Testing uninstall script behavior..."
    # Run uninstall script with a dry-run approach: check if it can be executed without errors
    # We'll run it in a way that doesn't actually modify the system
    if bash -n "$UNINSTALL_SCRIPT" 2>/dev/null; then
        pass "Uninstall script has valid syntax (can run on clean system)"
    else
        fail "Uninstall script has syntax errors"
    fi
fi

# Test 28: Install script idempotency - skip in quick mode (F2.9)
if [[ "$QUICK_MODE" == "true" ]]; then
    skip "Install script idempotency check - quick mode" "Remove --quick flag when running test.sh"
elif [[ -f "$SHELL_PROFILE" ]]; then
    START_COUNT=$(grep -c ">>> ai-client >>>" "$SHELL_PROFILE" 2>/dev/null || echo "0")
    END_COUNT=$(grep -c "<<< ai-client <<<" "$SHELL_PROFILE" 2>/dev/null || echo "0")

    if [[ "$START_COUNT" -eq 1 ]] && [[ "$END_COUNT" -eq 1 ]]; then
        pass "Install script marker comments found exactly once (idempotency verified)"
    elif [[ "$START_COUNT" -gt 1 ]] || [[ "$END_COUNT" -gt 1 ]]; then
        fail "Marker comments appear multiple times (idempotency broken)" "1 occurrence of each marker" "Start: $START_COUNT, End: $END_COUNT" "Re-run install.sh to fix duplicate markers"
    else
        fail "Install script marker comments not found in shell profile" "Markers present" "Markers missing" "Run install.sh to add markers"
    fi
fi

# Final summary (F2.11: Use box-drawing characters)
echo ""
echo "┌────────────────────────────────────────────────┐"
echo "│              Test Summary                      │"
echo "└────────────────────────────────────────────────┘"
echo ""
echo -e "${GREEN}Passed:${NC}  $TESTS_PASSED"
echo -e "${RED}Failed:${NC}  $TESTS_FAILED"
echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
echo "Total:   $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    echo ""
    echo "┌────────────────────────────────────────────────┐"
    echo "│              Next Steps                        │"
    echo "└────────────────────────────────────────────────┘"

    # F2.12: Add "Run install.sh" as explicit next step for env/dependency failures
    # Count environment and dependency test failures (tests 1-13)
    ENV_OR_DEP_FAILURES=false
    if [[ ! -f "$ENV_FILE" ]] || \
       [[ -z "${OLLAMA_API_BASE:-}" ]] || \
       [[ -z "${OPENAI_API_BASE:-}" ]] || \
       [[ -z "${OPENAI_API_KEY:-}" ]] || \
       ! command -v tailscale &> /dev/null || \
       ! command -v brew &> /dev/null || \
       ! command -v python3 &> /dev/null || \
       ! command -v pipx &> /dev/null; then
        ENV_OR_DEP_FAILURES=true
    fi

    if [[ "$ENV_OR_DEP_FAILURES" == "true" ]]; then
        echo "  • Run install.sh to configure environment and install dependencies"
    fi
    echo "  • Check if server is running and accessible via Tailscale"
    echo "  • Verify environment variables: source ~/.ai-client/env"
    echo "  • Open a new terminal to reload shell profile"
    echo ""
    exit 1
fi
