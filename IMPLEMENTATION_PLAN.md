<!--
 Copyright (c) 2026 Henrique Falconer. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

# Implementation Plan

Prioritized task list for achieving full spec implementation of both server and client components.

## Current Status

- **Specifications**: COMPLETE (all spec files exist for both server and client)
- **Documentation**: COMPLETE (README.md and SETUP.md exist for both server and client)
- **Server implementation**: NOT STARTED (`server/scripts/` directory does not exist)
- **Client implementation**: NOT STARTED (`client/scripts/` and `client/config/` directories do not exist)
- **Integration testing**: BLOCKED (requires both server and client implementation)

## Spec Audit Summary

The following analysis was performed by reading every spec file and cross-referencing requirements.

### Files required by specs (from FILES.md)

| Component | File | Spec Source | Status |
|-----------|------|-------------|--------|
| Server | `server/scripts/install.sh` | `server/specs/FILES.md` line 12 | NOT STARTED |
| Server | `server/scripts/warm-models.sh` | `server/specs/FILES.md` line 13 | NOT STARTED |
| Client | `client/scripts/install.sh` | `client/specs/FILES.md` line 12 | NOT STARTED |
| Client | `client/scripts/uninstall.sh` | `client/specs/FILES.md` line 13 | NOT STARTED |
| Client | `client/config/env.template` | `client/specs/FILES.md` line 15 | NOT STARTED |

### Cross-spec findings

1. **SETUP.md conflicts with best practices**: `server/SETUP.md` line 61 uses deprecated `launchctl load -w`; step 4 (line 64-69) mixes `brew services restart ollama` with the manual plist from step 3 -- these conflict. The install script must choose one approach (manual plist) and be consistent.

2. **`client/SETUP.md` references curl-based remote install** (line 11-13): `curl -fsSL https://raw.githubusercontent.com/.../install.sh | bash`. The client install script must work both when piped from curl AND when run from a local clone. This means it must resolve its own location for `config/env.template` dynamically (cannot assume `../config/env.template` always exists when piped).

3. **API contract defines 4 environment variables** (`client/specs/API_CONTRACT.md` lines 39-43): `OLLAMA_API_BASE`, `OPENAI_API_BASE`, `OPENAI_API_KEY`, and optionally `AIDER_MODEL`. The env.template and install script must set all four (with AIDER_MODEL commented out as optional).

4. **Server security constraints** (`server/specs/SECURITY.md` lines 20-24): Ollama logs must remain local, no outbound telemetry, avoid running as root, regular updates for macOS/Tailscale/Ollama only. The install script must ensure the launchd plist runs under the user account (not root).

5. **Server CORS** (`server/specs/SECURITY.md` lines 26-29): Default Ollama CORS restrictions apply. Optionally set `OLLAMA_ORIGINS` if browser-based clients are planned. The install script should document this but not enable it in v1.

6. **Tailscale ACL snippet** (`server/SETUP.md` lines 86-95, `server/specs/SECURITY.md` lines 11-12): The install script should print the ACL JSON snippet for the user to apply manually in the Tailscale admin console, including both tag-based (`tag:ai-client` -> `tag:private-ai-server:11434`) and the server machine name guidance.

7. **Client connectivity test** (`client/specs/FUNCTIONALITIES.md` lines 17-19): Install script must verify connectivity and provide clear error messages if Tailscale is not joined or tag is missing. This requires the hostname to be known first.

8. **No missing spec files identified**: All topics in the architecture (launchd config, env file format, ACL configuration) are covered across existing specs and SETUP.md documents. The launchd plist details are fully specified in `server/SETUP.md` lines 32-59. The env file format is specified in `client/specs/API_CONTRACT.md` lines 39-43 and `client/specs/SCRIPTS.md` lines 20-23.

### Priority ordering rationale

The original plan placed `client/config/env.template` as Priority 2. This is a trivial file (5 lines) with zero dependencies and could be created at any time. However, it IS a dependency for `client/scripts/install.sh` (which reads it as a template). The revised ordering:

1. **env.template first** -- trivial, zero dependencies, unblocks client install script
2. **Server install.sh** -- largest and most complex script; independent of client
3. **Client install.sh** -- depends on env.template; can be tested independently of server (connectivity test will fail gracefully if server not set up yet)
4. **Client uninstall.sh** -- depends on understanding what install.sh creates
5. **Server warm-models.sh** -- optional enhancement; depends on server being installed
6. **Integration testing** -- requires 1-5
7. **Documentation polish** -- requires 1-6

