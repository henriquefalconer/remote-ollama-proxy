<!--
 Copyright (c) 2026 Henrique Falconer. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

# Implementation Plan

**Last Updated**: 2026-02-11

---

## Current Status

| Component | Compliance | Summary |
|-----------|-----------|---------|
| **Client** | ~99% | All 6 scripts, env.template, SETUP.md implemented. 40 tests passing. One timing bug, stale README, missing spec entry. |
| **Root Analytics** | 100% | loop.sh, loop-with-analytics.sh, compare-analytics.sh, ANALYTICS_README.md all match specs. |
| **Server** | ~60% | Ollama API surface works (OpenAI + Anthropic, 26 tests). HAProxy proxy layer entirely missing. |

**Architecture gap**:
```
Current:   Client → Tailscale → Ollama (0.0.0.0:11434)
Specified: Client → Tailscale → HAProxy (100.x.x.x:11434) → Ollama (127.0.0.1:11434)
```

---

## Remaining Tasks

### P1: Align SCRIPTS.md Spec with Security Architecture

**File**: `server/specs/SCRIPTS.md` | **Effort**: Small | **Dependencies**: None (gates all P2 tasks)

SCRIPTS.md says `OLLAMA_HOST=0.0.0.0` in 3 places. All 5 other spec files say `127.0.0.1`. Align with security architecture:

- Change `OLLAMA_HOST=0.0.0.0` to `OLLAMA_HOST=127.0.0.1` throughout
- Add HAProxy installation section (consent prompt, Homebrew install, config generation, plist creation, service loading)
- Add HAProxy uninstallation section (stop service, remove plist, delete config dir, clean logs)
- Add HAProxy test specifications (service loaded, Tailscale interface listening, allowlist enforcement, direct Ollama access blocked)
- Update Security Tests to verify loopback binding instead of all-interfaces binding
- Update "No config files" section to reflect HAProxy config existence

### P2: Implement HAProxy in Server Scripts

#### P2a: Add HAProxy to install.sh

**File**: `server/scripts/install.sh` | **Effort**: Large | **Dependencies**: P1

1. **User consent prompt** -- "Install HAProxy proxy? (Y/n)" with benefits/tradeoffs. Default: Yes.
2. **HAProxy installation** -- `brew install haproxy` (suppress Homebrew noise)
3. **Config generation** -- `~/.haproxy/haproxy.cfg` with frontend on Tailscale interface (`100.x.x.x:11434` via `tailscale ip -4`), backend to `127.0.0.1:11434`, endpoint allowlist per FILES.md, default deny
4. **Plist creation** -- `~/Library/LaunchAgents/com.haproxy.plist` with RunAtLoad, KeepAlive
5. **Ollama binding change** -- Set `OLLAMA_HOST=127.0.0.1` in Ollama plist (currently `0.0.0.0`)
6. **Service loading** -- Load both LaunchAgents via `launchctl bootstrap`
7. **Verification** -- HAProxy listening on Tailscale interface, Ollama on loopback only, proxy forwarding works
8. **Fallback** -- If user declines, keep `OLLAMA_HOST=0.0.0.0` (functional but less secure)

#### P2b: Add HAProxy Cleanup to uninstall.sh

**File**: `server/scripts/uninstall.sh` | **Effort**: Small | **Dependencies**: P1

- Stop and remove `~/Library/LaunchAgents/com.haproxy.plist` via `launchctl bootout`
- Delete `~/.haproxy/` directory
- Clean up `/tmp/haproxy.log`
- Handle gracefully if HAProxy was never installed

#### P2c: Add HAProxy Tests to test.sh

**File**: `server/scripts/test.sh` | **Effort**: Medium | **Dependencies**: P2a

Modify existing tests:
- Test 17: Check `OLLAMA_HOST=127.0.0.1` (currently checks `0.0.0.0`)
- Test 18: Verify loopback-only binding via `lsof`

Add new tests (skip gracefully if HAProxy not installed):
- HAProxy LaunchAgent loaded (`launchctl list | grep com.haproxy`)
- HAProxy listening on Tailscale interface
- Endpoint allowlist enforcement (blocked paths return 403)
- Direct Ollama access from Tailscale IP blocked

Expected total: ~33-34 tests (up from 26).

### P3: Bug Fixes and Documentation

#### P3a: Fix client/scripts/test.sh Timing Bug

**File**: `client/scripts/test.sh` line 763 | **Effort**: Trivial | **Dependencies**: None

Change `[[ "$START_TIME" =~ N ]]` to `[[ ${#START_TIME} -gt 12 ]]`. All other 8 instances in the file already use the correct pattern.

#### P3b: Update client/README.md

**File**: `client/README.md` | **Effort**: Small | **Dependencies**: None

Remove "planned", "not yet implemented", and construction emoji references for v2+ features (Claude Code, Anthropic API, version management, analytics). All v2+ features are fully implemented and tested.

#### P3c: Add Root-Level Scripts to client/specs/SCRIPTS.md

**File**: `client/specs/SCRIPTS.md` | **Effort**: Small | **Dependencies**: None

Add specifications for `loop.sh`, `loop-with-analytics.sh`, and `compare-analytics.sh`. These are implemented and documented in ANALYTICS_README.md per ANALYTICS.md spec, but not referenced in SCRIPTS.md.

#### P3d: Verify Server Documentation Post-HAProxy

**Files**: `server/README.md`, `server/SETUP.md` | **Effort**: Small | **Dependencies**: P2a

Both files already describe HAProxy architecture. After implementation, verify accuracy and update test counts.

### P4: Hardware Validation

**Effort**: Medium | **Dependencies**: P2a, P2c

Run full test suites on Apple Silicon server hardware:
- Server tests (`server/scripts/test.sh --verbose`) including new HAProxy tests
- Client tests (`client/scripts/test.sh --verbose`)
- Manual Claude Code + Ollama integration validation
- Version management and analytics script validation

---

## Dependency Graph

```
P1 (SCRIPTS.md spec alignment)
 ├── P2a (install.sh HAProxy) ─── requires P1
 │    ├── P2c (test.sh HAProxy tests) ─── requires P2a
 │    └── P3d (server docs verification) ─── requires P2a
 └── P2b (uninstall.sh cleanup) ─── requires P1

P3a (client test.sh timing bug) ─── independent
P3b (client README update) ─── independent
P3c (client SCRIPTS.md spec) ─── independent

P4 (hardware validation) ─── requires P2a, P2c
```

**Suggested order**: P1 -> P2a -> P2b + P2c (parallel) -> P3d -> P4. P3a, P3b, P3c can run anytime.

---

## Implementation Constraints

1. **Security**: Tailscale-only network. No public exposure. No built-in authentication.
2. **API contract**: `client/specs/API_CONTRACT.md` is the single source of truth for the server-client interface.
3. **Idempotency**: All scripts must be safe to re-run without side effects.
4. **No stubs**: Implement completely or not at all.
5. **HAProxy is optional**: User consent prompt required. Default: Yes. Without it, Ollama falls back to `0.0.0.0` binding.
6. **Claude Code integration is optional**: Always prompt for user consent on the client side.
7. **curl-pipe install**: Client `install.sh` must work via `curl | bash`.
8. **Specs are authoritative**: `server/specs/*.md` (9 files), `client/specs/*.md` (9 files). Deviations must be corrected unless there is a compelling reason to update the spec.
