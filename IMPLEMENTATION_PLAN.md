<!--
 Copyright (c) 2026 Henrique Falconer. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

# Implementation Plan

**Last Updated**: 2026-02-12

---

## Current Status

| Component | v2 Compliance | Summary |
|-----------|:------------:|---------|
| **Specs** | 100% | All 18 specs (9 server, 9 client) are v2-compliant. No v1 contradictions remain. |
| **Server Scripts** | ~20% | Only `warm-models.sh` is v2-compliant. `install.sh`, `uninstall.sh`, `test.sh` still implement v1 (Tailscale + HAProxy + loopback). |
| **Client Scripts** | ~60% | `check-compatibility.sh`, `pin-versions.sh`, `downgrade-claude.sh`, `env.template` are v2-compliant. `install.sh` and `test.sh` still have Tailscale. `uninstall.sh` has minor Tailscale refs. |
| **Root Analytics** | 100% | `loop.sh`, `loop-with-analytics.sh`, `compare-analytics.sh`, `ANALYTICS_README.md` are v2-compliant. |
| **Documentation** | 100% | All READMEs, SETUP guides, ROUTER_SETUP.md are v2-compliant. |

**Target Architecture** (v2):
```
Client → WireGuard VPN (OpenWrt Router) → Firewall → Ollama (192.168.100.10:11434)
```

**v1 Architecture** (to be eliminated from scripts):
```
Client → Tailscale → HAProxy (100.x.x.x:11434) → Ollama (127.0.0.1:11434)
```

---

## Remaining Tasks

### P1: Server Scripts — Rewrite for v2 Architecture

**Effort**: Large | **Risk**: Medium (core functionality)
**Spec authority**: `server/specs/SCRIPTS.md`

#### P1a: server/scripts/install.sh (complete rewrite required)

**Remove** (v1 code — ~470 lines):
- Tailscale installation and connection workflow (lines 95–227, ~130 lines)
- HAProxy installation and configuration (lines 352–624, ~270 lines)
- Tailscale ACL configuration instructions (lines 626–698, ~70 lines)
- `OLLAMA_HOST=127.0.0.1` loopback binding (line 284)
- Tailscale/HAProxy references in final summary (lines 700–751)

**Add** (v2 requirements — ~200 lines):
- Router setup check prompt (reference `ROUTER_SETUP.md`, abort if not completed)
- DMZ network configuration prompts (subnet default `192.168.100.0/24`, server IP default `192.168.100.10`)
- Validate IP format and subnet membership
- Static IP configuration via `sudo networksetup -setmanual`
- Interface detection via `networksetup -listallhardwareports`
- DNS configuration (router as primary, public as backup)
- `OLLAMA_HOST=192.168.100.10` (DMZ) with `0.0.0.0` as configurable alternative
- Network binding verification (`lsof -i :11434`) confirming DMZ IP or `*:11434`
- Self-test against DMZ IP: `curl http://192.168.100.10:11434/v1/models`
- Router connectivity verification (`ping -c 3 192.168.100.1`)
- Optional model pre-pull prompt with popular model examples
- v2 final summary: DMZ IP status, auto-start enabled, router connectivity, "What's Next" (verify router WireGuard, add VPN peers, install client, test from VPN), security notes, troubleshooting

**Keep** (v2-compatible sections):
- System validation: macOS 14+, Apple Silicon, Homebrew (lines 54–94)
- Ollama install/validation via Homebrew (lines 229–248)
- Stop existing services (lines 250–262)
- LaunchAgent plist creation structure (lines 264–302, modify OLLAMA_HOST value)
- LaunchAgent loading via `launchctl bootstrap` (lines 304–308)
- Ollama startup verification loop (lines 310–329, modify URL to DMZ IP)
- Process ownership check (lines 331–342)

#### P1b: server/scripts/uninstall.sh