---

## Priority 1 — Client: `client/config/env.template`

**Status**: NOT STARTED
**Estimated effort**: Trivial (single file, ~8 lines)
**Dependencies**: None
**Blocks**: Priority 3 (client install.sh reads this template)

**Spec refs**:
- `client/specs/SCRIPTS.md` lines 20-23: "Template showing the exact variables required by the contract; Used by install.sh to create `~/.private-ai-client/env`"
- `client/specs/API_CONTRACT.md` lines 39-43: exact variable names and values
- `client/specs/FILES.md` line 15: file location `client/config/env.template`

**Tasks**:
- [ ] Create `client/config/` directory
- [ ] Create `env.template` with the exact variables from `API_CONTRACT.md`:
  ```bash
  # private-ai-client environment configuration
  # Generated from env.template by install.sh
  # See: client/specs/API_CONTRACT.md for the full contract
  export OLLAMA_API_BASE=http://__HOSTNAME__:11434/v1
  export OPENAI_API_BASE=http://__HOSTNAME__:11434/v1
  export OPENAI_API_KEY=ollama
  # export AIDER_MODEL=ollama/<model-name>
  ```
- [ ] Use `__HOSTNAME__` placeholder for `install.sh` to substitute (default: `private-ai-server`)
- [ ] Include comment header explaining the file's purpose and link to API_CONTRACT.md

---

## Priority 2 — Server: `server/scripts/install.sh`

**Status**: NOT STARTED
**Estimated effort**: Large (complex multi-step installer with launchd, Tailscale, Ollama)
**Dependencies**: None (server is independent of client)
**Blocks**: Priority 5 (warm-models.sh requires Ollama installed), Priority 6 (integration testing)

**Spec refs**:
- `server/specs/ARCHITECTURE.md` lines 5-11: core principles (zero public internet, zero cloud deps, launchd, authorized devices only)
- `server/specs/ARCHITECTURE.md` lines 15-18: hardware requirements (Apple Silicon, high memory)
- `server/specs/ARCHITECTURE.md` lines 22-25: server responsibilities (bind to all interfaces, model management)
- `server/specs/ARCHITECTURE.md` lines 29-31: Tailscale for all remote access, no port forwarding
- `server/specs/SECURITY.md` lines 3-7: no public ports, no inbound outside overlay, no built-in auth
- `server/specs/SECURITY.md` lines 11-12: Tailscale ACL enforcement on TCP port 11434
- `server/specs/SECURITY.md` lines 20-24: logs local, no telemetry, no root, security updates only
- `server/specs/INTERFACES.md` lines 11-12: OLLAMA_HOST env var + launchd plist
- `server/specs/FILES.md` line 12: file location `server/scripts/install.sh`
- `server/SETUP.md` lines 1-113: step-by-step manual setup (script must automate this)

**Tasks**:
- [ ] Create `server/scripts/` directory
- [ ] Add `#!/bin/bash` + `set -euo pipefail` header
- [ ] Detect macOS + Apple Silicon (`uname -m` = `arm64`); abort with clear message otherwise
  - Ref: `server/specs/ARCHITECTURE.md` line 15 ("Apple Silicon Mac (M-series)")
- [ ] Check/install Homebrew (prompt user if missing)
  - Ref: `server/SETUP.md` line 8 ("Homebrew package manager")
- [ ] Check/install Tailscale via `brew install tailscale`
  - Ref: `server/SETUP.md` lines 15-17
- [ ] Open Tailscale GUI for login + device approval; wait for connection; display Tailscale IP
  - Ref: `server/SETUP.md` line 17 (`open -a Tailscale`)
- [ ] Check/install Ollama via `brew install ollama`
  - Ref: `server/SETUP.md` lines 22-23
- [ ] Stop any existing Ollama service to avoid conflicts with the custom plist
  - Must handle both `brew services stop ollama` and `launchctl bootout` cases
  - Ref: `server/SETUP.md` line 64 (the conflicting step 4 we must resolve)
