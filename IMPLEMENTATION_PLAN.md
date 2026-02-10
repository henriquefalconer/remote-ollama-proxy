<!--
 Copyright (c) 2026 Henrique Falconer. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

# Implementation Plan

Prioritized task list for achieving full spec implementation of both server and client components.

## Current Status

- **Specifications**: COMPLETE (all spec files exist and are well-defined)
- **Documentation**: COMPLETE (README.md and SETUP.md exist for both server and client)
- **Server implementation**: NOT STARTED (no scripts exist)
- **Client implementation**: NOT STARTED (no scripts or config exist)
- **Integration testing**: BLOCKED (requires both server and client implementation)

---

## Priority 1 — Server: `server/scripts/install.sh`

**Status**: NOT STARTED
**Spec refs**: `server/specs/ARCHITECTURE.md`, `server/specs/SECURITY.md`, `server/specs/INTERFACES.md`, `server/specs/FILES.md`

Must automate every step documented in `server/SETUP.md`:

- [ ] Create `server/scripts/` directory
- [ ] Detect macOS + Apple Silicon; abort with clear message otherwise
- [ ] Check/install Homebrew (prompt user if missing)
- [ ] Check/install Tailscale via `brew install tailscale`; open GUI for login + device approval; wait for Tailscale connection; display Tailscale IP
- [ ] Check/install Ollama via `brew install ollama`
- [ ] Stop any existing Ollama service (`brew services stop ollama` and/or `launchctl` unload) to avoid conflicts
- [ ] Create launchd plist at `~/Library/LaunchAgents/com.ollama.plist` with `OLLAMA_HOST=0.0.0.0`, `KeepAlive=true`, `RunAtLoad=true`, log paths; use `/opt/homebrew/bin/ollama serve`
- [ ] Load the plist via `launchctl bootstrap gui/$(id -u)` (modern macOS; avoid deprecated `launchctl load`)
- [ ] Verify Ollama is listening on port 11434 (retry with timeout)
- [ ] Prompt user to set Tailscale machine name to `private-ai-server` (or custom) in admin console
- [ ] Print ACL snippet from `server/specs/SECURITY.md` for user to apply in Tailscale admin
- [ ] Run a self-test: `curl http://localhost:11434/v1/models` should return JSON
- [ ] Make script idempotent (safe to re-run)
- [ ] Comprehensive error handling with clear messages at every step
- [ ] Do NOT run Ollama as root (per `server/specs/SECURITY.md`)

**SETUP.md issues to fix in the script (do not modify SETUP.md itself)**:
- Use `launchctl bootstrap`/`bootout` instead of deprecated `launchctl load`/`unload`
- Resolve the `brew services` vs manual plist conflict — script should own the plist and not mix approaches
- Note that `0.0.0.0` binding is per spec (`ARCHITECTURE.md` line 23: "Bind the API listener to all network interfaces"), but Tailscale ACLs provide the security layer

---

## Priority 2 — Client: `client/config/env.template`

**Status**: NOT STARTED
**Spec refs**: `client/specs/SCRIPTS.md` lines 20-23, `client/specs/API_CONTRACT.md` lines 37-44

- [ ] Create `client/config/` directory
- [ ] Create `env.template` with the exact variables from `API_CONTRACT.md`:
  ```bash
  export OLLAMA_API_BASE=http://__HOSTNAME__:11434/v1
  export OPENAI_API_BASE=http://__HOSTNAME__:11434/v1
  export OPENAI_API_KEY=ollama
  # export AIDER_MODEL=ollama/<model-name>
  ```
- [ ] Use a placeholder (e.g. `__HOSTNAME__`) so `install.sh` can substitute the user's chosen hostname (default `private-ai-server`)

---

## Priority 3 — Client: `client/scripts/install.sh`

**Status**: NOT STARTED
**Spec refs**: `client/specs/SCRIPTS.md` lines 3-11, `client/specs/REQUIREMENTS.md`, `client/specs/FUNCTIONALITIES.md`, `client/specs/ARCHITECTURE.md`

