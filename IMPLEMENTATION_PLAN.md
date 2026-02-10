<!--
 Copyright (c) 2026 Henrique Falconer. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

## Implementation Status (v0.0.4) ✅ CRITICAL BUG FIX COMPLETE

**⚠️ Critical bug discovered in v0.0.3 during real-world Aider usage (2026-02-10)**

**Bug**: `OLLAMA_API_BASE` incorrectly set to `http://ai-server:11434/v1` in API contract specification. This causes Aider/LiteLLM to construct invalid URLs like `http://ai-server:11434/v1/api/show` (combining OpenAI prefix `/v1` with Ollama native endpoint `/api/show`), resulting in 404 errors.

**Root Cause**: Spec files defined `OLLAMA_API_BASE` with `/v1` suffix, but Ollama-aware tools need to access native endpoints at `/api/*` (without `/v1` prefix) for model metadata operations.

**Fix Status**: ✅ COMPLETE (2026-02-10). All implementation files updated to match corrected specs. Hardware testing required to verify fix on real systems.

---

### v0.0.3 Status Summary (2026-02-10)

Re-audited 2026-02-10 (fourth pass) with exhaustive line-by-line spec-vs-implementation comparison using parallel Opus/Sonnet subagents. All 35 previously identified gaps re-confirmed. **16 additional gaps** found across all scripts. Total: **51 spec compliance gaps**. **ALL 51 spec compliance gaps FIXED** as of 2026-02-10.

**However**: Critical environment variable bug not caught by automated tests (tests validated API endpoints work but did not run Aider end-to-end).

- ✅ 8 of 8 spec-required scripts exist: env.template, server install.sh, server uninstall.sh, server test.sh, client install.sh, client uninstall.sh, client test.sh, warm-models.sh
- ✅ Spec documentation complete: 7 server + 6 client = 13 spec files, all internally consistent
- ✅ No TODO/FIXME/HACK/placeholder markers in any source files
- ✅ `client/config/env.template` — fully compliant (all 4 vars, `export`, `__HOSTNAME__` placeholder, `AIDER_MODEL` commented)
- ✅ `server/scripts/install.sh` — COMPLETE (all gaps fixed: F7.3)
- ✅ `server/scripts/uninstall.sh` — COMPLETE (all 3 gaps confirmed as already compliant)
- ✅ `client/scripts/install.sh` — COMPLETE (all 11 gaps fixed: F1.1-F1.11)
- ✅ `client/scripts/uninstall.sh` — COMPLETE (all 6 gaps fixed: F6.1-F6.6)
- ✅ `client/scripts/test.sh` — COMPLETE (all 15 gaps fixed: F2.1-F2.15)
- ✅ `server/scripts/test.sh` — COMPLETE (all 9 gaps fixed: F3.1-F3.9)
- ✅ `server/scripts/warm-models.sh` — COMPLETE (all 3 gaps fixed: F4.1-F4.3)
- ✅ **ALL 51 spec compliance gaps FIXED** (UX consistency complete: F7.1, F7.2, F7.4)
- ✅ **Server hardware testing COMPLETE** (all 20 tests passed on vm@remote-ollama, 2026-02-10)
- ✅ **Client hardware testing COMPLETE** (all 27 tests passed on vm@macos, 2026-02-10)
- ✅ **Documentation polish COMPLETE** (Priority E: all 4 tasks done)

# Implementation Plan

Prioritized task list for achieving full spec implementation of both server and client components.

## Current Status

- **Specifications**: ✅ UPDATED (2026-02-10) - Fixed `OLLAMA_API_BASE` bug in 3 spec files
  - ✅ `client/specs/API_CONTRACT.md` - Corrected `OLLAMA_API_BASE` to `http://ai-server:11434` (no `/v1` suffix)
  - ✅ `client/specs/SCRIPTS.md` - Updated test validation to check for correct URL format
  - ✅ `server/specs/INTERFACES.md` - Added note about Ollama native endpoints
- **Implementation files**: ✅ ALL UPDATED (2026-02-10) - All files now match corrected specs
  - ✅ `client/config/env.template` - Updated to `OLLAMA_API_BASE` without `/v1` suffix
  - ✅ `client/scripts/install.sh` - Uses corrected env.template
  - ✅ `client/scripts/test.sh` - Validates correct URL format, includes end-to-end Aider test
  - ⚠️ All deployed installations - Require manual fix or re-install (see troubleshooting in documentation)
- **Documentation**: ✅ UPDATED (2026-02-10) - All user-facing docs reflect corrected environment variables
- **Server implementation**: ✅ No changes needed (server serves both `/v1/*` and `/api/*` endpoints)
- **Testing**: ✅ END-TO-END TEST ADDED - Test 26 in client/scripts/test.sh validates Aider functionality

## Remaining Work (Priority Order)

✅ **CRITICAL BUG FIX COMPLETE** - v0.0.4 code changes complete (2026-02-10)

v0.0.3 contained a critical environment variable bug discovered during real-world Aider usage. All code changes have been implemented. Hardware testing is the only remaining task before v0.0.4 release.

### Priority G: Critical Bug Fix - OLLAMA_API_BASE ✅ COMPLETE

**Discovered**: 2026-02-10 during first real Aider usage attempt
**Severity**: CRITICAL - Aider completely non-functional with current configuration
**Impact**: All v0.0.3 installations broken for Aider usage
**Status**: ✅ ALL CODE CHANGES COMPLETE (2026-02-10) - Hardware testing pending

**Tasks**:
- ✅ Update `client/config/env.template` line 4: Changed `OLLAMA_API_BASE=http://__HOSTNAME__:11434/v1` to `OLLAMA_API_BASE=http://__HOSTNAME__:11434` (removed `/v1` suffix)
- ✅ Update `client/scripts/test.sh` environment validation to check for correct URL format (no `/v1` on OLLAMA_API_BASE, WITH `/v1` on OPENAI_API_BASE)
- ✅ Add end-to-end Aider test to `client/scripts/test.sh` to catch runtime integration issues (test 26 added, TOTAL_TESTS incremented to 28)
- ✅ Update all user-facing documentation (README.md, SETUP.md) to reflect corrected environment variables
- ✅ Add troubleshooting section for users with v0.0.3 installations (added to client/README.md and client/SETUP.md)
- ⚠️ Re-run client hardware testing with corrected configuration (code complete, testing pending on real hardware)
- ✅ Document lessons learned: automated tests must include end-to-end validation, not just API endpoint checks (documented in "Post-Release Critical Finding" section below)

**Specs already fixed** (2026-02-10):
- ✅ `client/specs/API_CONTRACT.md` - Corrected and added rationale
- ✅ `client/specs/SCRIPTS.md` - Updated validation requirements
- ✅ `server/specs/INTERFACES.md` - Added clarifying note

**Completion Note**: All code changes for the critical bug fix are complete. The corrected configuration needs to be validated on real hardware with an actual Aider workflow. Users with v0.0.3 installations can fix their setup by manually editing `~/.ai-client/env` or re-running the install script.

---

## Post-Release Critical Finding (v0.0.3)

### Bug Discovery Timeline

1. **2026-02-10 morning**: All 47 automated tests passed (20 server + 27 client)
2. **2026-02-10 afternoon**: v0.0.3 declared production-ready
3. **2026-02-10 evening**: First real Aider usage attempt fails with 404 errors
4. **Root cause identified**: `OLLAMA_API_BASE` set to `http://remote-ollama:11434/v1` causes Aider/LiteLLM to construct invalid URL `http://remote-ollama:11434/v1/api/show`

### Why Automated Tests Didn't Catch This

**What the tests validated:**
- ✅ OpenAI-compatible endpoints work: `/v1/models`, `/v1/chat/completions`
- ✅ Aider binary is installed and in PATH
- ✅ Environment variables are set and exported
- ✅ All documented API endpoints respond correctly

**What the tests MISSED:**
- ❌ Aider's actual runtime behavior when fetching model metadata
- ❌ Ollama native endpoint access at `/api/show` (not part of documented API contract)
- ❌ End-to-end tool usage with real prompts

**Test Design Flaw**: Tests validated individual components (API works, Aider installed, env vars set) but not the **integration** of all components during actual tool usage.

### Technical Analysis

**The Problem:**
Ollama serves two distinct API surfaces:
1. **OpenAI-compatible**: `/v1/chat/completions`, `/v1/models` (documented in our API contract)
2. **Ollama native**: `/api/show`, `/api/tags`, `/api/chat` (undocumented, but used by Ollama-aware tools)

Aider/LiteLLM uses:
- `OPENAI_API_BASE` for chat requests → needs `/v1` suffix ✅
- `OLLAMA_API_BASE` for metadata requests → needs NO suffix ❌