**Remove** (v1 code — ~70 lines):
- HAProxy cleanup section (lines 92–155): service stop, plist removal, config dir cleanup, log cleanup
- "Tailscale" in preserved items list (line 161) and uninstall instructions (lines 200–206)
- "HAProxy binary" in preserved items list (line 163)

**Add** (v2 requirements):
- Optional static IP → DHCP revert: prompt user, run `sudo networksetup -setdhcp "Ethernet"`
- Router configuration cleanup note: remind user to manually remove WireGuard peer and DMZ firewall rules from router (reference `ROUTER_SETUP.md`)

**Keep**: Ollama service stop, plist removal, log cleanup, preserve Homebrew/Ollama binary/models

#### P1c: server/scripts/test.sh

**Remove** (v1 code — ~170 lines):
- Test 18: Loopback binding check expecting `127.0.0.1` (lines 853–872)
- Test 19: Localhost access test (lines 874–880)
- Test 20: Tailscale IP access test (lines 882–897)
- Tests 21–30: Entire HAProxy test section (lines 900–1058, 10 tests)

**Modify** (v1 → v2):
- Test 17 (lines 840–848): `OLLAMA_HOST` plist check — accept `192.168.100.10` or `0.0.0.0` (not `127.0.0.1`)
- "What's Next" section: reference ROUTER_SETUP.md, WireGuard, DMZ (not Tailscale/HAProxy)

**Add** (v2 requirements — ~6 new tests):
- Network Configuration Tests:
  - Verify static IP configured (`networksetup -getinfo "Ethernet"`)
  - Verify IP matches expected DMZ IP (e.g., `192.168.100.10`)
  - Test router connectivity (`ping -c 3 192.168.100.1`)
  - Test DNS resolution
  - Test outbound internet (`ping -c 3 8.8.8.8`)
  - Verify LAN isolation (`ping -c 1 192.168.1.x` — should fail/timeout)
- DMZ IP connectivity test: `curl http://192.168.100.10:11434/v1/models`
- Router Integration manual checklist display (VPN client tests, router tests, internet tests — not automated)
- Update `TOTAL_TESTS` variable to reflect new count (~31 automated tests)

**Keep** (28 v2-compliant tests):
- Service Status: Tests 1–4 (LaunchAgent, process, port, HTTP)
- OpenAI API: Tests 5–11 (models, chat completions, streaming, usage, JSON mode, responses)
- Anthropic API: Tests 21–26 (messages, streaming SSE, system prompt, errors, multi-turn, streaming usage)
- Error Behavior: Tests 12–13 (nonexistent model, malformed request)
- Security: Tests 14–16 (process owner, logs, plist exists)

---

### P2: Client Scripts — Update VPN References

**Effort**: Medium | **Risk**: Medium
**Spec authority**: `client/specs/SCRIPTS.md`

#### P2a: client/scripts/install.sh (substantial rewrite)

**Remove** (v1 code — ~130 lines):
- Tailscale GUI check/install (lines 152–171)
- Tailscale connection flow: GUI open, CLI auth, connection polling, IP detection (lines 173–280)
- Server hostname prompt defaulting to `self-sovereign-ollama` (lines 284–291)
- "Tailscale ACLs" in error messages (line 558)
- "Tailscale is connected" in next steps (line 607)

**Add** (v2 requirements — ~130 lines):
- WireGuard installation: `brew install wireguard-tools`
- WireGuard keypair generation: `wg genkey | tee privatekey | wg pubkey > publickey`
- Store keys in `~/.ai-client/wireguard/` with `chmod 600` on private key
- Display public key prominently with instructions to send to router admin
- Prompt for server IP (default `192.168.100.10` instead of hostname)
- Prompt for VPN server public key (from router admin)
- Prompt for VPN server endpoint (public IP:port, e.g., `1.2.3.4:51820`)
- Generate WireGuard config file (`~/.ai-client/wireguard/wg0.conf`)
- Provide import instructions for WireGuard app or `wg-quick`
- VPN connection confirmation prompt before connectivity test
- Final summary: display WireGuard public key again, remind to send to admin, remind to connect VPN