- [ ] Create `~/Library/LaunchAgents/com.ollama.plist` with:
  - `ProgramArguments`: `/opt/homebrew/bin/ollama serve`
  - `EnvironmentVariables`: `OLLAMA_HOST=0.0.0.0` (bind all interfaces per `ARCHITECTURE.md` line 23)
  - `KeepAlive=true`, `RunAtLoad=true`
  - `StandardOutPath=/tmp/ollama.stdout.log`, `StandardErrorPath=/tmp/ollama.stderr.log`
  - Ref: `server/SETUP.md` lines 32-59 (exact plist XML)
  - Ref: `server/specs/INTERFACES.md` line 12 ("launchd plist for service persistence")
- [ ] Load plist via `launchctl bootstrap gui/$(id -u)` (modern macOS API)
  - Do NOT use deprecated `launchctl load` (per `server/SETUP.md` line 61 which incorrectly uses it)
  - Handle already-loaded case with `launchctl bootout` first for idempotency
- [ ] Verify Ollama is listening on port 11434 with retry loop (timeout after ~30s)
- [ ] Prompt user to set Tailscale machine name to `private-ai-server` (or custom name)
  - Ref: `server/SETUP.md` line 82
- [ ] Print Tailscale ACL JSON snippet for user to apply in admin console
  - Ref: `server/SETUP.md` lines 86-96, `server/specs/SECURITY.md` lines 11-12
- [ ] Run self-test: `curl -sf http://localhost:11434/v1/models` should return JSON
  - Ref: `server/SETUP.md` lines 98-109 (verify server reachability)
- [ ] Make script idempotent (safe to re-run without breaking existing setup)
- [ ] Comprehensive error handling with clear messages at every step
- [ ] Ensure Ollama does NOT run as root
  - Ref: `server/specs/SECURITY.md` line 24 ("Avoid running the server process as root")
- [ ] Do NOT set `OLLAMA_ORIGINS` in v1 (document as optional future enhancement)
  - Ref: `server/specs/SECURITY.md` lines 28-29

**SETUP.md inconsistencies the script must resolve** (do NOT modify SETUP.md):
- `server/SETUP.md` line 61: uses deprecated `launchctl load -w` -- script must use `launchctl bootstrap` instead
- `server/SETUP.md` lines 64-69: mixes `brew services restart ollama` with manual plist -- script must own the plist exclusively and disable brew services for Ollama
- `server/SETUP.md` line 41: hardcodes `/opt/homebrew/bin/ollama` -- script should verify this path exists (it is correct for Apple Silicon Homebrew but should be validated)

---

## Priority 3 — Client: `client/scripts/install.sh`

**Status**: NOT STARTED
**Estimated effort**: Large (multi-step installer with prerequisite checks, env setup, Aider install)
**Dependencies**: Priority 1 (reads `client/config/env.template`)
**Blocks**: Priority 4 (uninstall.sh must undo what install.sh creates), Priority 6 (integration testing)

**Spec refs**:
- `client/specs/SCRIPTS.md` lines 3-11: full install.sh behavior specification
- `client/specs/REQUIREMENTS.md` lines 3-6: macOS 14+, zsh/bash
- `client/specs/REQUIREMENTS.md` lines 8-12: prerequisites (Homebrew, Python 3.10+, Tailscale GUI)
- `client/specs/FUNCTIONALITIES.md` lines 5-8: one-time installer, env vars, Aider, uninstaller
- `client/specs/FUNCTIONALITIES.md` lines 17-19: verify connectivity, clear error messages
- `client/specs/ARCHITECTURE.md` lines 5-9: responsibilities (Tailscale, env vars, Aider, uninstall, document contract)
- `client/specs/ARCHITECTURE.md` lines 18-20: no daemon, no wrapper, only env config + Aider
- `client/specs/API_CONTRACT.md` lines 39-43: exact env var names and values
- `client/specs/FILES.md` line 12: file location `client/scripts/install.sh`
- `client/SETUP.md` lines 9-13: curl-based remote install option (script must support this)

**Tasks**:
- [ ] Create `client/scripts/` directory
- [ ] Add `#!/bin/bash` + `set -euo pipefail` header
- [ ] Detect macOS 14+ (Sonoma); abort with clear message otherwise
  - Ref: `client/specs/REQUIREMENTS.md` line 3 ("macOS 14 Sonoma or later")
