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
| **Specs** | 100% | All specs are v2-compliant. V1 content removed from FUNCTIONALITIES.md, Tailscale references fixed across all spec files. |
| **Server Scripts** | ~20% | `warm-models.sh` is v2-compliant. `install.sh`, `uninstall.sh`, `test.sh` still implement v1 (Tailscale + HAProxy). |
| **Client Scripts** | ~70% | Version management scripts (3) are v2-compliant. `install.sh`, `test.sh`, `uninstall.sh` have Tailscale references. |
| **Root Analytics** | 100% | All analytics scripts and `ANALYTICS_README.md` are v2-compliant. |
| **Documentation** | 100% | All docs are v2-compliant. `IMPLEMENTATION_PLAN.md` updated. |

**Target Architecture** (v2):
```
Client → WireGuard VPN (OpenWrt Router) → Firewall → Ollama (192.168.100.10:11434)
```

**v1 Architecture** (to be eliminated):
```
Client → Tailscale → HAProxy (100.x.x.x:11434) → Ollama (127.0.0.1:11434)
```

---

## Remaining Tasks

### P0: Spec Cleanup — Remove v1 Contradictions

**Effort**: Small | **Risk**: Low (documentation only)

These spec files claim v2.0.0 but contain active v1 prescriptions that contradict v2 architecture:

- [x] **server/specs/FUNCTIONALITIES.md**: Deleted 360 lines of v1 content (HAProxy, Tailscale, v1 workflows)
- [x] **client/specs/API_CONTRACT.md**: "Tailscale provides security" → "WireGuard VPN provides security"
- [x] **client/specs/FUNCTIONALITIES.md**: Tailscale → WireGuard VPN (2 references)
- [x] **client/specs/ARCHITECTURE.md**: "Tailscale + dummy API key" → "WireGuard VPN + dummy API key"
- [x] **server/specs/HARDENING_OPTIONS.md**: Replaced Tailscale baseline references with WireGuard VPN
- [x] **ANALYTICS_README.md**: Replaced `http://ai-server:11434` with `http://192.168.100.10:11434`
- [x] **client/scripts/check-compatibility.sh**: "Tailscale is connected" → "WireGuard VPN is connected"

### P1: Server Scripts — Rewrite for v2 Architecture

**Effort**: Large | **Risk**: Medium (core functionality)

#### P1a: server/scripts/install.sh (complete rewrite required)

**Remove** (v1 code):
- Tailscale installation and connection workflow (~130 lines)
- HAProxy installation and configuration (~270 lines)
- `OLLAMA_HOST=127.0.0.1` loopback binding
- Tailscale references in final summary

**Add** (v2 requirements from `server/specs/SCRIPTS.md`):
- Router setup check prompt (reference `ROUTER_SETUP.md`, abort if not completed)
- DMZ network configuration prompts (subnet default 192.168.100.0/24, server IP default 192.168.100.10)
- Static IP configuration via `networksetup -setmanual`
- `OLLAMA_HOST=192.168.100.10` (DMZ) with `0.0.0.0` as fallback option
- Router connectivity verification (`ping 192.168.100.1`)
- Model pre-pull prompt
- v2 final summary (router WireGuard setup, client peer addition, DMZ security notes)
- Network binding verification (`lsof -i :11434`)
- Self-test against DMZ IP (not localhost)

#### P1b: server/scripts/uninstall.sh

**Remove** (v1 code):
- HAProxy cleanup section (~64 lines)
- Tailscale references in "preserved" list and instructions

**Add** (v2 requirements):
- Static IP → DHCP revert prompt (`networksetup -setdhcp`)
- Router configuration cleanup note (WireGuard peer, DMZ rules — manual)

#### P1c: server/scripts/test.sh

**Remove** (v1 code):
- Tailscale IP access test
- Entire HAProxy test section (10 tests)
- Tailscale reference in "Next Steps"

**Change** (v1 → v2):
- `OLLAMA_HOST` check: accept `192.168.100.10` or `0.0.0.0` (not `127.0.0.1`)
- Binding verification: check for DMZ IP or `0.0.0.0` (not loopback)
- Remove `haproxy` from grep patterns

**Add** (v2 requirements from `server/specs/SCRIPTS.md`):
- Network Configuration Tests (~7 tests): static IP, interface binding, router connectivity, DNS, outbound internet, LAN isolation
- Router Integration manual checklist display (VPN client tests, router tests, internet tests)
- DMZ IP connectivity test alongside localhost test
- Update total test count

### P2: Client Scripts — Update VPN References

**Effort**: Medium | **Risk**: Medium

#### P2a: client/scripts/install.sh (substantial rewrite)

**Remove** (v1 code):
- Tailscale installation and connection workflow (~130 lines)
- Tailscale hostname-based server discovery

**Add** (v2 requirements from `client/specs/SCRIPTS.md`):
- WireGuard installation (`brew install wireguard-tools`)
- WireGuard keypair generation (store in `~/.ai-client/wireguard/`)
- Display public key with instructions to send to router admin
- Prompts for: server IP (default 192.168.100.10), VPN server public key, VPN server endpoint
- WireGuard configuration file generation
- Import instructions (WireGuard app or `wg-quick`)
- VPN connection confirmation before connectivity test

**Change**:
- Replace `__HOSTNAME__` substitution with static IP (default 192.168.100.10)
- Update error messages from Tailscale to WireGuard references

#### P2b: client/scripts/uninstall.sh

**Change**:
- "Tailscale" references → "WireGuard"

**Add**:
- WireGuard config cleanup (before `~/.ai-client/` deletion)
- Optional WireGuard tools removal prompt
- Router admin reminder (display public key, remind to remove VPN peer)

#### P2c: client/scripts/test.sh

**Change**:
- Tests 8-9: Tailscale checks → WireGuard interface checks
- Test 14: Tailscale connectivity → WireGuard connectivity
- Error messages: Tailscale → WireGuard
- Next steps guidance: Tailscale → WireGuard

### P3: Hardware Validation (Manual Testing Phase)

**Effort**: Medium | **Dependencies**: P0-P2 complete | **Location**: Apple Silicon hardware only

Validation checklist:
- Server tests (`server/scripts/test.sh --verbose`) — verify all tests pass
- Client tests (`client/scripts/test.sh --verbose`) — verify all tests pass
- Manual Claude Code + Ollama integration validation
- Version management and analytics script validation
- End-to-end workflow testing with real models
- WireGuard VPN connectivity from remote client
- DMZ network isolation verification (server cannot reach LAN)

---

## Dependency Graph

```
P0 (spec cleanup) ─── no dependencies, can start immediately
    │
P1 (server scripts) ─── depends on P0 (specs must be correct before implementation)
P2 (client scripts) ─── depends on P0 (specs must be correct before implementation)
    │
P3 (hardware validation) ─── depends on P1 + P2
```

---

## Implementation Constraints

1. **Security**: WireGuard VPN + OpenWrt firewall + DMZ isolation. No public exposure. No built-in authentication.
2. **API contract**: `client/specs/API_CONTRACT.md` is the single source of truth for the server-client interface.
3. **Idempotency**: All scripts must be safe to re-run without side effects.
4. **No stubs**: Implement completely or not at all.
5. **Claude Code integration is optional**: Always prompt for user consent on the client side.
6. **curl-pipe install**: Client `install.sh` must work via `curl | bash`.
7. **Specs are authoritative**: `server/specs/*.md` (9 files), `client/specs/*.md` (9 files). Deviations must be corrected unless there is a compelling reason to update the spec.