**Change**:
- `__HOSTNAME__` substitution in env template → use server IP (default `192.168.100.10`)
- `claude-ollama` alias URL → `http://$SERVER_IP:11434`
- All error/help messages: "Tailscale" → "WireGuard VPN"

**Keep**: macOS/shell detection, Homebrew check, Python install, pipx/Aider install, env file creation, shell profile modification, Claude Code alias creation, uninstall.sh copy

#### P2b: client/scripts/uninstall.sh (minor update)

**Change** (2 lines):
- Line 6: "Leaves Tailscale" → "Leaves WireGuard"
- Line 142: `echo "  - Tailscale"` → `echo "  - WireGuard"`

**Add**:
- WireGuard config cleanup: remove `~/.ai-client/wireguard/` contents (already handled by `~/.ai-client/` deletion, but the spec also calls for optional WireGuard tools removal prompt and router admin reminder)
- Optional `brew uninstall wireguard-tools` prompt
- Reminder to have router admin remove VPN peer (display public key if available before deletion)

#### P2c: client/scripts/test.sh

**Change** (~20 lines):
- Test 8 (lines 248–254): `command -v tailscale` → `command -v wg` or `brew list wireguard-tools`
- Test 9 (lines 256–267): `tailscale status`/`tailscale ip -4` → WireGuard interface check (e.g., `wg show` or check for active utun interface)
- Error messages at lines 558, 607, 641, 1403, 1413: "Tailscale" → "WireGuard VPN" / "VPN"
- Test 14 connectivity context: VPN connection check before server tests

**Keep**: All other tests (environment config, dependencies, API contract, Aider, Claude Code, version management — all v2-compliant)

---

### P3: Hardware Validation (Manual Testing Phase)

**Effort**: Medium | **Dependencies**: P1 + P2 complete | **Location**: Apple Silicon hardware + OpenWrt router

Validation checklist:
- Server install: `server/scripts/install.sh` completes without errors
- Server tests: `server/scripts/test.sh --verbose` — all automated tests pass
- Server uninstall: `server/scripts/uninstall.sh` cleanly removes configuration
- Client install: `client/scripts/install.sh` completes without errors
- Client tests: `client/scripts/test.sh --verbose` — all automated tests pass
- Client uninstall: `client/scripts/uninstall.sh` cleanly removes configuration
- WireGuard VPN: client connects to server through router VPN tunnel
- DMZ isolation: server cannot reach LAN (`ping 192.168.1.x` fails)
- End-to-end: Aider and Claude Code inference via VPN
- Version management: `check-compatibility.sh`, `pin-versions.sh`, `downgrade-claude.sh` work correctly
- Analytics: `loop-with-analytics.sh` captures metrics correctly
- Idempotency: re-running install scripts on already-installed system succeeds cleanly

---

## Dependency Graph

```
P1 (server scripts) ─── can start immediately (specs are authoritative)
P2 (client scripts) ─── can start immediately (independent of P1)
    │
P3 (hardware validation) ─── depends on P1 + P2
```

P1 and P2 are independent and can be executed in parallel. They share no code and communicate only via the API contract in `client/specs/API_CONTRACT.md`.

---

## Implementation Constraints

1. **Security**: WireGuard VPN + OpenWrt firewall + DMZ isolation. No public exposure. No built-in authentication.
2. **API contract**: `client/specs/API_CONTRACT.md` is the single source of truth for the server-client interface.
3. **Idempotency**: All scripts must be safe to re-run without side effects.
4. **No stubs**: Implement completely or not at all.
5. **Claude Code integration is optional**: Always prompt for user consent on the client side.
6. **curl-pipe install**: Client `install.sh` must work via `curl | bash`.
7. **Specs are authoritative**: `server/specs/*.md` (9 files), `client/specs/*.md` (9 files). Deviations must be corrected unless there is a compelling reason to update the spec.
