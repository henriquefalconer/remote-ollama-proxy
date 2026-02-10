<!--
 Copyright (c) 2026 Henrique Falconer. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

# Implementation Plan

Prioritized task list for achieving full spec implementation of both server and client components.

## Current Status

- **Specifications**: COMPLETE (5 server + 6 client = 11 spec files)
- **Documentation**: COMPLETE (README.md + SETUP.md for both server and client, plus root README)
- **Server implementation**: COMPLETE (install.sh COMPLETE, warm-models.sh COMPLETE)
- **Client implementation**: COMPLETE (env.template COMPLETE, scripts COMPLETE)
- **Integration testing**: READY (all implementation complete)

## Spec Audit Summary

Every spec file was read and cross-referenced. Findings are grouped below.

### Files required by specs (from FILES.md)

| Component | File | Spec Source | Status |
|-----------|------|-------------|--------|
| Client | `client/config/env.template` | `client/specs/FILES.md` line 16 | COMPLETE |
| Server | `server/scripts/install.sh` | `server/specs/FILES.md` line 12 | COMPLETE |
| Client | `client/scripts/install.sh` | `client/specs/FILES.md` line 12 | COMPLETE |
| Client | `client/scripts/uninstall.sh` | `client/specs/FILES.md` line 13 | COMPLETE |
| Server | `server/scripts/warm-models.sh` | `server/specs/FILES.md` line 13 | COMPLETE |

### Cross-spec findings

1. **server/SETUP.md uses deprecated launchctl API**: Line 61 uses `launchctl load -w`; step 4 (lines 64-69) mixes `brew services restart ollama` with the manual plist from step 3. These conflict. The install script must use `launchctl bootstrap` / `launchctl bootout` exclusively and disable brew services for Ollama.