- [ ] Detect shell (zsh or bash); note for profile sourcing later
  - Ref: `client/specs/REQUIREMENTS.md` line 4 ("zsh (default) or bash")
- [ ] Check/install Homebrew (prompt user if missing)
  - Ref: `client/specs/REQUIREMENTS.md` line 10 ("Homebrew")
- [ ] Check/install Python 3.10+ via Homebrew if missing
  - Ref: `client/specs/REQUIREMENTS.md` line 11 ("Python 3.10+ (installed via Homebrew if missing)")
- [ ] Check/install Tailscale GUI app; open for login + device approval
  - Ref: `client/specs/REQUIREMENTS.md` line 12 ("Tailscale (GUI app; installer opens it for login)")
  - Ref: `client/specs/SCRIPTS.md` line 6 ("Opens Tailscale app for login + device approval")
- [ ] Prompt for server hostname (default: `private-ai-server`)
  - Ref: `client/specs/SCRIPTS.md` line 7
- [ ] Create `~/.private-ai-client/` directory
  - Ref: `client/specs/SCRIPTS.md` line 8
- [ ] Resolve location of `config/env.template` (must work both from local clone AND when piped via curl)
  - Ref: `client/SETUP.md` lines 11-13 (curl install option)
  - If running from clone: use relative path `$(dirname "$0")/../config/env.template`
  - If piped from curl: embed the template inline or download it separately
- [ ] Copy env.template to `~/.private-ai-client/env`, replacing `__HOSTNAME__` with chosen hostname
  - Ref: `client/specs/SCRIPTS.md` line 8 ("Creates `~/.private-ai-client/env` with exact variables from API_CONTRACT.md")
- [ ] Append `source ~/.private-ai-client/env` to `~/.zshrc` (with user consent)
  - Ref: `client/specs/SCRIPTS.md` line 9
  - Guard with marker comment (e.g. `# private-ai-client`) to avoid duplicates on re-run
- [ ] Also handle `~/.bashrc` if user's shell is bash
- [ ] Install pipx if not present (`brew install pipx && pipx ensurepath`)
- [ ] Install Aider via `pipx install aider-chat` (isolated environment, no global pollution)
  - Ref: `client/specs/SCRIPTS.md` line 10 ("Installs Aider via pipx (isolated, no global pollution)")
  - Ref: `client/specs/ARCHITECTURE.md` line 7 ("Install Aider (the only supported interface in v1)")
- [ ] Run connectivity test: `curl -sf http://<hostname>:11434/v1/models`
  - Ref: `client/specs/SCRIPTS.md` line 11 ("Runs a connectivity test using the contract")
  - Ref: `client/specs/FUNCTIONALITIES.md` lines 17-19 (verify connectivity, clear error messages)
  - Must handle graceful failure (server not yet set up) with clear message, NOT script abort
- [ ] Print success summary with next steps
  - Ref: `client/specs/FUNCTIONALITIES.md` lines 12-13 ("User can run `aider` or `aider --yes`")
- [ ] Make script idempotent (safe to re-run)
- [ ] Comprehensive error handling with clear messages
- [ ] No sudo required for main flow
  - Ref: `client/specs/REQUIREMENTS.md` lines 14-16 ("No sudo required; Except for Homebrew/Tailscale installation if chosen by user")

---

## Priority 4 — Client: `client/scripts/uninstall.sh`

**Status**: NOT STARTED
**Estimated effort**: Small-medium (reverse of install, with safety checks)
**Dependencies**: Must understand exactly what Priority 3 (install.sh) creates
**Blocks**: Priority 6 (integration testing includes uninstall verification)

**Spec refs**:
- `client/specs/SCRIPTS.md` lines 14-18: full uninstall.sh behavior specification
- `client/specs/FUNCTIONALITIES.md` line 8: "Uninstaller that removes only client-side changes"
- `client/specs/FILES.md` line 13: file location `client/scripts/uninstall.sh`

**Tasks**:
- [ ] Add `#!/bin/bash` + `set -euo pipefail` header
- [ ] Remove Aider via `pipx uninstall aider-chat`
  - Ref: `client/specs/SCRIPTS.md` line 15 ("Removes Aider")
  - Handle case where Aider is not installed (graceful skip)