- [ ] Create `client/scripts/` directory
- [ ] Detect macOS 14+ and zsh/bash; abort with clear message otherwise
- [ ] Check/install Homebrew (prompt user if missing)
- [ ] Check/install Python 3.10+ via Homebrew if missing (`brew install python`)
- [ ] Check/install Tailscale GUI app; open it for login + device approval
- [ ] Prompt for server hostname (default: `private-ai-server`)
- [ ] Create `~/.private-ai-client/` directory
- [ ] Copy `config/env.template` → `~/.private-ai-client/env`, replacing `__HOSTNAME__` placeholder with chosen hostname
- [ ] Append `source ~/.private-ai-client/env` to `~/.zshrc` (with user consent); guard with a marker comment to avoid duplicates
- [ ] Also handle `~/.bashrc` if user uses bash
- [ ] Install pipx if not present (`brew install pipx && pipx ensurepath`)
- [ ] Install Aider via `pipx install aider-chat` (isolated, no global pollution per spec)
- [ ] Run connectivity test: `curl -sf http://<hostname>:11434/v1/models` and report result
- [ ] Print success summary with next steps (e.g. `aider --yes`)
- [ ] Make script idempotent
- [ ] Comprehensive error handling

---

## Priority 4 — Client: `client/scripts/uninstall.sh`

**Status**: NOT STARTED
**Spec refs**: `client/specs/SCRIPTS.md` lines 13-18

- [ ] Remove Aider via `pipx uninstall aider-chat`
- [ ] Delete `~/.private-ai-client/` directory
- [ ] Remove or comment out the `source ~/.private-ai-client/env` line from `~/.zshrc` and `~/.bashrc`
- [ ] Leave Tailscale and Homebrew untouched (per spec)
- [ ] Clear user feedback on what was removed and what was left
- [ ] Handle cases where files/directories don't exist gracefully

---

## Priority 5 — Server: `server/scripts/warm-models.sh`

**Status**: NOT STARTED
**Spec refs**: `server/specs/FUNCTIONALITIES.md` line 17 ("pre-warming via optional script"), `server/specs/FILES.md`, `server/specs/INTERFACES.md` line 17

- [ ] Accept model names as command-line arguments (e.g. `./warm-models.sh qwen2.5-coder:32b deepseek-r1:70b`)
- [ ] For each model: run `ollama pull <model>` (download if not present)
- [ ] For each model: send a lightweight chat completions request to force load into memory
- [ ] Report progress and status for each model
- [ ] Continue on individual model failures; report summary at end
- [ ] Can optionally be wired into launchd as a post-boot script (document how)

---

## Priority 6 — Integration Testing

**Status**: BLOCKED (requires Priority 1-4)
**Spec refs**: All specs

- [ ] From client machine: verify `curl http://private-ai-server:11434/v1/models` returns model list
- [ ] Test `/v1/chat/completions` non-streaming request
- [ ] Test `/v1/chat/completions` streaming request (`stream: true`)
- [ ] Test `/v1/chat/completions` with JSON mode (`response_format: { "type": "json_object" }`)
- [ ] Test tool/function calling if model supports it
- [ ] Test `/v1/responses` endpoint
- [ ] Test that Aider connects and can chat with the server model
- [ ] Test Tailscale ACL enforcement: unauthorized device should be rejected
- [ ] Test model warm-up script loads models correctly
- [ ] Verify error codes match `API_CONTRACT.md`: 404 (unreachable), 429 (concurrency), 500 (inference error)

---

## Priority 7 — Documentation Polish

**Status**: BLOCKED (requires Priority 1-5 to validate)

- [ ] Update `server/README.md` with actual tested commands and outputs
- [ ] Update `client/README.md` with actual tested commands and outputs
- [ ] Expand troubleshooting sections in both SETUP.md files based on issues found during testing
- [ ] Add quick-reference card for common operations (start/stop server, switch models, check status)

---

## Implementation Constraints

- Security requirements from `server/specs/SECURITY.md` are non-negotiable
- API contract in `client/specs/API_CONTRACT.md` is the single source of truth for the server-client interface
- No public internet exposure at any stage
- Server and client remain independent except via the API contract
- All scripts must be idempotent (safe to re-run)
- No placeholders or stubs — implement completely or not at all