2. **curl-pipe URL corrected**: `client/SETUP.md` line 12 now correctly references branch `master` (repository's default branch).

3. **curl-pipe install requires self-contained script**: `client/SETUP.md` line 12 references `curl -fsSL ...install.sh | bash`. When piped, `$0` is `bash` and there is no filesystem context. The script cannot assume `../config/env.template` exists. **Prescribed solution**: embed the env.template content as a heredoc fallback inside install.sh. If the file exists on disk (local clone mode), read it; otherwise use the embedded copy. This makes the script self-contained for curl-pipe while still using the canonical template file when available.

4. **API contract defines 4 environment variables** (`client/specs/API_CONTRACT.md` lines 39-43): `OLLAMA_API_BASE`, `OPENAI_API_BASE`, `OPENAI_API_KEY`, and optionally `AIDER_MODEL`. The env.template and install script must set all four (with AIDER_MODEL commented out as optional). Variables must use `export` so they propagate to child processes like Aider.

5. **Server security constraints** (`server/specs/SECURITY.md` lines 20-24): Ollama logs must remain local, no outbound telemetry, avoid running as root, regular updates for macOS/Tailscale/Ollama only. The launchd plist is a user-level LaunchAgent (in `~/Library/LaunchAgents/`), which inherently runs as the user -- not root. The install script must validate this.

6. **Server CORS** (`server/specs/SECURITY.md` lines 26-29): Default Ollama CORS restrictions apply. The install script should NOT set `OLLAMA_ORIGINS` in v1 but should include a comment in the plist section documenting it as an optional future enhancement.

7. **Tailscale ACL snippet** (`server/SETUP.md` lines 86-96, `server/specs/SECURITY.md` lines 11-12): The server install script should print the full ACL JSON snippet for the user to apply in the Tailscale admin console, including tag-based rules (`tag:ai-client` -> `tag:private-ai-server:11434`) and machine name guidance.

8. **Client connectivity test** (`client/specs/FUNCTIONALITIES.md` lines 17-19): The install script must test connectivity and provide clear error messages if Tailscale is not connected or the server is unreachable. Per `FUNCTIONALITIES.md` line 18 this test is described as "optional" -- the script must **warn but not abort** if the server is unreachable.

9. **server/SETUP.md hardcodes Ollama path**: Line 41 uses `/opt/homebrew/bin/ollama`. This is correct for Apple Silicon Homebrew but the install script should validate the path exists before writing it into the plist (use `which ollama` or `brew --prefix`/`bin/ollama` as fallback).

10. **client/SETUP.md "with user consent"**: Line 32 says the installer will "Update your shell profile (~/.zshrc) to source the environment". `client/specs/SCRIPTS.md` line 9 specifies "(with user consent)". The install script must interactively prompt before modifying `~/.zshrc`.

11. **pipx ensurepath timing**: After `brew install pipx`, `pipx ensurepath` must be called to add `~/.local/bin` to PATH. This must happen before `pipx install aider-chat` so the aider binary is findable. Additionally, the shell profile sourcing line must come before the pipx PATH additions, or the user must open a new terminal.

12. **curl-pipe uninstall documented**: `client/SETUP.md` lines 68-72 now documents both uninstall paths (local clone: `./scripts/uninstall.sh`, curl-pipe: `~/.private-ai-client/uninstall.sh`). Install.sh must copy uninstall.sh to `~/.private-ai-client/uninstall.sh` during installation.

13. **`/v1/responses` endpoint version requirement documented**: `client/specs/API_CONTRACT.md` line 26 now notes "requires Ollama 0.5.0+ (experimental)". The integration testing phase must verify this endpoint works with documented version.

14. **All 4 API contract endpoints are covered by Ollama**: `/v1/chat/completions` (core), `/v1/models` (listing), `/v1/models/{model}` (detail), and `/v1/responses` (experimental). No custom server code is needed -- Ollama serves all of these natively. The install script just needs to ensure Ollama is running and bound to all interfaces.

15. **Marker comment pattern for shell profile**: The install script must use a consistent marker pattern (`# >>> private-ai-client >>>` / `# <<< private-ai-client <<<`) to delimit the sourcing block in `~/.zshrc` and `~/.bashrc`. This enables idempotent insertion (skip if markers already present) and clean removal by uninstall.sh (delete everything between markers inclusive).

16. **"Sonnet" vs "Sonoma" typo corrected**: All READMEs (`server/README.md` line 19, `client/README.md` line 24, root `README.md` lines 51/56) now correctly say "macOS 14 Sonoma".

### Priority ordering rationale

1. **env.template first** -- trivial, zero dependencies, unblocks client install script
2. **Server install.sh** -- largest and most complex script; independent of client; unblocks warm-models.sh
3. **Client install.sh** -- depends on env.template; can be tested independently of server (connectivity test warns but does not abort)
4. **Client uninstall.sh** -- must exactly reverse what install.sh creates
5. **Server warm-models.sh** -- optional enhancement; depends on server being installed
6. **Integration testing** -- requires 1-5 to be complete
7. **Documentation polish** -- requires 1-6 to validate accuracy

This ordering is optimal because: (a) the trivial file is first to unblock downstream work; (b) server and client install scripts are independent and could theoretically be parallelized, but server is listed first because it has zero dependencies while client depends on Priority 1; (c) uninstall.sh must be written after install.sh to ensure exact reversal; (d) warm-models.sh is optional and can be deferred.

---

## Priority 1 -- Client: `client/config/env.template`

**Status**: COMPLETE
**Effort**: Trivial (~8 lines)
**Dependencies**: None
**Blocks**: Priority 3 (client install.sh reads this template)

**Spec refs**:
- `client/specs/SCRIPTS.md` lines 20-23: "Template showing the exact variables required by the contract; Used by install.sh to create `~/.private-ai-client/env`"
- `client/specs/API_CONTRACT.md` lines 39-43: exact variable names and values
- `client/specs/FILES.md` line 16: file location `client/config/env.template`

**Tasks**:
- [x] Create `client/config/` directory
- [x] Create `env.template` with the following content:
  ```bash
  # private-ai-client environment configuration
  # Source: client/specs/API_CONTRACT.md
  # Generated from env.template by install.sh -- do not edit manually
  export OLLAMA_API_BASE=http://__HOSTNAME__:11434/v1
  export OPENAI_API_BASE=http://__HOSTNAME__:11434/v1
  export OPENAI_API_KEY=ollama
  # export AIDER_MODEL=ollama/<model-name>
  ```
- [x] Use `__HOSTNAME__` as the placeholder (install.sh substitutes with actual hostname, default `private-ai-server`)
- [x] Include `export` on each variable so they propagate to child processes when sourced
- [x] Keep `AIDER_MODEL` commented out (optional per API contract)

---

## Priority 2 -- Server: `server/scripts/install.sh`

**Status**: COMPLETE
**Effort**: Large (complex multi-step installer)
**Dependencies**: None (server is independent of client)
**Blocks**: Priority 5 (warm-models.sh), Priority 6 (integration testing)

**Spec refs**:
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
- [x] Prompt user to set Tailscale machine name to `private-ai-server` (or custom name)
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
- `client/specs/FUNCTIONALITIES.md` lines 5-8: one-time installer, env vars, Aider, uninstaller
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
- [x] Prompt for server hostname (default: `private-ai-server`)
  - Ref: `client/specs/SCRIPTS.md` line 7
- [x] Create `~/.private-ai-client/` directory
  - Ref: `client/specs/SCRIPTS.md` line 8
- [x] Resolve env.template (dual-mode strategy):
  - **Local clone mode**: read `$(dirname "$0")/../config/env.template`
  - **curl-pipe mode**: use embedded heredoc fallback (template content hardcoded in script)
  - Detection: if `$0` is `bash` or `/dev/stdin` or the template file does not exist, use embedded mode
  - Ref: `client/SETUP.md` lines 11-13
- [x] Generate `~/.private-ai-client/env` by substituting `__HOSTNAME__` with chosen hostname
  - Ref: `client/specs/SCRIPTS.md` line 8
- [x] Prompt user for consent before modifying shell profile
  - Ref: `client/specs/SCRIPTS.md` line 9 ("with user consent")
  - Ref: `client/SETUP.md` line 32 ("Update your shell profile")
- [x] Append `source ~/.private-ai-client/env` to `~/.zshrc` (or `~/.bashrc` for bash users)
  - Guard with marker comment (`# >>> private-ai-client >>>` / `# <<< private-ai-client <<<`) for idempotency and clean removal
  - Only append if marker not already present
  - Handle both `~/.zshrc` and `~/.bashrc`
- [x] Install pipx if not present: `brew install pipx`
- [x] Run `pipx ensurepath` immediately after pipx installation (adds `~/.local/bin` to PATH)
  - This must happen before `pipx install` so the binary is locatable
  - Ref: `client/SETUP.md` lines 91-93 (troubleshooting)
- [x] Install Aider via `pipx install aider-chat`
  - Ref: `client/specs/SCRIPTS.md` line 10
  - Ref: `client/specs/ARCHITECTURE.md` line 7
- [x] Copy `uninstall.sh` to `~/.private-ai-client/uninstall.sh` for curl-pipe users
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
  - Use the same `# >>> private-ai-client >>>` / `# <<< private-ai-client <<<` markers from install.sh
  - Clean both `~/.zshrc` and `~/.bashrc`
- [x] Delete `~/.private-ai-client/` directory (includes env file and copied uninstall.sh)
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

**Status**: AWAITING HARDWARE
**Dependencies**: All implementation priorities (1-5 COMPLETE)
**Blocks**: Priority 7

**Note**: Integration testing cannot be performed in the Linux sandbox environment. This requires actual macOS hardware with Apple Silicon and Tailscale to verify the server-client integration. All implementation code is complete and ready for testing on real hardware.

**Spec refs**:
- `client/specs/API_CONTRACT.md` lines 17-26: supported endpoints
- `client/specs/API_CONTRACT.md` lines 46-51: error behavior
- `server/specs/FUNCTIONALITIES.md` lines 6-13: API capabilities
- `server/specs/SECURITY.md` lines 11-12: Tailscale ACL enforcement

**Manual testing checklist** (run from an authorized client machine):

### API endpoints
- [ ] `GET /v1/models` returns JSON model list
  - Ref: `client/specs/API_CONTRACT.md` line 24
- [ ] `GET /v1/models/{model}` returns single model details
  - Ref: `client/specs/API_CONTRACT.md` line 25
- [ ] `POST /v1/chat/completions` non-streaming request succeeds
  - Ref: `client/specs/API_CONTRACT.md` line 23
- [ ] `POST /v1/chat/completions` streaming (`stream: true`) returns SSE chunks
  - Ref: `client/specs/API_CONTRACT.md` line 23
- [ ] `POST /v1/chat/completions` with `stream_options.include_usage` returns usage in final chunk
  - Ref: `client/specs/API_CONTRACT.md` line 33
- [ ] `POST /v1/chat/completions` JSON mode (`response_format: { "type": "json_object" }`) returns valid JSON
  - Ref: `client/specs/API_CONTRACT.md` line 23
- [ ] `POST /v1/chat/completions` with tools/tool_choice (if model supports)
  - Ref: `client/specs/API_CONTRACT.md` line 23
- [ ] `POST /v1/chat/completions` with vision/image_url (if model supports)
  - Ref: `client/specs/API_CONTRACT.md` line 23
- [ ] `POST /v1/responses` endpoint returns non-stateful response
  - Ref: `client/specs/API_CONTRACT.md` line 26
  - **Note**: Experimental in Ollama -- document minimum version if it fails

### Error behavior
- [ ] Connection refused / 404 when Tailscale not connected
  - Ref: `client/specs/API_CONTRACT.md` line 48
- [ ] 429 under concurrent load (if reproducible)
  - Ref: `client/specs/API_CONTRACT.md` line 49
- [ ] 500 on inference error (e.g., nonexistent model)
  - Ref: `client/specs/API_CONTRACT.md` line 50

### Security
- [ ] Unauthorized Tailscale device is rejected
  - Ref: `server/specs/SECURITY.md` lines 11-12
- [ ] Ollama process is running as user (not root)
  - Ref: `server/specs/SECURITY.md` line 24

### End-to-end client flow
- [ ] Aider connects and completes a chat exchange with the server
  - Ref: `client/specs/FUNCTIONALITIES.md` lines 12-13
- [ ] Any OpenAI-compatible tool using `OPENAI_API_BASE` + `OPENAI_API_KEY` works
  - Ref: `client/specs/FUNCTIONALITIES.md` line 13

### Script behavior
- [ ] Client install.sh works via curl-pipe method
  - Ref: `client/SETUP.md` lines 11-13
- [ ] Client install.sh works from local clone
  - Ref: `client/SETUP.md` lines 20-23
- [ ] Client uninstall.sh cleanly removes all client-side changes
  - Ref: `client/specs/SCRIPTS.md` lines 14-18
- [ ] Re-running client install.sh (idempotency) does not break existing setup
- [ ] Re-running server install.sh (idempotency) does not break existing setup
- [ ] Re-running uninstall.sh on already-clean system does not error
- [ ] Warm-models.sh pulls and loads models correctly
  - Ref: `server/specs/FUNCTIONALITIES.md` line 17
- [ ] Warm-models.sh continues on individual model failure
- [ ] `OPENAI_API_BASE` works with generic OpenAI-compatible tool (not just Aider)

---

## Priority 7 -- Documentation Polish

**Status**: PARTIALLY COMPLETE (6 of 10 tasks done)
**Dependencies**: All implementation and testing priorities

**Completed**:
- [x] Fix "Sonnet" -> "Sonoma" typo in all READMEs (server, client, root)
- [x] Fix branch name in curl-pipe URL: `client/SETUP.md` line 12 now uses `master`
- [x] Update `server/SETUP.md` step 3 to use `launchctl bootstrap` instead of deprecated `launchctl load -w`
- [x] Remove conflicting `brew services restart ollama` from `server/SETUP.md` step 4
- [x] Update `client/SETUP.md` uninstall section to document both local and curl-pipe uninstall paths
- [x] Document minimum Ollama version for `/v1/responses` endpoint (0.5.0+ experimental) in API contract

**Remaining Tasks** (blocked until testing complete):
- [ ] Update `server/README.md` and `client/README.md` with actual tested commands and sample outputs
- [ ] Expand troubleshooting sections in both SETUP.md files based on issues found during testing
- [ ] Add quick-reference card for common operations (start/stop server, switch models, check status)
- [ ] Verify all cross-links between spec files, READMEs, and SETUP.md are correct

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

8. **curl-pipe install support** (`client/SETUP.md` lines 11-13): Client install.sh must work when piped from curl. Solution: embed env.template as heredoc fallback; copy uninstall.sh to `~/.private-ai-client/`.

## Resolved Documentation Issues

All previously identified documentation inconsistencies have been corrected (2026-02-10):

1. ✅ **"Sonnet" vs "Sonoma"**: All READMEs now correctly reference "macOS 14 Sonoma"
2. ✅ **SETUP.md deprecated API**: `server/SETUP.md` now uses modern `launchctl bootstrap` command
3. ✅ **SETUP.md conflicting service management**: Removed conflicting `brew services` command; now uses only `launchctl kickstart -k`
4. ✅ **curl-pipe URL branch**: `client/SETUP.md` now uses correct `master` branch in URL
5. ✅ **curl-pipe uninstall path**: `client/SETUP.md` now documents `~/.private-ai-client/uninstall.sh` for curl-pipe users
6. ✅ **`/v1/responses` endpoint version**: API contract now notes "requires Ollama 0.5.0+ (experimental)"