- [ ] Delete `~/.private-ai-client/` directory
  - Ref: `client/specs/SCRIPTS.md` line 16 ("Deletes `~/.private-ai-client`")
  - Handle case where directory does not exist
- [ ] Remove or comment out the `source ~/.private-ai-client/env` line from `~/.zshrc`
  - Ref: `client/specs/SCRIPTS.md` line 17 ("Comments out or removes the sourcing line from shell profile")
  - Use the same marker comment from install.sh to identify the line
- [ ] Also clean `~/.bashrc` if the sourcing line exists there
- [ ] Leave Tailscale and Homebrew untouched
  - Ref: `client/specs/SCRIPTS.md` line 18 ("Leaves Tailscale and Homebrew untouched")
- [ ] Leave pipx itself untouched (only remove the aider-chat package)
- [ ] Print clear summary of what was removed and what was left
- [ ] Handle all edge cases gracefully (files missing, partial install, etc.)

---

## Priority 5 — Server: `server/scripts/warm-models.sh`

**Status**: NOT STARTED
**Estimated effort**: Small-medium (Ollama CLI + API calls)
**Dependencies**: Priority 2 (requires Ollama installed and running)
**Blocks**: Priority 6 (integration testing includes model warm-up verification)

**Spec refs**:
- `server/specs/FUNCTIONALITIES.md` line 17: "Automatic model loading on first request (or pre-warming via optional script)"
- `server/specs/FUNCTIONALITIES.md` line 19: "Keep-alive of frequently used models in memory when possible"
- `server/specs/INTERFACES.md` line 17: "Optional boot script for model pre-warming"
- `server/specs/FILES.md` line 13: file location `server/scripts/warm-models.sh`

**Tasks**:
- [ ] Add `#!/bin/bash` + `set -euo pipefail` header
- [ ] Accept model names as command-line arguments
  - e.g. `./warm-models.sh qwen2.5-coder:32b deepseek-r1:70b`
  - Abort with usage message if no arguments provided
- [ ] Verify Ollama is running (`curl -sf http://localhost:11434/v1/models`) before proceeding
- [ ] For each model: run `ollama pull <model>` (download if not already present)
  - Ref: `server/SETUP.md` lines 74-76
- [ ] For each model: send a lightweight `/v1/chat/completions` request to force-load into memory
  - Use minimal prompt (e.g. "hi") with `max_tokens: 1` to minimize inference cost
  - Ref: `server/specs/FUNCTIONALITIES.md` line 17 ("pre-warming")
- [ ] Report progress and status for each model (pulling, loading, ready, failed)
- [ ] Continue on individual model failures; print summary at end
- [ ] Document in script comments how to wire into launchd as a post-boot script
  - Ref: `server/specs/INTERFACES.md` line 17 ("Optional boot script for model pre-warming")

---

## Priority 6 — Integration Testing

**Status**: BLOCKED (requires Priorities 1-5 to be implemented)
**Dependencies**: All implementation priorities (1-5)
**Blocks**: Priority 7 (documentation polish)

**Spec refs**:
- `client/specs/API_CONTRACT.md` lines 17-26: supported endpoints and capabilities
- `client/specs/API_CONTRACT.md` lines 46-51: error behavior (404, 429, 500)
- `server/specs/FUNCTIONALITIES.md` lines 6-13: API capabilities
- `server/specs/SECURITY.md` lines 11-12: Tailscale ACL enforcement

**Tasks** (manual testing checklist -- run from an authorized client machine):
- [ ] Verify `curl http://private-ai-server:11434/v1/models` returns JSON model list
  - Ref: `client/specs/API_CONTRACT.md` line 24 (`/v1/models` GET)
- [ ] Test `/v1/chat/completions` non-streaming request
  - Ref: `client/specs/API_CONTRACT.md` line 23
- [ ] Test `/v1/chat/completions` streaming request (`stream: true`)
  - Ref: `client/specs/API_CONTRACT.md` line 23
- [ ] Test `/v1/chat/completions` with JSON mode (`response_format: { "type": "json_object" }`)
  - Ref: `client/specs/API_CONTRACT.md` line 23
- [ ] Test `/v1/chat/completions` with tools/tool_choice
  - Ref: `client/specs/API_CONTRACT.md` line 23 (if model supports it)