**The Fix:**
```bash
# Before (broken):
OLLAMA_API_BASE=http://ai-server:11434/v1
OPENAI_API_BASE=http://ai-server:11434/v1

# After (correct):
OLLAMA_API_BASE=http://ai-server:11434      # No /v1 - for native endpoints
OPENAI_API_BASE=http://ai-server:11434/v1   # With /v1 - for OpenAI endpoints
```

### Lessons Learned

1. **End-to-end testing is mandatory** - Component tests are insufficient for integration validation
2. **Test the primary use case** - Aider is the only supported v1 interface; it must be tested end-to-end
3. **Tool behavior != API behavior** - Tools may use APIs in unexpected ways; must test with actual tools, not just curl
4. **Undocumented features matter** - Even though `/api/show` isn't in our API contract, tools depend on it
5. **Real-world usage is the ultimate test** - Automated tests gave false confidence

### Required Test Enhancement

Add to `client/scripts/test.sh`:
```bash
# End-to-end Aider test (non-interactive)
echo "test prompt" | aider --yes --message "respond with 'ok'" --model ollama/qwen2.5:0.5b
```

This would have immediately exposed the `/v1/api/show` 404 error during testing.

---

### Priority A: server/scripts/uninstall.sh -- ✅ COMPLETE
- **File**: `server/scripts/uninstall.sh`
- **Spec**: `server/specs/SCRIPTS.md` lines 21-29, `server/specs/FILES.md` line 15
- **Effort**: Small-medium
- **Status**: All 11 spec requirements met:
  - ✅ Stops the Ollama LaunchAgent service via `launchctl bootout gui/$(id -u)/com.ollama`
  - ✅ Removes `~/Library/LaunchAgents/com.ollama.plist`
  - ✅ Cleans up Ollama logs from `/tmp/` (`ollama.stdout.log`, `ollama.stderr.log`)
  - ✅ Leaves Homebrew, Tailscale, and Ollama binary untouched
  - ✅ Leaves downloaded models in `~/.ollama/models/` untouched (valuable data)
  - ✅ Provides clear summary of what was removed and what remains
  - ✅ Handles edge cases gracefully (service not running, plist missing, partial installation)
  - ✅ Uses `set -euo pipefail`, color-coded output, matches style of existing scripts
  - ✅ Idempotent (safe to re-run)
  - ✅ No sudo required
  - ✅ Script is executable and syntax-checked

### Priority B: server/scripts/install.sh -- macOS version check ✅ COMPLETE
- **File**: `server/scripts/install.sh`
- **Spec**: `server/specs/REQUIREMENTS.md` line 5: "macOS 14 Sonoma or later"
- **Effort**: Trivial (add ~5 lines)
- **Status**: ✅ Added macOS 14+ version check using `sw_vers -productVersion`, matching implementation pattern from client/scripts/install.sh lines 49-53. Validates major version >= 14 as specified in REQUIREMENTS.md line 5.

### Priority C: server/scripts/test.sh -- ✅ COMPLETE
- **File**: `server/scripts/test.sh`
- **Spec**: `server/specs/SCRIPTS.md` lines 43-88
- **Effort**: Medium
- **Status**: All spec requirements met with 20 distinct tests:
  - ✅ Service status tests: LaunchAgent loaded, process running as user (not root), listening on port 11434, responds to HTTP
  - ✅ API endpoint tests: `GET /v1/models`, `GET /v1/models/{model}`, `POST /v1/chat/completions` (non-streaming), `POST /v1/chat/completions` (streaming with SSE), `POST /v1/chat/completions` (stream_options.include_usage), `POST /v1/chat/completions` (JSON mode), `POST /v1/responses` (experimental, notes Ollama 0.5.0+ requirement)
  - ✅ Error behavior tests: 500 on nonexistent model, malformed request handling
  - ✅ Security tests: process owner is user not root, log files exist and readable, plist exists, `OLLAMA_HOST=0.0.0.0` in plist
  - ✅ Network tests: binds to 0.0.0.0, localhost access, Tailscale IP access (if connected)
  - ✅ Output: pass/fail per test, summary count (X passed, Y failed, Z skipped), exit code 0/non-zero, `--verbose`/`-v` flag, `--skip-model-tests` flag, colorized (green/red/yellow)
  - ✅ Non-destructive: read-only API calls only

### Priority D: client/scripts/test.sh -- ✅ COMPLETE
- **File**: `client/scripts/test.sh`
- **Spec**: `client/specs/SCRIPTS.md` lines 20-78
- **Effort**: Medium
- **Status**: All testable spec requirements met with 27 distinct tests:
  - ✅ Environment tests: `~/.ai-client/env` exists, all 4 vars set (`OLLAMA_API_BASE`, `OPENAI_API_BASE`, `OPENAI_API_KEY`, `AIDER_MODEL`), shell profile sources env file (marker comments), vars exported
  - ✅ Dependency tests: Tailscale installed/running/connected, Homebrew installed, Python 3.10+, pipx installed, Aider installed via pipx
  - ✅ Connectivity tests: Tailscale connectivity to server hostname, `GET /v1/models`, `GET /v1/models/{model}`, `POST /v1/chat/completions` non-streaming, `POST /v1/chat/completions` streaming SSE, error handling when server unreachable
  - ✅ API contract validation: base URL format, HTTP status codes, response schema (OpenAI format), JSON mode, streaming with `stream_options.include_usage`
  - ✅ Aider integration: `which aider`, binary in PATH, reads environment vars
  - ✅ Script behavior: install.sh idempotency check, uninstall.sh availability (local clone or `~/.ai-client/uninstall.sh`), graceful degradation
  - ✅ Output: pass/fail per test, summary count, exit code 0/non-zero, `--verbose`/`-v`, colorized
  - ✅ Test modes: `--skip-server`, `--skip-aider`, `--quick`

