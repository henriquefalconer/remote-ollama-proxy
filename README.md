<!--
 Copyright (c) 2026 Henrique Falconer. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

# self-sovereign-ollama

Secure remote access to Ollama on your hardware.

Complete infrastructure for private AI inference using OpenWrt router, WireGuard VPN, and DMZ network segmentation. No third-party cloud services.

## Project Structure

This monorepo contains two main components:

- **server/** – Ollama server configuration with OpenWrt router + DMZ network segmentation
- **client/** – Client-side setup and configuration for connecting to remote Ollama

## Overview

The self-sovereign-ollama project provides a complete solution for running Ollama on your own hardware with secure remote access via self-hosted WireGuard VPN, zero public internet exposure, and zero third-party cloud dependencies.

### Server (ai-server)
- Runs Ollama on a dedicated Apple Silicon Mac with high unified memory
- **Two-layer security**: Network Perimeter (OpenWrt router + WireGuard VPN + DMZ isolation + Firewall) + AI Server (Ollama)
- OpenWrt router provides VPN authentication, DMZ network segmentation, and port-level firewall rules
- Exposes dual API: OpenAI-compatible `/v1` and Anthropic-compatible `/v1/messages` endpoints
- Accessible only via WireGuard VPN (self-sovereign infrastructure)
- 24/7 operation for on-demand inference
- Supports both Aider (OpenAI API) and Claude Code (Anthropic API)

### Client (ai-client)
- macOS environment setup and configuration
- Connects to remote Ollama server via WireGuard VPN
- Configures tools (Aider, optionally Claude Code) to use remote Ollama automatically
- Optional: Claude Code can use either Anthropic cloud API or remote Ollama backend
- Zero manual configuration per session

## Quick Start

### Server Setup
See [server/README.md](server/README.md) for detailed server installation and configuration.

### Client Setup
See [client/README.md](client/README.md) for client installation and usage.

## Supported Tools in Client

### Aider
- Uses OpenAI-compatible API (`/v1/chat/completions`)
- Connects to remote Ollama automatically after installation
- Zero configuration per session

### Claude Code
- **Default**: Uses Anthropic cloud API (Opus 4.6, Sonnet 4.5)
- **Optional**: Can use self-hosted Ollama backend via Anthropic-compatible API (`/v1/messages`)
- Optional backend switching via shell alias
- Version compatibility checking and management tools included

## Network Architecture

```
Client → WireGuard VPN (Router) → Firewall (port 11434 only) → Ollama (DMZ: 192.168.100.10)
```

**Two-layer security:**
1. **Network Perimeter** (Router + VPN + DMZ + Firewall) - Controls WHO can reach the server and WHAT ports are accessible
2. **AI Server** (Ollama on DMZ) - Provides inference services

**Network Topology:**
- **VPN subnet**: 10.10.10.0/24 (WireGuard clients)
- **DMZ subnet**: 192.168.100.0/24 (Ollama server isolated from LAN)
- **LAN subnet**: 192.168.1.0/24 (Admin only, no VPN/DMZ access)

**Properties:**
- **No public internet exposure** – All access via self-hosted WireGuard VPN
- **Self-sovereign infrastructure** – No third-party VPN services (was Tailscale in v1)
- **DMZ isolation** – Server separated from LAN, controlled firewall access
- **Per-peer VPN authentication** – WireGuard public key cryptography
- **Port-level firewall** – Only port 11434 accessible from VPN
- **Dual API support** – OpenAI-compatible `/v1/*` and Anthropic-compatible `/v1/messages`
- Works with any tool supporting custom OpenAI or Anthropic base URLs

## Requirements

### Router (Network Perimeter)
- OpenWrt 23.05 LTS or later
- WireGuard support (built into OpenWrt kernel)
- Wired Ethernet ports (no Wi-Fi infrastructure)
- Public IP with port forwarding capability (for VPN endpoint)

### Server
- Apple Silicon Mac (M-series) with ≥96 GB unified memory recommended
- macOS 14 Sonoma or later
- Wired Ethernet connection to router (DMZ network)
- High upload bandwidth (≥100 Mb/s recommended)
- 24/7 operation capability

### Client
- macOS 14 Sonoma or later
- Homebrew
- Python 3.10+
- WireGuard client (installed via Homebrew)

## Documentation

### Setup Guides
- [server/README.md](server/README.md) – Server overview and quick reference
- [server/SETUP.md](server/SETUP.md) – Server installation instructions
- [server/ROUTER_SETUP.md](server/ROUTER_SETUP.md) – OpenWrt router + WireGuard VPN configuration guide
- [client/README.md](client/README.md) – Client overview and quick reference
- [client/SETUP.md](client/SETUP.md) – Client installation instructions

### Specifications
- **Server specs**: `server/specs/` – Server architecture, dual API support, Anthropic compatibility, **security model**, hardening options
- **Client specs**: `client/specs/` – Client architecture, API contract, Claude Code integration, analytics, version management

### Project Management
- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) – Implementation status and roadmap
- [AGENTS.md](AGENTS.md) – Component responsibilities and coordination

## Security Model

### Two-Layer Defense in Depth

**Layer 1: Network Perimeter (OpenWrt Router)**
- **WireGuard VPN**: Per-peer public key authentication (cryptographic identity)
- **DMZ Network Segmentation**: Server isolated from LAN (192.168.100.0/24)
- **Firewall Rules**: VPN → DMZ port 11434 only, DMZ → LAN denied
- **Self-Sovereign Infrastructure**: No third-party VPN services

**Layer 2: AI Server (Ollama on DMZ)**
- **Direct API Exposure**: All Ollama endpoints accessible to authorized VPN clients
- **DMZ Binding**: Ollama listens on DMZ interface (192.168.100.10)
- **Isolation from LAN**: Cannot access personal files or services on LAN

### Security Properties

- ✅ **Cryptographic authentication** - WireGuard per-peer public keys (no shared secrets)
- ✅ **Network isolation** - DMZ separated from LAN, controlled access from VPN
- ✅ **Port-level control** - Only port 11434 accessible from VPN clients
- ✅ **Self-sovereign** - No reliance on third-party VPN services
- ✅ **Defense in depth** - VPN authentication + DMZ isolation + port firewall

### Architectural Trade-offs (v1 → v2)

**v1 (Tailscale + HAProxy + Loopback):**
- ✅ Endpoint allowlisting (HAProxy filtered specific paths)
- ✅ Three independent layers
- ❌ Third-party dependency (Tailscale mesh VPN)
- ❌ Additional proxy layer (HAProxy maintenance)

**v2 (WireGuard + DMZ + Firewall):**
- ✅ Self-sovereign infrastructure (WireGuard on own router)
- ✅ Simpler architecture (two layers, no application proxy)
- ✅ Lower latency (direct Ollama access)
- ❌ Port-level control only (all Ollama endpoints accessible to VPN clients)

See `server/specs/SECURITY.md` for complete security model documentation.

## License

Proprietary. Copyright (c) 2026 Henrique Falconer. All rights reserved.