- [ ] Test `/v1/models/{model}` for single model details
  - Ref: `client/specs/API_CONTRACT.md` line 25
- [ ] Test `/v1/responses` endpoint (non-stateful)
  - Ref: `client/specs/API_CONTRACT.md` line 26
- [ ] Test that Aider connects and can complete a chat exchange with the server
  - Ref: `client/specs/FUNCTIONALITIES.md` lines 12-13
- [ ] Test Tailscale ACL enforcement: unauthorized device should be rejected
  - Ref: `server/specs/SECURITY.md` lines 11-12
- [ ] Test model warm-up script pulls and loads models correctly
  - Ref: `server/specs/FUNCTIONALITIES.md` line 17
- [ ] Verify error codes match `API_CONTRACT.md`: 404 (unreachable), 429 (concurrency), 500 (inference)
  - Ref: `client/specs/API_CONTRACT.md` lines 46-51
- [ ] Verify client install.sh works via curl pipe method
  - Ref: `client/SETUP.md` lines 11-13
- [ ] Verify client uninstall.sh cleanly removes all client-side changes
  - Ref: `client/specs/SCRIPTS.md` lines 14-18
- [ ] Verify re-running install.sh (idempotency) does not break existing setup

---

## Priority 7 — Documentation Polish

**Status**: BLOCKED (requires Priorities 1-6 to validate documentation accuracy)
**Dependencies**: All implementation and testing priorities

**Tasks**:
- [ ] Update `server/README.md` with actual tested commands and sample outputs
- [ ] Update `client/README.md` with actual tested commands and sample outputs
- [ ] Expand troubleshooting sections in both SETUP.md files based on issues found during testing
- [ ] Add quick-reference card for common operations (start/stop server, switch models, check status)
- [ ] Verify all cross-links between spec files, READMEs, and SETUP.md are correct
- [ ] Fix minor inconsistency: README files say "macOS 14 Sonnet" but macOS 14 is "Sonoma"
  - Found in: `server/README.md` line 19, `client/README.md` line 24, root `README.md` lines 51, 57

---

## Implementation Constraints (from specs)

These constraints apply to ALL implementation work and are non-negotiable:

1. **Security** (`server/specs/SECURITY.md`): No public internet exposure at any stage. API has no built-in auth -- relies entirely on Tailscale network-layer isolation. Ollama must not run as root. Logs remain local, no telemetry.

2. **API contract** (`client/specs/API_CONTRACT.md`): This is the single source of truth for the server-client interface. The client must configure exactly these env vars and rely only on the documented endpoints. The server must guarantee all documented endpoints and behaviors.

3. **Independence** (`AGENTS.md`): Server and client remain independent except via the API contract. No assumptions about server internals from the client side.

4. **Idempotency**: All scripts must be safe to re-run without breaking existing setup.

5. **No stubs**: Implement completely or not at all. No placeholders or partial implementations.

6. **macOS only (v1)**: Both server and client target macOS only. Server requires Apple Silicon. Client requires macOS 14+.

7. **Aider is the only v1 interface** (`client/specs/ARCHITECTURE.md` line 7): No custom HTTP clients, no IDE plugins, no web UI. But the env var setup ensures any OpenAI-compatible tool works automatically.

8. **curl-pipe install support** (`client/SETUP.md` lines 11-13): The client install script must work when piped from curl (not just from a local clone). This means env.template content must be embeddable or downloadable.

## Identified Spec Issues (non-blocking)

These are documentation inconsistencies found during the audit. They do NOT block implementation but should be noted:

1. **"Sonnet" vs "Sonoma"**: Multiple README files refer to "macOS 14 Sonnet" but the correct name is "macOS 14 Sonoma". Found in `server/README.md` line 19, `client/README.md` line 24, and root `README.md` lines 51 and 57.

2. **SETUP.md deprecated API**: `server/SETUP.md` line 61 uses `launchctl load -w` which is deprecated on modern macOS. The install script must use `launchctl bootstrap` instead. The SETUP.md itself should ideally be updated after implementation is validated (Priority 7).

3. **SETUP.md conflicting service management**: `server/SETUP.md` step 3 creates a manual plist, then step 4 suggests `brew services restart ollama` -- these two approaches conflict. The install script resolves this by exclusively using the manual plist approach.