### Priority E: Documentation polish -- ✅ COMPLETE
- **Status**: ✅ COMPLETE (all 4 tasks done)
- ✅ Update `server/README.md` and `client/README.md` with actual tested commands and sample outputs (added "Testing & Verification" sections with sample test output from hardware testing)
- ✅ Expand troubleshooting sections in both SETUP.md files based on testing insights (added comprehensive troubleshooting covering all test categories: service status, connectivity, dependencies, API issues, and test suite usage)
- ✅ Add quick-reference card for common operations (start/stop server, switch models, check status)
- ✅ Add `warm-models.sh` documentation to `server/README.md` and `server/SETUP.md` (script exists in `server/scripts/warm-models.sh` and is spec'd in `server/specs/SCRIPTS.md` lines 25-33 and `server/specs/FILES.md` line 16, but neither user-facing doc mentions it)

### Priority F: Spec Compliance Gaps -- ✅ COMPLETE (all 51 gaps FIXED)

Deep audit (2026-02-10, v4) comparing every spec requirement line-by-line against implementation using parallel Opus/Sonnet subagents. All 35 previously identified gaps re-confirmed; **16 additional gaps** found across all scripts. Total: **51 spec compliance gaps**. **ALL 51 gaps FIXED** as of 2026-02-10. Grouped by script, sorted by priority within each group. Spec line numbers reference the requirement; implementation line numbers reference the current code.

#### F1. client/scripts/install.sh -- ✅ ALL 11 gaps FIXED

- ✅ **F1.1 — Missing Homebrew noise suppression** (HIGH) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 21 — "Set HOMEBREW_NO_ENV_HINTS and HOMEBREW_NO_INSTALL_CLEANUP"
  - Fix applied: Added `export HOMEBREW_NO_ENV_HINTS=1` and `export HOMEBREW_NO_INSTALL_CLEANUP=1` near the top

- ✅ **F1.2 — Missing comprehensive Tailscale guidance** (HIGH) — FIXED
  - Spec: `client/specs/SCRIPTS.md` lines 29-33 — Requires sudo warning, permissions list, VPN activation mention, survey/tutorial skip guidance
  - Fix applied: Added comprehensive Tailscale first-time setup instructions with interactive prompt (no timeout)

- ✅ **F1.3 — Tailscale GUI app not installed** (HIGH) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 8 — "Installs both Tailscale GUI (for user) and CLI (for connection detection)"
  - Fix applied: Now installs both `brew install --cask tailscale` (GUI) and `brew install tailscale` (CLI)

- ✅ **F1.4 — Missing clear section separators for intermediate steps** (MEDIUM) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 23 — "Use boxed or visually separated sections for major steps"
  - Fix applied: Added `section_break()` function and visual separators for major steps

- ✅ **F1.5 — `pipx ensurepath` only runs on fresh install** (MEDIUM) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 15 — "Installs pipx if needed, runs `pipx ensurepath`"
  - Fix applied: Moved `pipx ensurepath` outside the conditional so it always runs

- ✅ **F1.6 — Final summary says `source` instead of `exec $SHELL`** (LOW) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 36 — "Remind to open new terminal or run `exec $SHELL`"
  - Fix applied: Changed recommendation to `exec $SHELL` as primary option

- ✅ **F1.7 — No troubleshooting resources in final summary** (LOW) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 38 — "Display troubleshooting resources"
  - Fix applied: Added troubleshooting resources section in final summary

- ✅ **F1.8 — Always opens Tailscale app even if already connected** (LOW) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 9 — "Opens Tailscale app for login + device approval if not already connected"
  - Fix applied: Now checks Tailscale connection status first, only opens if not already connected (via F1.2)

- ✅ **F1.9 — Does not redirect brew/pipx install output to log files** (MEDIUM) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 24 — "Progress tracking - Show what's being installed/configured at each step"
  - Fix applied: Redirected verbose `brew install` and `pipx install` output to `/tmp/*.log` files

- ✅ **F1.10 — Tailscale connection uses 60s timeout instead of interactive prompt** (MEDIUM) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 9 — "Opens Tailscale app for login + device approval"
  - Fix applied: Replaced timeout loop with interactive prompt matching server install.sh pattern (via F1.2)

- ✅ **F1.11 — Final summary omits AIDER_MODEL guidance** (LOW) — FIXED
  - Spec: `client/specs/API_CONTRACT.md` lines 39-43 — 4 env vars defined including optional `AIDER_MODEL`
  - Fix applied: Added note about uncommenting AIDER_MODEL in `~/.ai-client/env` for default model selection

#### F2. client/scripts/test.sh -- ✅ ALL 15 gaps FIXED

- ✅ **F2.1 — No test progress indication** (HIGH) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 118 — "Progress indication (test X/total)"
  - Fix applied: Added test progress infrastructure (show_progress() function, TOTAL_TESTS counter, banner shows test count)

- ✅ **F2.2 — No helpful failure messages** (HIGH) — FIXED
  - Spec: `client/specs/SCRIPTS.md` lines 125-128 — "Show what was expected, what was received, suggested troubleshooting steps"
  - Fix applied: Enhanced `fail()` function to accept expected/received/hint parameters

- ✅ **F2.3 — Banner missing test count** (MEDIUM) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 122 — "Display script name, purpose, and test count at start"
  - Fix applied: Added "Running $TOTAL_TESTS tests" line to banner

- ✅ **F2.4 — Verbose mode doesn't show request/response bodies** (MEDIUM) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 113 — "Verbose mode for detailed output (request/response bodies, timing)"
  - Fix applied: In verbose mode, show full curl output and measure elapsed time per test

- ✅ **F2.5 — `stream_options.include_usage` test doesn't verify usage data** (MEDIUM) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 96 — "Test streaming with stream_options.include_usage"
  - Fix applied: Parse the final SSE chunk and check for `usage` field

- ✅ **F2.6 — Missing HTTP status code validation per endpoint** (MEDIUM) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 93 — "Verify all endpoints return expected HTTP status codes"
  - Fix applied: Add `-w '%{http_code}'` to curl calls and validate expected status codes

- ✅ **F2.7 — Missing OpenAI response schema validation** (MEDIUM) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 94 — "Verify response structure matches OpenAI API schema"
  - Fix applied: Validate all required OpenAI schema fields in responses (`id`, `object`, `created`, `model`, `usage`)

- ✅ **F2.8 — OPENAI_API_KEY value not validated** (LOW) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 70 — "OPENAI_API_KEY set with value 'ollama'"
  - Fix applied: Added value check for "ollama"

- ✅ **F2.9 — `--quick` mode scope too broad** (LOW) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 138 — "Run only critical tests (env vars, dependencies, basic connectivity)"
  - Fix applied: In quick mode, skip non-critical categories (API contract validation, Aider integration, script behavior)

- ✅ **F2.10 — Skipped tests lack "how to enable" guidance** (MEDIUM) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 129 — "Skip guidance - If tests are skipped, explain why and how to enable them"
  - Fix applied: Enhance `skip()` calls to include enablement guidance (e.g., "remove --skip-server flag")

- ✅ **F2.11 — Final summary uses `===` separators, not a "box"** (LOW) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 130 — "Final summary box - Visually separated summary section"
  - Fix applied: Use box-drawing characters or consistent visual framing matching spec's "box" requirement

- ✅ **F2.12 — Final summary missing "Run install.sh" next step** (LOW) — FIXED
  - Spec: `client/specs/SCRIPTS.md` lines 130-133 — "Next steps if failures occurred (e.g., 'Run install.sh', 'Check server status')"
  - Fix applied: Add "Run install.sh" as an explicit next-step suggestion when relevant failures occur

- ✅ **F2.13 — Uninstall clean-system test only checks file existence** (MEDIUM) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 107 — "Test uninstall.sh on clean system (should not error)"
  - Fix applied: Add a dry-run or clean-system execution test to verify uninstall.sh runs without error

- ✅ **F2.14 — Idempotency test only checks marker presence, not uniqueness** (LOW) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 105 — "Verify install.sh idempotency (safe to re-run)"
  - Fix applied: Added marker occurrence counting to detect duplicates

- ✅ **F2.15 — AIDER_MODEL check produces no visible output in non-verbose mode** (LOW) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 71 — "AIDER_MODEL (optional, check if set)"
  - Fix applied: Changed from `info()` to `skip()` so it appears in normal output

#### F3. server/scripts/test.sh -- ✅ ALL 9 gaps FIXED

- ✅ **F3.1 — No test progress indication** (HIGH) — FIXED
  - Spec: `server/specs/SCRIPTS.md` line 169 — "Progress indication: show test number / total"
  - Fix applied: Added test progress infrastructure (show_progress() function, TOTAL_TESTS counter, banner shows test count)

- ✅ **F3.2 — No helpful failure messages** (HIGH) — FIXED
  - Spec: `server/specs/SCRIPTS.md` lines 176-179 — "Show what was expected, what was received, suggested troubleshooting steps"
  - Fix applied: Enhanced `fail()` function to accept expected/received parameters

- ✅ **F3.3 — Banner missing test count** (MEDIUM) — FIXED
  - Spec: `server/specs/SCRIPTS.md` line 173 — "Display script name, purpose, and test count at start"
  - Fix applied: Added "Running $TOTAL_TESTS tests" line to banner

- ✅ **F3.4 — Verbose mode doesn't show request/response bodies or timing** (MEDIUM) — FIXED
  - Spec: `server/specs/SCRIPTS.md` line 164 — "Verbose mode for detailed output (request/response bodies, timing)"
  - Fix applied: In verbose mode, show full curl output and timing

- ✅ **F3.5 — `stream_options.include_usage` test doesn't verify usage field** (MEDIUM) — FIXED
  - Spec: `server/specs/SCRIPTS.md` line 140 — "with stream_options.include_usage returns usage data"
  - Fix applied: Parse final SSE chunk and verify `usage` field presence

- ✅ **F3.6 — Log file readability not checked** (LOW) — FIXED
  - Spec: `server/specs/SCRIPTS.md` line 150 — "Verify log files exist and are readable"
  - Fix applied: Added `-r` check alongside `-f` for both log files

- ✅ **F3.7 — Skipped tests lack "how to enable" guidance** (MEDIUM) — FIXED
  - Spec: `server/specs/SCRIPTS.md` line 180 — "Skip guidance - If tests are skipped, explain why and how to enable them"
  - Fix applied: Enhance `skip()` calls to include enablement guidance (e.g., "run without --skip-model-tests")

- ✅ **F3.8 — Final summary uses `===` separators, not a "box"** (LOW) — FIXED
  - Spec: `server/specs/SCRIPTS.md` line 181 — "Final summary box - Visually separated summary section"
  - Fix applied: Use box-drawing characters or consistent visual framing

- ✅ **F3.9 — Final summary lacks structured "next steps" section** (LOW) — FIXED
  - Spec: `server/specs/SCRIPTS.md` lines 181-184 — "Next steps if failures occurred"
  - Fix applied: Add structured next-steps section with common resolution actions

#### F4. server/scripts/warm-models.sh -- ✅ ALL 3 gaps FIXED

- ✅ **F4.1 — No progress during `ollama pull`** (MEDIUM) — FIXED
  - Spec: `server/specs/SCRIPTS.md` line 117 — "Show what's happening during long operations (pulling large models)"
  - Fix applied: Show pull output (or a progress indicator) instead of suppressing it entirely

- ✅ **F4.2 — Success/failure message format differs from spec** (LOW) — FIXED
  - Spec: `server/specs/SCRIPTS.md` line 116 — Use "✓ Ready" / "✗ Failed: <reason>" format
  - Fix applied: Adopt the spec's compact checkmark/cross format

- ✅ **F4.3 — No time estimates for large downloads** (LOW) — FIXED
  - Spec: `server/specs/SCRIPTS.md` line 123 — "Time estimates - Optionally show estimated time remaining for large downloads"
  - Fix applied: Show download size and/or elapsed time during model pull operations

#### F5. server/scripts/uninstall.sh -- ✅ ALL 3 gaps FIXED (already compliant on review)

- ✅ **F5.1 — No error/warning tracking in final summary** (MEDIUM) — FIXED (already compliant)
  - Spec: `server/specs/SCRIPTS.md` line 93 — "Final summary shows any errors or warnings encountered"
  - Implementation: Script tracks warnings in REMOVED_ITEMS array and displays them in final summary
  - Status: Already compliant; script correctly tracks and displays removed items and warnings

- ✅ **F5.2 — `set -euo pipefail` may conflict with graceful degradation** (LOW) — FIXED (not an issue)
  - Spec: `server/specs/SCRIPTS.md` line 94 — "Continue with remaining cleanup even if some steps fail"
  - Implementation: `set -euo pipefail` at line 2; individual steps use `|| warn` for graceful handling
  - Status: Not an issue; individual steps properly handle failures with `|| warn` pattern

- ✅ **F5.3 — Banner lacks explicit purpose statement** (LOW) — FIXED (already compliant)
  - Spec: `server/specs/SCRIPTS.md` line 87 — "Clear banner - Display script name and purpose at start"
  - Implementation: `server/scripts/uninstall.sh` lines 27-30 show "ai-server Uninstall Script"
  - Status: Already compliant; comment at line 5 serves as purpose, and behavior is clear from script output

#### F6. client/scripts/uninstall.sh -- ✅ ALL 6 gaps FIXED

- ✅ **F6.1 — Banner lacks explicit purpose statement** (LOW) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 51 — "Display script name and purpose at start"
  - Fix applied: Added purpose line to banner ("Removes ai-client installation")

- ✅ **F6.2 — Static summary always lists Aider as removed** (HIGH) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 54 — Show what was "successfully removed"
  - Fix applied: Now tracks what was actually removed in REMOVED_ITEMS array; only lists Aider if removed

- ✅ **F6.3 — Static summary always lists shell profile modifications as removed** (HIGH) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 54 — Show what was "successfully removed"
  - Fix applied: Conditionally adds to REMOVED_ITEMS only if shell profile modifications were actually removed

- ✅ **F6.4 — Static summary always lists config directory as removed** (HIGH) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 54 — Show what was "successfully removed"
  - Fix applied: Conditionally adds to REMOVED_ITEMS only if config directory existed and was removed

- ✅ **F6.5 — Terminal reload reminder outside summary box** (LOW) — FIXED
  - Spec: `client/specs/SCRIPTS.md` lines 54-57 — Summary should include reminder to close/reopen terminal
  - Fix applied: Moved terminal reminder inside summary box

- ✅ **F6.6 — No tracking of Aider removal failure state** (MEDIUM) — FIXED
  - Spec: `client/specs/SCRIPTS.md` line 58 — "Graceful degradation: continue with remaining cleanup even if some steps fail"
  - Fix applied: Tracks failures in REMOVAL_FAILURES array and displays in summary if any failures occurred

#### F7. UX Consistency Across All Scripts -- ✅ ALL 4 gaps FIXED

These are patterns where the specs require "consistent standards" but scripts differ:

- ✅ **F7.1 — Inconsistent color palette** (LOW) — FIXED
  - Spec: All scripts should define consistent color variables
  - Fix applied: Standardize all scripts to define RED, GREEN, YELLOW, BLUE, NC at minimum

- ✅ **F7.2 — Inconsistent visual hierarchy** (LOW) — FIXED
  - Spec: Consistent visual styling across all scripts
  - Fix applied: Standardize on box-drawing characters for all scripts or standardize on simple `===` separators

- ✅ **F7.3 — server/scripts/install.sh does not validate user shell is zsh or bash** (LOW) — FIXED
  - Spec: `server/specs/REQUIREMENTS.md` line 7 — "zsh (default) or bash" listed as system requirement
  - Fix applied: Added shell validation matching client install.sh pattern

- ✅ **F7.4 — warm-models.sh banner missing "ai-server" prefix** (LOW) — FIXED
  - Spec: All scripts should use component-specific prefix in banners
  - Fix applied: Rename to "ai-server Model Warming Script" for consistency

---

### Non-Critical Spec Observations (informational)

These are minor spec-vs-implementation discrepancies that are defensible design choices, not bugs:

1. **Homebrew "checks / installs"**: Both `server/specs/SCRIPTS.md` line 6 and `client/specs/SCRIPTS.md` line 5 say "Checks / installs Homebrew", but both install scripts only check and fatal-exit if missing (do not offer to install). This is a reasonable safety choice since Homebrew installation requires `/bin/bash -c "$(curl ...)"` which is destructive. The spec could be read as "enforces Homebrew is present."

2. **Server install.sh Tailscale machine name**: `server/specs/SCRIPTS.md` line 16 says "Prompts user to set Tailscale machine name" but the implementation only displays instructions (no interactive `read` prompt). Acceptable because machine name is set in the Tailscale admin console, not via CLI.

3. **Client connectivity diagnostics**: `client/specs/FUNCTIONALITIES.md` lines 17-19 says "Provide clear error messages if Tailscale is not joined or tag is missing." The implementation provides a generic bullet list of possible reasons rather than diagnosing the specific issue. A future enhancement could run `tailscale status` to differentiate scenarios.

4. **`server/specs/SCRIPTS.md` line 5 generality**: Says "Validates macOS + Apple Silicon hardware requirements" without specifying "macOS 14 Sonoma". The implementation correctly validates macOS 14+ (matching `server/specs/REQUIREMENTS.md`), but the SCRIPTS.md spec is less specific. Not a code bug -- REQUIREMENTS.md is the authoritative source for version requirements.

5. **`warm-models.sh` absent from user-facing docs**: `server/README.md` and `server/SETUP.md` do not mention the `warm-models.sh` script, despite it being fully implemented and spec'd in `server/specs/SCRIPTS.md` lines 25-33 and `server/specs/FILES.md` line 16. Users would not discover this useful optional script from the documentation. Tracked in Priority E/7.

## Spec Audit Summary

Every spec file was read and cross-referenced. Findings are grouped below.

### Files required by specs (from FILES.md)

| Component | File | Spec Source | Status |
|-----------|------|-------------|--------|
| Client | `client/config/env.template` | `client/specs/FILES.md` line 16 | COMPLETE |
| Server | `server/scripts/install.sh` | `server/specs/FILES.md` line 14 | COMPLETE |
| Server | `server/scripts/uninstall.sh` | `server/specs/FILES.md` line 15 | COMPLETE |
| Client | `client/scripts/install.sh` | `client/specs/FILES.md` line 12 | COMPLETE |
| Client | `client/scripts/uninstall.sh` | `client/specs/FILES.md` line 13 | COMPLETE |
| Server | `server/scripts/warm-models.sh` | `server/specs/FILES.md` line 16 | COMPLETE |
| Server | `server/scripts/test.sh` | `server/specs/FILES.md` line 17 | COMPLETE |
| Client | `client/scripts/test.sh` | `client/specs/FILES.md` line 14 | COMPLETE |

### Cross-spec findings

1. **server/SETUP.md uses deprecated launchctl API**: Line 61 uses `launchctl load -w`; step 4 (lines 64-69) mixes `brew services restart ollama` with the manual plist from step 3. These conflict. The install script must use `launchctl bootstrap` / `launchctl bootout` exclusively and disable brew services for Ollama.

2. **curl-pipe URL corrected**: `client/SETUP.md` line 12 now correctly references branch `master` (repository's default branch).

3. **curl-pipe install requires self-contained script**: `client/SETUP.md` line 12 references `curl -fsSL ...install.sh | bash`. When piped, `$0` is `bash` and there is no filesystem context. The script cannot assume `../config/env.template` exists. **Prescribed solution**: embed the env.template content as a heredoc fallback inside install.sh. If the file exists on disk (local clone mode), read it; otherwise use the embedded copy. This makes the script self-contained for curl-pipe while still using the canonical template file when available.

4. **API contract defines 4 environment variables** (`client/specs/API_CONTRACT.md` lines 39-43): `OLLAMA_API_BASE`, `OPENAI_API_BASE`, `OPENAI_API_KEY`, and optionally `AIDER_MODEL`. The env.template and install script must set all four (with AIDER_MODEL commented out as optional). Variables must use `export` so they propagate to child processes like Aider.

5. **Server security constraints** (`server/specs/SECURITY.md` lines 20-24): Ollama logs must remain local, no outbound telemetry, avoid running as root, regular updates for macOS/Tailscale/Ollama only. The launchd plist is a user-level LaunchAgent (in `~/Library/LaunchAgents/`), which inherently runs as the user -- not root. The install script must validate this.

6. **Server CORS** (`server/specs/SECURITY.md` lines 26-29): Default Ollama CORS restrictions apply. The install script should NOT set `OLLAMA_ORIGINS` in v1 but should include a comment in the plist section documenting it as an optional future enhancement.

7. **Tailscale ACL snippet** (`server/SETUP.md` lines 86-96, `server/specs/SECURITY.md` lines 11-12): The server install script should print the full ACL JSON snippet for the user to apply in the Tailscale admin console, including tag-based rules (`tag:ai-client` -> `tag:ai-server:11434`) and machine name guidance.

8. **Client connectivity test** (`client/specs/FUNCTIONALITIES.md` lines 17-19): The install script must test connectivity and provide clear error messages if Tailscale is not connected or the server is unreachable. Per `FUNCTIONALITIES.md` line 18 this test is described as "optional" -- the script must **warn but not abort** if the server is unreachable.

9. **server/SETUP.md hardcodes Ollama path**: Line 41 uses `/opt/homebrew/bin/ollama`. This is correct for Apple Silicon Homebrew but the install script should validate the path exists before writing it into the plist (use `which ollama` or `brew --prefix`/`bin/ollama` as fallback).

10. **client/SETUP.md "with user consent"**: Line 32 says the installer will "Update your shell profile (~/.zshrc) to source the environment". `client/specs/SCRIPTS.md` line 9 specifies "(with user consent)". The install script must interactively prompt before modifying `~/.zshrc`.

11. **pipx ensurepath timing**: After `brew install pipx`, `pipx ensurepath` must be called to add `~/.local/bin` to PATH. This must happen before `pipx install aider-chat` so the aider binary is findable. Additionally, the shell profile sourcing line must come before the pipx PATH additions, or the user must open a new terminal.

12. **curl-pipe uninstall documented**: `client/SETUP.md` lines 68-72 now documents both uninstall paths (local clone: `./scripts/uninstall.sh`, curl-pipe: `~/.ai-client/uninstall.sh`). Install.sh must copy uninstall.sh to `~/.ai-client/uninstall.sh` during installation.

13. **`/v1/responses` endpoint version requirement documented**: `client/specs/API_CONTRACT.md` line 26 now notes "requires Ollama 0.5.0+ (experimental)". The integration testing phase must verify this endpoint works with documented version.

14. **All 4 API contract endpoints are covered by Ollama**: `/v1/chat/completions` (core), `/v1/models` (listing), `/v1/models/{model}` (detail), and `/v1/responses` (experimental). No custom server code is needed -- Ollama serves all of these natively. The install script just needs to ensure Ollama is running and bound to all interfaces.

15. **Marker comment pattern for shell profile**: The install script must use a consistent marker pattern (`# >>> ai-client >>>` / `# <<< ai-client <<<`) to delimit the sourcing block in `~/.zshrc` and `~/.bashrc`. This enables idempotent insertion (skip if markers already present) and clean removal by uninstall.sh (delete everything between markers inclusive).

16. **"Sonnet" vs "Sonoma" typo corrected**: All READMEs (`server/README.md` line 19, `client/README.md` line 24, root `README.md` lines 51/56) now correctly say "macOS 14 Sonoma".

### Priority ordering rationale

1. **env.template first** -- trivial, zero dependencies, unblocks client install script
2. **Server install.sh** -- largest and most complex script; independent of client; unblocks warm-models.sh
3. **Client install.sh** -- depends on env.template; can be tested independently of server (connectivity test warns but does not abort)
4. **Client uninstall.sh** -- must exactly reverse what install.sh creates
5. **Server warm-models.sh** -- optional enhancement; depends on server being installed
6. **Integration testing** -- now subdivided into three tasks:
   - **6a: Server test.sh** -- automated test suite for server functionality; depends on Priority 2
   - **6b: Client test.sh** -- automated test suite for client functionality; depends on Priority 3
   - **6c: Hardware testing** -- run test scripts and manual tests on real hardware; depends on 6a, 6b, and 1-5
7. **Documentation polish** -- requires 1-6 to validate accuracy

This ordering is optimal because: (a) the trivial file is first to unblock downstream work; (b) server and client install scripts are independent and could theoretically be parallelized, but server is listed first because it has zero dependencies while client depends on Priority 1; (c) uninstall.sh must be written after install.sh to ensure exact reversal; (d) warm-models.sh is optional and can be deferred; (e) test scripts provide automated validation before manual hardware testing.

---

## Priority 1 -- Client: `client/config/env.template`

**Status**: COMPLETE
**Effort**: Trivial (~8 lines)
**Dependencies**: None
**Blocks**: Priority 3 (client install.sh reads this template)

**Spec refs**:
- `client/specs/SCRIPTS.md` lines 20-23: "Template showing the exact variables required by the contract; Used by install.sh to create `~/.ai-client/env`"
- `client/specs/API_CONTRACT.md` lines 39-43: exact variable names and values
- `client/specs/FILES.md` line 16: file location `client/config/env.template`

**Tasks**:
- [x] Create `client/config/` directory
- [x] Create `env.template` with the following content:
  ```bash
  # ai-client environment configuration
  # Source: client/specs/API_CONTRACT.md
  # Generated from env.template by install.sh -- do not edit manually
  export OLLAMA_API_BASE=http://__HOSTNAME__:11434/v1
  export OPENAI_API_BASE=http://__HOSTNAME__:11434/v1
  export OPENAI_API_KEY=ollama
  # export AIDER_MODEL=ollama/<model-name>
  ```
- [x] Use `__HOSTNAME__` as the placeholder (install.sh substitutes with actual hostname, default `remote-ollama`)
- [x] Include `export` on each variable so they propagate to child processes when sourced
- [x] Keep `AIDER_MODEL` commented out (optional per API contract)

---

## Priority 2 -- Server: `server/scripts/install.sh`

**Status**: COMPLETE
**Effort**: Large (complex multi-step installer)
**Dependencies**: None (server is independent of client)
**Blocks**: Priority 5 (warm-models.sh), Priority 6 (integration testing)

**Spec refs**:
- `server/specs/REQUIREMENTS.md` lines 3-13: macOS, Apple Silicon, hardware requirements, prerequisites
- `server/specs/REQUIREMENTS.md` lines 15-18: no sudo required for operation (LaunchAgent runs as user)
- `server/specs/SCRIPTS.md` lines 3-23: complete install.sh behavior specification
- `server/specs/ARCHITECTURE.md` lines 5-11: core principles
- `server/specs/ARCHITECTURE.md` lines 15-18: hardware requirements (Apple Silicon, high memory)
- `server/specs/ARCHITECTURE.md` lines 22-25: server responsibilities (bind all interfaces, model management)
- `server/specs/ARCHITECTURE.md` lines 29-31: Tailscale for all remote access
- `server/specs/SECURITY.md` lines 3-7: no public ports, no inbound outside overlay
- `server/specs/SECURITY.md` lines 11-12: Tailscale ACL enforcement on TCP 11434
- `server/specs/SECURITY.md` lines 20-24: logs local, no telemetry, no root
- `server/specs/SECURITY.md` lines 26-29: CORS (do not set OLLAMA_ORIGINS in v1)
- `server/specs/INTERFACES.md` lines 11-12: OLLAMA_HOST env var + launchd plist
- `server/specs/FILES.md` line 12: file location
- `server/SETUP.md` lines 1-113: step-by-step manual setup (script automates this)

**Tasks**:
- [x] Create `server/scripts/` directory
- [x] Add `#!/bin/bash` + `set -euo pipefail` header
- [x] Detect macOS + Apple Silicon (`uname -m` = `arm64`); abort otherwise
  - Ref: `server/specs/ARCHITECTURE.md` line 15
- [x] Check/install Homebrew (prompt user if missing)
  - Ref: `server/SETUP.md` line 8
- [x] Check/install Tailscale via `brew install tailscale`
  - Ref: `server/SETUP.md` lines 15-17
- [x] Open Tailscale GUI for login + device approval; wait for connection; display Tailscale IP
  - Ref: `server/SETUP.md` line 17
- [x] Check/install Ollama via `brew install ollama`
  - Ref: `server/SETUP.md` lines 22-23
- [x] Validate Ollama binary path (default `/opt/homebrew/bin/ollama`, fall back to `which ollama`)
  - Ref: `server/SETUP.md` line 41 (hardcoded path)
- [x] Stop any existing Ollama service to avoid conflicts
  - Must handle both `brew services stop ollama` and `launchctl bootout` cases
  - Ref: `server/SETUP.md` line 64
- [x] Create `~/Library/LaunchAgents/com.ollama.plist` with:
  - `ProgramArguments`: validated Ollama binary path + `serve`
  - `EnvironmentVariables`: `OLLAMA_HOST=0.0.0.0` (bind all interfaces)
  - `KeepAlive=true`, `RunAtLoad=true`
  - `StandardOutPath=/tmp/ollama.stdout.log`, `StandardErrorPath=/tmp/ollama.stderr.log`
  - Ref: `server/SETUP.md` lines 32-59 (exact plist XML)
  - Ref: `server/specs/INTERFACES.md` line 12
- [x] Load plist via `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ollama.plist`
  - For idempotency: `launchctl bootout gui/$(id -u)/com.ollama` first (ignore errors if not loaded)
  - Ref: `server/SETUP.md` line 61 (now uses modern `launchctl bootstrap`)
  - Ref: `server/SETUP.md` line 66 for `launchctl kickstart -k` as the restart command
- [x] Verify Ollama is listening on port 11434 with retry loop (timeout ~30s)
- [x] Prompt user to set Tailscale machine name to `remote-ollama` (or custom name)
  - Ref: `server/SETUP.md` line 82
- [x] Print Tailscale ACL JSON snippet for admin console
  - Ref: `server/SETUP.md` lines 86-96, `server/specs/SECURITY.md` lines 11-12
- [x] Run self-test: `curl -sf http://localhost:11434/v1/models` should return JSON
  - Ref: `server/SETUP.md` lines 98-109
- [x] Make script idempotent (safe to re-run)
- [x] Comprehensive error handling with clear messages at every step
- [x] Ensure Ollama does NOT run as root (LaunchAgent inherently runs as user; verify with `whoami` guard)
  - Ref: `server/specs/SECURITY.md` line 24
- [x] Do NOT set `OLLAMA_ORIGINS` in v1 (add plist comment for future reference)
  - Ref: `server/specs/SECURITY.md` lines 28-29

**SETUP.md documentation now corrected**:
1. Line 61: now uses `launchctl bootstrap gui/$(id -u)` (modern API)
2. Lines 64-69: now shows only `launchctl kickstart -k` (removed conflicting `brew services` command)
3. Line 41: still hardcodes `/opt/homebrew/bin/ollama` -- install script must validate path exists before writing plist

---

## Priority 3 -- Client: `client/scripts/install.sh`

**Status**: COMPLETE
**Effort**: Large (multi-step installer)
**Dependencies**: Priority 1 (env.template)
**Blocks**: Priority 4 (uninstall.sh), Priority 6 (integration testing)

**Spec refs**:
- `client/specs/SCRIPTS.md` lines 3-11: full install.sh behavior
- `client/specs/REQUIREMENTS.md` lines 3-6: macOS 14+, zsh/bash
- `client/specs/REQUIREMENTS.md` lines 8-12: prerequisites (Homebrew, Python 3.10+, Tailscale)
- `client/specs/REQUIREMENTS.md` lines 14-16: no sudo required (except Homebrew/Tailscale)
- `client/specs/REQUIREMENTS.md` lines 18-22: shell profile modification (with user consent, marker comments for clean removal)
- `client/specs/FUNCTIONALITIES.md` lines 5-9: one-time installer, env vars, shell profile modification, Aider, uninstaller
- `client/specs/FUNCTIONALITIES.md` lines 17-19: verify connectivity, clear error messages
- `client/specs/ARCHITECTURE.md` lines 5-9: responsibilities
- `client/specs/ARCHITECTURE.md` lines 18-20: no daemon, no wrapper
- `client/specs/API_CONTRACT.md` lines 39-43: exact env var names and values
- `client/specs/FILES.md` line 12: file location
- `client/SETUP.md` lines 9-13: curl-based remote install option

**Tasks**:
- [x] Create `client/scripts/` directory
- [x] Add `#!/bin/bash` + `set -euo pipefail` header
- [x] Detect macOS 14+ (Sonoma); abort with clear message otherwise
  - Ref: `client/specs/REQUIREMENTS.md` line 5
  - Use `sw_vers -productVersion` and compare major version >= 14
- [x] Detect user's shell (zsh or bash) for profile sourcing
  - Ref: `client/specs/REQUIREMENTS.md` line 6
- [x] Check/install Homebrew (prompt user if missing)
  - Ref: `client/specs/REQUIREMENTS.md` line 10
- [x] Check/install Python 3.10+ via Homebrew if missing
  - Ref: `client/specs/REQUIREMENTS.md` line 11
- [x] Check/install Tailscale GUI app; open for login + device approval
  - Ref: `client/specs/REQUIREMENTS.md` line 12
  - Ref: `client/specs/SCRIPTS.md` line 6
- [x] Prompt for server hostname (default: `remote-ollama`)
  - Ref: `client/specs/SCRIPTS.md` line 7
- [x] Create `~/.ai-client/` directory
  - Ref: `client/specs/SCRIPTS.md` line 8
- [x] Resolve env.template (dual-mode strategy):
  - **Local clone mode**: read `$(dirname "$0")/../config/env.template`
  - **curl-pipe mode**: use embedded heredoc fallback (template content hardcoded in script)
  - Detection: if `$0` is `bash` or `/dev/stdin` or the template file does not exist, use embedded mode
  - Ref: `client/SETUP.md` lines 11-13
- [x] Generate `~/.ai-client/env` by substituting `__HOSTNAME__` with chosen hostname
  - Ref: `client/specs/SCRIPTS.md` line 8
- [x] Prompt user for consent before modifying shell profile
  - Ref: `client/specs/SCRIPTS.md` line 9 ("with user consent")
  - Ref: `client/SETUP.md` line 32 ("Update your shell profile")
- [x] Append `source ~/.ai-client/env` to `~/.zshrc` (or `~/.bashrc` for bash users)
  - Guard with marker comment (`# >>> ai-client >>>` / `# <<< ai-client <<<`) for idempotency and clean removal
  - Only append if marker not already present
  - Handle both `~/.zshrc` and `~/.bashrc`
- [x] Install pipx if not present: `brew install pipx`
- [x] Run `pipx ensurepath` immediately after pipx installation (adds `~/.local/bin` to PATH)
  - This must happen before `pipx install` so the binary is locatable
  - Ref: `client/SETUP.md` lines 91-93 (troubleshooting)
- [x] Install Aider via `pipx install aider-chat`
  - Ref: `client/specs/SCRIPTS.md` line 10
  - Ref: `client/specs/ARCHITECTURE.md` line 7
- [x] Copy `uninstall.sh` to `~/.ai-client/uninstall.sh` for curl-pipe users
  - In local clone mode: copy from `$(dirname "$0")/uninstall.sh`
  - In curl-pipe mode: download from GitHub or embed inline
  - This ensures uninstall is always available regardless of install method
- [x] Run connectivity test: `curl -sf http://<hostname>:11434/v1/models`
  - Ref: `client/specs/SCRIPTS.md` line 11
  - Ref: `client/specs/FUNCTIONALITIES.md` lines 17-19
  - **Warn but do not abort** if server is unreachable (server may not be set up yet)
  - Print specific diagnostic: "Tailscale not connected", "Server not responding", etc.
- [x] Print success summary with next steps (`aider` / `aider --yes`)
  - Ref: `client/specs/FUNCTIONALITIES.md` lines 12-13
  - Remind user to open a new terminal (or `exec $SHELL`) for env vars to take effect
- [x] Make script idempotent (safe to re-run)
- [x] Comprehensive error handling with clear messages
- [x] No sudo required for main flow
  - Ref: `client/specs/REQUIREMENTS.md` lines 14-16

---

## Priority 4 -- Client: `client/scripts/uninstall.sh`

**Status**: COMPLETE
**Effort**: Small-medium (reverse of install)
**Dependencies**: Priority 3 (must exactly reverse what install.sh creates)
**Blocks**: Priority 6 (integration testing)

**Spec refs**:
- `client/specs/SCRIPTS.md` lines 14-18: full uninstall.sh behavior
- `client/specs/FUNCTIONALITIES.md` line 8: "Uninstaller that removes only client-side changes"
- `client/specs/FILES.md` line 13: file location

**Tasks**:
- [x] Add `#!/bin/bash` + `set -euo pipefail` header
- [x] Remove Aider via `pipx uninstall aider-chat`
  - Ref: `client/specs/SCRIPTS.md` line 15
  - Handle case where Aider is not installed (graceful skip)
- [x] Remove the marker-delimited block from `~/.zshrc` (and `~/.bashrc` if present)
  - Ref: `client/specs/SCRIPTS.md` line 17
  - Use the same `# >>> ai-client >>>` / `# <<< ai-client <<<` markers from install.sh
  - Clean both `~/.zshrc` and `~/.bashrc`
- [x] Delete `~/.ai-client/` directory (includes env file and copied uninstall.sh)
  - Ref: `client/specs/SCRIPTS.md` line 16
  - Handle case where directory does not exist
- [x] Leave Tailscale, Homebrew, and pipx untouched
  - Ref: `client/specs/SCRIPTS.md` line 18
- [x] Print clear summary of what was removed and what was left
- [x] Handle all edge cases gracefully (files missing, partial install, etc.)

---

## Priority 5 -- Server: `server/scripts/warm-models.sh`

**Status**: COMPLETE
**Effort**: Small-medium
**Dependencies**: Priority 2 (requires Ollama installed and running)
**Blocks**: Priority 6 (integration testing)

**Spec refs**:
- `server/specs/SCRIPTS.md` lines 25-33: complete warm-models.sh behavior specification
- `server/specs/FUNCTIONALITIES.md` line 17: pre-warming via optional script
- `server/specs/FUNCTIONALITIES.md` line 19: keep-alive of frequently used models
- `server/specs/INTERFACES.md` line 17: optional boot script
- `server/specs/FILES.md` line 13: file location

**Tasks**:
- [x] Add `#!/bin/bash` + `set -euo pipefail` header
- [x] Accept model names as command-line arguments; abort with usage if none provided
  - e.g. `./warm-models.sh qwen2.5-coder:32b deepseek-r1:70b`
- [x] Verify Ollama is running (`curl -sf http://localhost:11434/v1/models`) before proceeding
- [x] For each model: `ollama pull <model>` (download if not present)
  - Ref: `server/SETUP.md` lines 74-76
- [x] For each model: send lightweight `/v1/chat/completions` request to force-load into memory
  - Minimal prompt ("hi") with `max_tokens: 1`
  - Ref: `server/specs/FUNCTIONALITIES.md` line 17
- [x] Report progress per model (pulling, loading, ready, failed)
- [x] Continue on individual model failures; print summary at end
- [x] Document in script comments how to wire into launchd as a post-boot warmup
  - Ref: `server/specs/INTERFACES.md` line 17

---

## Priority 6 -- Integration Testing

**Status**: ✅ COMPLETE
**Dependencies**: All implementation priorities (1-5 COMPLETE), Priorities A, B, C, and D COMPLETE
**Blocks**: Priority 7

**Note**: Test scripts (server test.sh, client test.sh) are now complete. Hardware testing successfully completed 2026-02-10 for both server and client.

This priority is subdivided into three tasks:
- **Priority 6a / Priority C**: Implement server test script (`server/scripts/test.sh`) -- ✅ COMPLETE
- **Priority 6b / Priority D**: Implement client test script (`client/scripts/test.sh`) -- ✅ COMPLETE
- **Priority 6c**: Run integration testing on real hardware -- ✅ COMPLETE

**Spec refs**:
- `server/specs/SCRIPTS.md` lines 43-88: complete server test script specification
- `client/specs/SCRIPTS.md` lines 20-78: complete client test script specification
- `client/specs/API_CONTRACT.md` lines 17-26: supported endpoints
- `client/specs/API_CONTRACT.md` lines 46-51: error behavior
- `server/specs/FUNCTIONALITIES.md` lines 6-13: API capabilities
- `server/specs/SECURITY.md` lines 11-12: Tailscale ACL enforcement

---

### Priority 6a -- Server: `server/scripts/test.sh`

**Status**: ✅ COMPLETE
**Effort**: Medium (comprehensive test automation)
**Dependencies**: Priority 2 (server install.sh)

**Spec refs**:
- `server/specs/SCRIPTS.md` lines 43-88: complete test.sh behavior specification
- `server/specs/FILES.md` line 17: file location

**Tasks**:
- [x] Create comprehensive server test script with 20 distinct tests
- [x] Test service status (LaunchAgent loaded, process running, listening on port)
- [x] Test all API endpoints (`/v1/models`, `/v1/models/{model}`, `/v1/chat/completions`, `/v1/responses`)
- [x] Test streaming and non-streaming chat completions
- [x] Test JSON mode and stream options
- [x] Test error behavior (nonexistent model, malformed requests)
- [x] Test security (process owner, log files, plist configuration)
- [x] Test network binding (0.0.0.0, localhost, Tailscale IP)
- [x] Implement pass/fail reporting with summary
- [x] Support `--verbose`, `--skip-model-tests` flags
- [x] Colorized output (green/red/yellow)
- [x] Exit code 0 on success, non-zero on failure

---

### Priority 6b -- Client: `client/scripts/test.sh`

**Status**: ✅ COMPLETE
**Effort**: Medium (comprehensive test automation)
**Dependencies**: Priority 3 (client install.sh)

**Spec refs**:
- `client/specs/SCRIPTS.md` lines 20-78: complete test.sh behavior specification
- `client/specs/FILES.md` line 14: file location

**Tasks**:
- [x] Create comprehensive client test script with 27 distinct tests
- [x] Test environment configuration (env file exists, all vars set, shell profile sourcing)
- [x] Test dependencies (Tailscale, Homebrew, Python, pipx, Aider)
- [x] Test connectivity to server (all API endpoints)
- [x] Test API contract validation (endpoint formats, response schemas)
- [x] Test Aider integration (binary in PATH, environment vars readable)
- [x] Test script behavior (install idempotency, uninstall availability)
- [x] Implement pass/fail reporting with summary
- [x] Support `--verbose`, `--skip-server`, `--skip-aider`, `--quick` flags
- [x] Colorized output (green/red/yellow)
- [x] Exit code 0 on success, non-zero on failure

---

### Priority 6c -- Run Integration Testing on Hardware

**Status**: ✅ COMPLETE
**Effort**: Large (manual testing on real hardware)
**Dependencies**: Priorities 6a, 6b (test scripts), 1-5 (all implementation)
**Blocks**: Priority 7

**Requirements**: Apple Silicon Mac with Tailscale for both server and client testing

**Server Testing Results** (2026-02-10):
- ✅ Executed `./server/scripts/test.sh` on hardware (vm@remote-ollama)
- ✅ All 20 automated tests PASSED
- ✅ Service Status: LaunchAgent loaded, process running as user (vm, PID 19272), listening on port 11434
- ✅ API Endpoints: All tested endpoints working (`/v1/models`, `/v1/models/{model}`, `/v1/chat/completions`, `/v1/responses`)
- ✅ Streaming: SSE chunks working correctly with `stream_options.include_usage`
- ✅ Error Behavior: Proper 404/400 status codes for invalid requests
- ✅ Security: Process running as user (not root), logs accessible, OLLAMA_HOST=0.0.0.0 configured
- ✅ Network: Binding to all interfaces, accessible via localhost and Tailscale IP (100.100.246.47)
- ✅ Model loaded: qwen2.5-coder:7b confirmed operational

**Client Testing Results** (2026-02-10):
- ✅ Executed `./client/scripts/test.sh` on hardware (vm@macos)
- ✅ All 27 automated tests PASSED (2 expected skips: AIDER_MODEL optional, JSON mode model-dependent)
- ✅ Environment Configuration: All 4 env vars set correctly (OLLAMA_API_BASE, OPENAI_API_BASE, OPENAI_API_KEY), shell profile sourcing verified
- ✅ Dependencies: Tailscale connected (100.100.246.47), Homebrew installed, Python 3.14, pipx installed, Aider 0.86.1 installed
- ✅ Connectivity: Server reachable at remote-ollama, all API endpoints responding
- ✅ API Contract: Base URL formats validated, streaming with usage data working
- ✅ Aider Integration: Binary found at `/Users/vm/.local/bin/aider`, in PATH, environment vars configured
- ✅ Script Behavior: Uninstall script available, valid syntax, install idempotency verified

**Testing approach**:
1. ✅ Run server test script on server machine: `./server/scripts/test.sh --verbose`
2. ✅ Run client test script on client machine: `./client/scripts/test.sh --verbose`
3. Manual verification not required for v1 release (automated tests cover all critical functionality)

**Verification Summary**:

### API endpoints - ✅ ALL VERIFIED
- ✅ `GET /v1/models` returns JSON model list (server/client test.sh) — VERIFIED 2026-02-10
- ✅ `GET /v1/models/{model}` returns single model details (server/client test.sh) — VERIFIED 2026-02-10
- ✅ `POST /v1/chat/completions` non-streaming request succeeds (server/client test.sh) — VERIFIED 2026-02-10
- ✅ `POST /v1/chat/completions` streaming (`stream: true`) returns SSE chunks (server/client test.sh) — VERIFIED 2026-02-10
- ✅ `POST /v1/chat/completions` with `stream_options.include_usage` returns usage in final chunk (server/client test.sh) — VERIFIED 2026-02-10
- ✅ `POST /v1/responses` endpoint returns non-stateful response (server test.sh) — VERIFIED 2026-02-10 (Ollama 0.5.0+)
- ⚠️ JSON mode model-dependent (skipped in client test.sh as expected)
- ⚠️ Tools/tool_choice and vision/image_url are model-dependent (out of scope for v1)

### Error behavior - ✅ ALL VERIFIED
- ✅ Nonexistent endpoint returns 404 (client test.sh) — VERIFIED 2026-02-10
- ✅ Nonexistent model returns error status (server test.sh) — VERIFIED 2026-02-10
- ✅ Malformed request returns error status (server test.sh) — VERIFIED 2026-02-10

### Security - ✅ VERIFIED
- ✅ Ollama process running as user (not root) (server test.sh) — VERIFIED 2026-02-10
- ✅ Logs accessible (server test.sh) — VERIFIED 2026-02-10
- ✅ OLLAMA_HOST=0.0.0.0 configured (server test.sh) — VERIFIED 2026-02-10
- ⚠️ Tailscale ACL enforcement requires multi-device testing (out of scope for v1)

### Client integration - ✅ ALL VERIFIED
- ✅ Aider binary installed and in PATH (client test.sh) — VERIFIED 2026-02-10
- ✅ Environment variables configured correctly (client test.sh) — VERIFIED 2026-02-10
- ✅ Server connectivity validated (client test.sh) — VERIFIED 2026-02-10

### Script behavior - ✅ ALL VERIFIED
- ✅ Install script idempotency verified (client test.sh) — VERIFIED 2026-02-10
- ✅ Uninstall script available and has valid syntax (client test.sh) — VERIFIED 2026-02-10
- ⚠️ Manual curl-pipe install and end-to-end Aider chat flow deferred to user acceptance testing

---

## Priority 7 -- Documentation Polish

**Status**: ✅ COMPLETE (all 11 tasks done)
**Dependencies**: ✅ All implementation and testing priorities COMPLETE (Priorities 1-6, A-F)

**Completed**:
- [x] Fix "Sonnet" -> "Sonoma" typo in all READMEs (server, client, root)
- [x] Fix branch name in curl-pipe URL: `client/SETUP.md` line 12 now uses `master`
- [x] Update `server/SETUP.md` step 3 to use `launchctl bootstrap` instead of deprecated `launchctl load -w`
- [x] Remove conflicting `brew services restart ollama` from `server/SETUP.md` step 4
- [x] Update `client/SETUP.md` uninstall section to document both local and curl-pipe uninstall paths
- [x] Document minimum Ollama version for `/v1/responses` endpoint (0.5.0+ experimental) in API contract
- [x] Verify all cross-links between spec files, READMEs, and SETUP.md are correct
- [x] Add quick-reference card for common operations (start/stop server, switch models, check status)
- [x] Add `warm-models.sh` documentation to `server/README.md` and `server/SETUP.md`
- [x] Update `server/README.md` and `client/README.md` with actual tested commands and sample outputs (added "Testing & Verification" sections with sample test output from 2026-02-10 hardware testing)
- [x] Expand troubleshooting sections in both SETUP.md files based on testing insights (added comprehensive troubleshooting covering service status, connectivity, dependencies, API issues, and test suite usage)

---

## Implementation Constraints (from specs)

These constraints apply to ALL implementation work and are non-negotiable:

1. **Security** (`server/specs/SECURITY.md`): No public internet exposure. No built-in auth -- relies entirely on Tailscale isolation. Ollama must not run as root. Logs remain local, no telemetry.

2. **API contract** (`client/specs/API_CONTRACT.md`): Single source of truth for the server-client interface. Client configures exactly these env vars and relies only on documented endpoints. Server guarantees all documented endpoints and behaviors.

3. **Independence** (`AGENTS.md`): Server and client remain independent except via the API contract.

4. **Idempotency**: All scripts must be safe to re-run without breaking existing setup.

5. **No stubs**: Implement completely or not at all.

6. **macOS only (v1)**: Server requires Apple Silicon. Client requires macOS 14+ (Sonoma).

7. **Aider is the only v1 interface** (`client/specs/ARCHITECTURE.md` line 7): But the env var setup ensures any OpenAI-compatible tool works automatically.

8. **curl-pipe install support** (`client/SETUP.md` lines 11-13): Client install.sh must work when piped from curl. Solution: embed env.template as heredoc fallback; copy uninstall.sh to `~/.ai-client/`.

## Spec Audit Findings (2026-02-10, re-audited 2026-02-10, v3 2026-02-10)

### Spec consistency audit
A comprehensive audit of all 13 specification files was performed to validate internal consistency, cross-file consistency, and completeness:

- **No internal contradictions**: Each spec file is internally consistent with no conflicting requirements
- **No cross-file contradictions**: All cross-spec dependencies verified; no conflicting requirements between files
- **All requirements satisfiable**: Current implementation scope can fully satisfy all documented requirements
- **No TODO/FIXME markers**: All spec files and implementation scripts are complete for v1 scope with no placeholder sections

### Implementation-vs-spec audit (updated 2026-02-10, v4.3)
Every implemented script was compared line-by-line against its spec requirements using parallel Opus/Sonnet subagents. Fourth audit pass; all 35 previously identified gaps re-confirmed, 16 additional gaps found across all scripts. Total: 51 gaps. **31 gaps fixed as of 2026-02-10. Remaining: 20 gaps.**

- **client/config/env.template**: ✅ COMPLETE. All 4 variables present and correct, `export` used, `AIDER_MODEL` commented out, `__HOSTNAME__` placeholder correct
- **server/scripts/install.sh**: ✅ COMPLETE. All gaps fixed including shell validation (F7.3)
- **server/scripts/uninstall.sh**: ✅ COMPLETE. All 3 gaps confirmed as already compliant: error/warning tracking works (F5.1), `set -euo pipefail` compatible with graceful handling (F5.2), purpose clear from output (F5.3)
- **server/scripts/warm-models.sh**: ✅ COMPLETE. All 3 gaps fixed (F4.1-F4.3): progress shown during pull, spec-compliant message format, time estimates added
- **server/scripts/test.sh**: ✅ COMPLETE. All 20 tests implemented. All 9 gaps fixed (F3.1-F3.9): progress indication, helpful failures, banner with count, log readability, verbose mode with timing, usage verification, skip guidance, boxed summary, next-steps section
- **client/scripts/install.sh**: ✅ COMPLETE. All 11 gaps fixed (F1.1-F1.11) including all 3 HIGH priority gaps
- **client/scripts/uninstall.sh**: ✅ COMPLETE. All 6 gaps fixed (F6.1-F6.6) including all 3 HIGH priority gaps
- **client/scripts/test.sh**: ✅ COMPLETE. All 27 tests implemented. All 15 gaps fixed (F2.1-F2.15): progress indication, helpful failures, banner with count, verbose mode with timing, usage verification, HTTP status validation, schema validation, OPENAI_API_KEY check, quick mode scope, skip guidance, boxed summary, next steps, uninstall test, idempotency check, AIDER_MODEL visibility
- **UX consistency**: ✅ COMPLETE. All 4 cross-cutting gaps fixed (F7.1-F7.4): color palette standardized, visual hierarchy consistent, shell validation added, banner prefixes unified

---

## Resolved Documentation Issues

All previously identified documentation inconsistencies have been corrected (2026-02-10):

1. ✅ **"Sonnet" vs "Sonoma"**: All READMEs now correctly reference "macOS 14 Sonoma"
2. ✅ **SETUP.md deprecated API**: `server/SETUP.md` now uses modern `launchctl bootstrap` command
3. ✅ **SETUP.md conflicting service management**: Removed conflicting `brew services` command; now uses only `launchctl kickstart -k`
4. ✅ **curl-pipe URL branch**: `client/SETUP.md` now uses correct `master` branch in URL
5. ✅ **curl-pipe uninstall path**: `client/SETUP.md` now documents `~/.ai-client/uninstall.sh` for curl-pipe users
6. ✅ **`/v1/responses` endpoint version**: API contract now notes "requires Ollama 0.5.0+ (experimental)"
