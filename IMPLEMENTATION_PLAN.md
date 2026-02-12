<!--
 Copyright (c) 2026 Henrique Falconer. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

# Implementation Plan

**Last Updated**: 2026-02-12

---

## Completed Work (v1.1.2)

### P0: Specification Cleanup ✅ COMPLETE
- All 18 specification files made v2-compliant (removed v1 contradictions)
- All 5 documentation files made v2-compliant (READMEs, SETUP guides, ROUTER_SETUP.md)
- v1 references retained only as historical context

### P1: Server Scripts ✅ COMPLETE (2026-02-12)
**Spec authority**: `server/specs/SCRIPTS.md`

- **install.sh**: Complete rewrite. 752→426 lines (43% reduction). Removed Tailscale and HAProxy. Added DMZ network configuration, static IP setup, interface detection, binding choice (DMZ-only vs all interfaces), router connectivity validation.
- **uninstall.sh**: v2-compliant. Removed HAProxy cleanup. Added optional static IP→DHCP revert and router config cleanup reminders.
- **test.sh**: v2-compliant. 29 tests (down from 36). Removed loopback/localhost/Tailscale/HAProxy tests. Added DMZ IP connectivity, router gateway, DNS resolution, internet connectivity, LAN isolation verification.
- **warm-models.sh**: v2-compliant. Added dynamic host detection (`detect_ollama_host()` function) to work with DMZ IP binding.

### P2: Client Scripts ✅ COMPLETE (2026-02-12)
**Spec authority**: `client/specs/SCRIPTS.md`

- **install.sh**: Tailscale→WireGuard migration. 617→643 lines. Added WireGuard tools install, keypair generation, config file creation, VPN server prompts, connection instructions. Updated env template with static DMZ IP.
- **uninstall.sh**: v2-compliant. Added WireGuard config display, optional tools cleanup, router admin reminder with public key.
- **test.sh**: v2-compliant. All 40 tests updated. Changed Tailscale checks to WireGuard interface validation.

### Supporting Components ✅ COMPLETE
- **Root Analytics** (3 scripts): `loop.sh`, `loop-with-analytics.sh`, `compare-analytics.sh` — all v2-compliant
- **Client Version Management** (3 scripts): `check-compatibility.sh`, `pin-versions.sh`, `downgrade-claude.sh` — all v2-compliant
- **Client Config**: `env.template` — static DMZ IP `192.168.100.10`, correct environment variables

---

## Current Status

| Component | v2 Compliance | Notes |
|-----------|:------------:|-------|
| **Specs** (18 files) | 100% | All v2-compliant. v1 mentions are historical context only. |
| **Documentation** (5 files) | 100% | READMEs, SETUP guides, ROUTER_SETUP.md — all v2-compliant. |
| **Server Scripts** (4 files) | 100% | install.sh, uninstall.sh, warm-models.sh, test.sh |
| **Client Scripts** (3 files) | 100% | install.sh, test.sh, uninstall.sh |
| **Root Analytics** (3 scripts) | 100% | loop.sh, loop-with-analytics.sh, compare-analytics.sh |
| **Client Version Mgmt** (3 scripts) | 100% | check-compatibility.sh, pin-versions.sh, downgrade-claude.sh |
| **Client Config** | 100% | env.template |

**Target Architecture** (v2):
```
Client → WireGuard VPN (OpenWrt Router) → Firewall → Ollama (192.168.100.10:11434)
```

**Key Changes from v1**:
- Removed: Tailscale VPN, HAProxy reverse proxy, loopback binding
- Added: WireGuard VPN, direct DMZ network access, OpenWrt router firewall
- Security model: Two-layer (Network Perimeter + AI Server), DMZ isolation

---

## Dependency Graph

```
P1 (server scripts) ─── COMPLETE ✅
P2 (client scripts) ─── COMPLETE ✅
        │
        ↓
P3 (hardware validation) ─── BLOCKED (awaiting hardware deployment)
```

P1 and P2 share no code and communicate only via `client/specs/API_CONTRACT.md`

---

## P3: Hardware Validation (REMAINING WORK)

**Status**: BLOCKED — awaiting hardware deployment
**Dependencies**: P1 + P2 complete ✅
**Location**: Apple Silicon Mac mini + OpenWrt router

### Validation Checklist

#### Server Installation
- [ ] `server/scripts/install.sh` completes without errors on target hardware
- [ ] DMZ network configuration (static IP 192.168.100.10, gateway 192.168.100.1)
- [ ] Ollama service starts successfully and binds to DMZ IP or 0.0.0.0
- [ ] `server/scripts/test.sh --verbose` — all 29 automated tests pass
- [ ] `server/scripts/uninstall.sh` cleanly removes configuration

#### Client Installation
- [ ] `client/scripts/install.sh` completes without errors
- [ ] WireGuard keypair generation and config file creation
- [ ] VPN connection established through OpenWrt router tunnel to server
- [ ] `client/scripts/test.sh --verbose` — all 40 automated tests pass
- [ ] `client/scripts/uninstall.sh` cleanly removes configuration

#### Network & Security
- [ ] WireGuard VPN: client successfully connects to server via router
- [ ] DMZ isolation: server cannot reach LAN (`ping 192.168.1.x` fails — expected)
- [ ] Firewall rules: only client VPN traffic reaches server port 11434
- [ ] DNS resolution works on both server and client

#### End-to-End Functionality
- [ ] Aider integration: inference works via OpenAI API (`/v1/chat/completions`)
- [ ] Claude Code integration: inference works via Anthropic API (`/v1/messages`)
- [ ] Model warm-up: `server/scripts/warm-models.sh` successfully pre-loads models
- [ ] Version management: `check-compatibility.sh`, `pin-versions.sh`, `downgrade-claude.sh` work correctly
- [ ] Analytics: `loop-with-analytics.sh` captures metrics

#### Reliability
- [ ] Idempotency: re-running install scripts on already-installed system succeeds cleanly
- [ ] Service persistence: Ollama restarts automatically after reboot
- [ ] Error recovery: scripts handle common failure modes gracefully

---

## Implementation Constraints

All code development follows these principles:

1. **Specs are authoritative**: `server/specs/*.md` (9 files), `client/specs/*.md` (9 files). Scripts must match specs exactly.
2. **API contract**: `client/specs/API_CONTRACT.md` is the single source of truth for the server-client interface.
3. **Security model**: WireGuard VPN + OpenWrt firewall + DMZ isolation. No public exposure. No built-in authentication.
4. **Idempotency**: All scripts must be safe to re-run without side effects.
5. **No stubs**: Implement features completely or not at all. No placeholder code.
6. **User consent**: Claude Code integration is optional and requires explicit user opt-in.
7. **curl-pipe install**: Client `install.sh` must work via `curl | bash` for easy remote deployment.
