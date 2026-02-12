# Future Hardening Options (Design Space)

## Purpose of This Document

This document catalogs **optional capability-mediation controls** that can be layered onto the base architecture **without re-architecture**.

**This is NOT a roadmap or requirement list.**

It's a design space—a menu of orthogonal controls you can draw from later as needs evolve.

---

## Base Architecture (v2 Baseline)

The current two-layer architecture provides:

```
Layer 1: Network Perimeter (Router + VPN + DMZ + Firewall) → Controls WHO can reach the server and WHAT networks can communicate
Layer 2: AI Server (Ollama on DMZ) → Provides inference services
```

This baseline provides:
- ✅ Network perimeter security (OpenWrt firewall rules)
- ✅ VPN authentication (WireGuard per-peer public keys)
- ✅ DMZ isolation (separated from LAN, controlled access from VPN)
- ✅ Self-sovereign infrastructure (no third-party VPN services)
- ✅ Direct Ollama API exposure (all endpoints accessible to authorized VPN clients)

**The following options build on top of this foundation.**

---

## A. Network-Level Capability Mediation

These controls act **before** a request reaches Ollama.

### A1. Endpoint Allowlisting (Application Layer Proxy)

**Status**: ❌ NOT implemented in v2 (architectural trade-off)

**v1 approach**: HAProxy mediated access at application layer (endpoint allowlist)
**v2 approach**: Direct Ollama API exposure to VPN clients (all endpoints accessible)

**Why removed**:
- Simplified architecture (two layers instead of three)
- Lower maintenance burden (no HAProxy configuration)
- Ollama endpoints are designed for authorized client access
- DMZ isolation + VPN authentication provides network-level security

**If endpoint allowlisting becomes necessary**:
- **Option 1**: Add nginx/HAProxy reverse proxy between VPN and Ollama
- **Option 2**: Use OpenWrt Layer 7 packet inspection (complex, limited)
- **Option 3**: Implement application-level firewall (iptables string matching - fragile)

**Trade-off**: v2 prioritizes simplicity over granular endpoint control.

### A2. Port-Level Firewall Rules

**Capability**: Restrict traffic to specific port (11434) from specific source (VPN)

**Implementation**: OpenWrt firewall rules (already part of base v2 architecture)
```bash
# VPN → DMZ port 11434 only
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-VPN-to-Ollama'
uci set firewall.@rule[-1].src='vpn'
uci set firewall.@rule[-1].dest='dmz'
uci set firewall.@rule[-1].dest_ip='192.168.100.10'
uci set firewall.@rule[-1].dest_port='11434'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'
```

**Mitigates**:
- Access to non-Ollama services on DMZ server
- Port scanning attacks
- Lateral movement within DMZ

**Cost**: None (iptables rule matching)

**Complexity**: Low (standard firewall configuration)

### A3. Connection State Tracking

**Capability**: Only allow established/related connections, drop invalid packets

**Implementation**: OpenWrt firewall (default behavior)
```bash
# Only allow established/related connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -m state --state INVALID -j DROP
```

**Mitigates**:
- TCP hijacking
- Invalid packet injection
- Out-of-sequence attacks

**Cost**: Minimal (connection tracking overhead)

**Complexity**: Low (standard iptables)

### A4. Rate Limiting (Connection-Level)

**Capability**: Limit new connections per second from VPN clients

**Implementation**: OpenWrt iptables with recent module
```bash
# Limit new connections to 20/minute from single VPN client
iptables -A FORWARD -i wg0 -o br-dmz -p tcp --dport 11434 \
    -m recent --name vpn_connlimit --set
iptables -A FORWARD -i wg0 -o br-dmz -p tcp --dport 11434 \
    -m recent --name vpn_connlimit --update --seconds 60 --hitcount 20 \
    -j DROP
```

**Mitigates**:
- Connection flood attacks
- Buggy client creating excessive connections
- Resource exhaustion

**Trade-offs**:
- Legitimate high-frequency clients may be throttled
- Requires tuning based on usage patterns

**Cost**: Minimal (kernel module)

**Complexity**: Medium (iptables recent module)

---

## B. Execution-Level Mediation

These controls regulate **how much** inference can happen.

### B1. Concurrency Limits (Connection-Level)

**Capability**: Cap maximum simultaneous TCP connections

**Implementation**: OpenWrt iptables connlimit module
```bash
# Global limit: max 10 concurrent connections to Ollama
iptables -A FORWARD -i wg0 -o br-dmz -p tcp --dport 11434 \
    -m connlimit --connlimit-above 10 --connlimit-mask 0 \
    -j REJECT --reject-with tcp-reset

# Per-client limit: max 3 concurrent connections per VPN client
iptables -A FORWARD -i wg0 -o br-dmz -p tcp --dport 11434 \
    -m connlimit --connlimit-above 3 --connlimit-mask 32 \
    -j REJECT --reject-with tcp-reset
```

**Mitigates**:
- Silent compute abuse (one client monopolizing server)
- Self-DoS (buggy client spawning unbounded requests)
- Resource exhaustion

**Trade-offs**:
- Limits concurrent connections, not HTTP requests (streaming uses 1 connection)
- May need tuning based on actual usage patterns
- Ollama has internal queuing, this adds network-level gate

**Cost**: Minimal (connection tracking)

**Complexity**: Medium (iptables connlimit module)

### B2. Connection Timeouts (TCP-Level)

**Capability**: Kill idle connections after timeout

**Implementation**: OpenWrt firewall timeout settings
```bash
# TCP connection timeout (default 432000s = 5 days)
sysctl net.netfilter.nf_conntrack_tcp_timeout_established=3600  # 1 hour

# Or via iptables for specific connections
iptables -A FORWARD -i wg0 -o br-dmz -p tcp --dport 11434 \
    -m state --state ESTABLISHED \
    -m conntrack --ctstate ESTABLISHED --ctexpire 3600 \
    -j ACCEPT
```

**Mitigates**:
- Zombie connections (client disconnects without FIN)
- Resource leaks from abandoned connections
- Connection table exhaustion

**Trade-offs**:
- Streaming requests may be long-lived (minutes to hours)
- Need longer timeouts for legitimate use cases
- TCP-level timeout doesn't kill Ollama process (just drops connection)

**Cost**: None (prevents resource waste)

**Complexity**: Low to Medium (sysctl or iptables)

### B3. Model Allowlists (Application-Level)

**Capability**: Restrict which models clients can load

**Status**: ❌ Not available without application-layer proxy

**v2 limitation**: Direct Ollama API exposure means clients can request any model

**Mitigation options**:
- **Option 1**: Pre-pull only desired models (`ollama pull qwen3-coder`), remove others
- **Option 2**: Ollama doesn't support model allowlists natively (as of 0.5.x)
- **Option 3**: Add reverse proxy (nginx/HAProxy) with request body inspection
- **Option 4**: Modify Ollama source code (maintenance burden)

**Trade-off**: v2 trusts authorized VPN clients not to abuse model selection

**Recommendation**: Use operational controls (disk quotas, monitoring) instead of technical enforcement

### B4. Packet-Based Rate Limiting

**Capability**: Cap packets per second from VPN clients

**Implementation**: OpenWrt iptables limit module
```bash
# Limit packets to 100/second from single VPN client
iptables -A FORWARD -i wg0 -o br-dmz -p tcp --dport 11434 \
    -m limit --limit 100/sec --limit-burst 200 \
    -j ACCEPT
iptables -A FORWARD -i wg0 -o br-dmz -p tcp --dport 11434 \
    -j DROP
```

**Mitigates**:
- Packet flood attacks
- High-frequency request patterns
- Network-level resource exhaustion

**Trade-offs**:
- Packet-based limiting is coarse (doesn't distinguish HTTP requests)
- Legitimate streaming may send many packets
- Needs tuning based on workload

**Cost**: Minimal (packet counting)

**Complexity**: Low (iptables limit module)

---

## C. Identity-Aware Mediation

These controls tie actions to VPN client identity.

### C1. WireGuard Peer Identity (Built-In)

**Capability**: Per-peer public key authentication

**Status**: ✅ Already implemented (WireGuard VPN architecture)

**Implementation**: OpenWrt WireGuard peer configuration
```bash
# Each VPN client identified by unique public key
uci add wireguard wg0 peer
uci set wireguard.@peer[-1].PublicKey='CLIENT_PUBLIC_KEY'
uci set wireguard.@peer[-1].AllowedIPs='10.10.10.X/32'
uci set wireguard.@peer[-1].PersistentKeepalive='25'
```

**Provides**:
- Cryptographic identity (private key proof)
- Per-peer IP assignment (10.10.10.X)
- Attribution (firewall logs show source IP = specific peer)
- Revocation (remove peer from config)

**Cost**: None (WireGuard built-in)

**Complexity**: Low (standard WireGuard configuration)

### C2. Per-Peer Firewall Rules

**Capability**: Different access rules for different VPN clients

**Implementation**: OpenWrt iptables rules based on source IP
```bash
# Allow only specific VPN client (10.10.10.5) to access Ollama
iptables -A FORWARD -s 10.10.10.5 -i wg0 -o br-dmz -p tcp --dport 11434 -j ACCEPT

# Different rate limits for different clients
iptables -A FORWARD -s 10.10.10.5 -i wg0 -o br-dmz -p tcp --dport 11434 \
    -m limit --limit 50/sec -j ACCEPT  # Lower limit for this client

# Block specific client
iptables -A FORWARD -s 10.10.10.99 -i wg0 -o br-dmz -p tcp --dport 11434 -j DROP
```

**Provides**:
- Differentiated access (trusted vs untrusted clients)
- Selective revocation (block misbehaving client)
- Priority tiers (higher limits for important clients)

**Trade-offs**:
- Requires maintaining per-client rules
- IP-based (relies on static VPN IP assignments)
- More complex firewall configuration

**Cost**: Minimal (iptables rule matching)

**Complexity**: Medium (per-client rule management)

### C3. mTLS Client Certificates (Additional Layer)

**Capability**: Double authentication (VPN + TLS certificates)

**Implementation**: nginx/HAProxy reverse proxy with client cert validation
```nginx
server {
    listen 192.168.100.10:11434 ssl;
    ssl_client_certificate /etc/nginx/ca.pem;
    ssl_verify_client on;

    location / {
        proxy_pass http://127.0.0.1:11435;  # Ollama on different port
    }
}
```

**Provides**:
- Defense in depth (VPN compromised, TLS still protects)
- Application-level identity (separate from network identity)
- Fine-grained access control (certificate attributes)

**Trade-offs**:
- Very high operational complexity (PKI + cert distribution + renewal)
- Adds reverse proxy layer (moves back toward v1 complexity)
- Certificate management overhead

**Cost**: Low latency (~1-2ms TLS handshake per connection)

**Complexity**: Very High (PKI management, reverse proxy configuration)

**Recommendation**: Only if defense-in-depth is critical (e.g., untrusted network between VPN and server)

---

## D. Observability & Audit

These controls provide visibility without restricting access.

### D1. Firewall Connection Logs

**Capability**: Log all connections to Ollama with VPN client attribution

**Implementation**: OpenWrt firewall logging
```bash
# Log accepted connections to Ollama
iptables -A FORWARD -i wg0 -o br-dmz -p tcp --dport 11434 \
    -j LOG --log-prefix "OLLAMA_ACCESS: " --log-level 6

# Then allow
iptables -A FORWARD -i wg0 -o br-dmz -p tcp --dport 11434 -j ACCEPT
```

**Captures**:
- Source IP (VPN client: 10.10.10.X)
- Destination IP (Ollama: 192.168.100.10)
- Timestamp
- TCP connection establishment

**Provides**:
- Usage attribution (which VPN client accessed Ollama)
- Connection patterns (frequency, timing)
- Security auditing (detect anomalies)

**Trade-offs**:
- Connection-level logging (not HTTP request/response details)
- Log storage (grows over time, requires rotation)
- Performance impact if high traffic

**Cost**: Low (kernel logging)

**Complexity**: Low (iptables LOG target)

**Log location**: `/var/log/kern.log` or OpenWrt `logread`

### D2. Ollama Access Logs (Application-Level)

**Capability**: Log HTTP requests to Ollama API

**Status**: ⚠️ Limited (Ollama logging not configurable as of 0.5.x)

**Current behavior**: Ollama logs to launchd stderr/stdout
- Location: `/tmp/com.ollama.stderr.log` (macOS)
- Content: Model loading, generation errors, API version
- Format: Not structured (plain text)

**Enhancement options**:
- **Option 1**: Reverse proxy (nginx/HAProxy) with access logs
- **Option 2**: Modify Ollama source to add structured logging
- **Option 3**: Network packet capture (tcpdump on DMZ interface)
- **Option 4**: Wait for Ollama to add configurable logging

**Recommendation**: Use firewall connection logs (D1) for attribution, Ollama logs for debugging

### D3. Network Traffic Monitoring

**Capability**: Monitor bandwidth and connection patterns

**Implementation**: OpenWrt traffic monitoring tools
```bash
# Install monitoring packages
opkg update
opkg install iftop bwm-ng tcpdump

# Monitor VPN → DMZ traffic
iftop -i wg0

# Capture packets for analysis
tcpdump -i br-dmz -w /tmp/ollama-traffic.pcap port 11434
```

**Metrics available**:
- Bandwidth usage (MB/s per VPN client)
- Connection counts (active, total)
- Packet rates (packets/sec)
- Protocol distribution (TCP, HTTP)

**Provides**:
- Capacity planning data
- Anomaly detection (unusual traffic spikes)
- Performance troubleshooting

**Trade-offs**:
- Requires router shell access for real-time monitoring
- Storage for packet captures (if enabled)
- Performance impact if capturing all packets

**Cost**: Low (monitoring) to Medium (full packet capture)

**Complexity**: Low (standard tools) to Medium (analysis)

### D4. Alerting via Router

**Capability**: Trigger actions on firewall events

**Implementation**: OpenWrt hotplug scripts
```bash
# /etc/hotplug.d/iptables/99-ollama-alerts
# Trigger on specific log patterns

LOG_PATTERN="OLLAMA_ACCESS"
ALERT_URL="http://monitoring.local/webhook"

tail -f /var/log/kern.log | grep "$LOG_PATTERN" | while read line; do
    # Parse log, check thresholds
    # Send webhook if anomaly detected
    wget -q -O- --post-data "$line" "$ALERT_URL"
done
```

**Alerts on**:
- High connection rate from single client
- Connections from blocked IPs
- Unusual traffic patterns

**Provides**:
- Proactive incident response
- Abuse detection
- Operational awareness

**Trade-offs**:
- Requires external alerting endpoint
- False positives possible
- Script maintenance overhead

**Cost**: Low (script execution)

**Complexity**: Medium to High (scripting, webhook integration)

---

## E. Hard Isolation (If Priorities Shift)

These are architectural changes, not config additions.

### E1. Network-Level Isolation (Already Implemented)

**Status**: ✅ Already part of v2 architecture

**Implementation**: DMZ network segmentation
- DMZ subnet: 192.168.100.0/24
- LAN subnet: 192.168.1.0/24
- VPN subnet: 10.10.10.0/24
- Firewall rules:
  - VPN → DMZ: port 11434 only
  - DMZ → LAN: denied
  - DMZ → Internet: allowed (model downloads)
  - LAN → DMZ: admin access only (optional)

**Provides**:
- Server isolation from LAN (Ollama can't access personal files on LAN devices)
- Limited attack surface (only port 11434 exposed to VPN)
- Containment (compromised DMZ server can't pivot to LAN)

**No additional cost**: Network segmentation is base v2 architecture

### E2. VM/Container Boundary (Additional Layer)

**Capability**: Run Ollama inside VM or container on DMZ server

**Options**:
- **VM**: Ollama inside UTM/Parallels VM on Mac Mini
- **Container**: Ollama inside Docker container
- **Jail**: Similar to FreeBSD jails (not native on macOS)

**Provides**:
- Kernel-level isolation (Ollama can't escape to host)
- Resource limits (CPU, memory, disk quotas)
- Snapshot/restore capability
- Additional layer beyond DMZ network isolation

**Trade-offs**:
- Performance overhead (GPU passthrough complexity)
- Operational complexity (VM/container management)
- Reduced hardware access (Metal GPU may not work in VM)

**Cost**: High (10-30% performance penalty, especially for GPU)

**Complexity**: Very High (requires re-architecture)

**Recommendation**: Only if defense-in-depth critical (e.g., untrusted models)

### E3. Separate User Account

**Capability**: Run Ollama as dedicated low-privilege user

**Implementation**:
```bash
# Create ollama user (no login shell)
sudo dscl . -create /Users/ollama
sudo dscl . -create /Users/ollama UserShell /usr/bin/false
sudo dscl . -create /Users/ollama NFSHomeDirectory /var/ollama

# Run Ollama LaunchAgent as ollama user
# Modify ~/Library/LaunchAgents/com.ollama.plist
```

**Provides**:
- Privilege separation (Ollama process can't access admin's files)
- Audit trail (filesystem actions attributed to ollama user)
- Defense in depth (compromised Ollama contained to ollama user)

**Trade-offs**:
- More complex setup (sudo required, file permissions)
- File permission management overhead
- May break GPU access (Metal requires user session context)
- LaunchAgent pattern designed for user-level services

**Cost**: None (security benefit)

**Complexity**: Medium to High (user management, permissions, GPU access)

**Limitation**: macOS security model ties GPU access to user session (may not work with system user)

---

## Decision Framework

When evaluating future hardening options:

### Questions to Ask

1. **What threat does this mitigate?**
   - Be specific (not just "security")
   - Is the threat realistic for your deployment?

2. **What's the operational cost?**
   - Complexity added (config, maintenance)
   - Performance impact (latency, throughput)
   - Ongoing overhead (token rotation, cert renewal)

3. **Can it be added incrementally?**
   - Does it require re-architecture?
   - Can it be tested in staging first?
   - Can it be rolled back easily?

4. **What's the baseline alternative?**
   - Network isolation (WireGuard VPN + DMZ) already in place
   - Firewall rules (port-level filtering) already in place

5. **Is there a simpler solution?**
   - Tighter OpenWrt firewall rules or per-peer WireGuard configuration
   - Better monitoring (detect vs prevent)
   - Operational procedure (not technical control)

### Prioritization Matrix

| Option | Threat Mitigated | Complexity | Cost | Incremental? |
|--------|------------------|------------|------|--------------|
| Connection logging (D1) | (Visibility only) | Low | Storage | ✅ Yes |
| Connection limits (B1) | Abuse, self-DoS | Medium | None | ✅ Yes |
| Rate limiting (A4, B4) | Abuse | Medium | Low | ✅ Yes |
| Connection timeouts (B2) | Resource leaks | Low | None | ✅ Yes |
| Per-peer rules (C2) | Differentiated access | Medium | Low | ✅ Yes |
| Network monitoring (D3) | (Analysis) | Medium | Storage | ✅ Yes |
| mTLS (C3) | Strong auth | Very High | Low | ⚠️ Partial |
| Model allowlist (B3) | Resource control | High | None | ❌ Requires proxy |
| VM isolation (E2) | Kernel compromise | Very High | High | ❌ No |

---

## Recommended Adoption Order

If you decide to add hardening:

**Phase 1: Zero-Cost Visibility**
1. Enable firewall connection logging (D1)
2. Analyze actual usage patterns (connection frequency, timing)
3. Identify real threats (not theoretical)

**Phase 2: Low-Complexity Controls**
4. Add connection timeouts (B2) - prevents zombie connections
5. Add connection-level rate limiting (A4) - prevents flood attacks
6. Add concurrency limits (B1) - prevents resource exhaustion

**Phase 3: Per-Client Controls (If Needed)**
7. Implement per-peer firewall rules (C2) - differentiated access
8. Enable network monitoring (D3) - bandwidth and connection analysis
9. Set up alerting hooks (D4) - proactive response

**Phase 4: Advanced (Only If Required)**
10. Packet-based rate limiting (B4) - if connection limiting insufficient
11. mTLS client certificates (C3) - if defense-in-depth critical
12. Add reverse proxy for endpoint allowlisting (A1) - if fine-grained control needed

**NOT Recommended Unless...**
- Model allowlisting (B3) - Requires reverse proxy (architectural change)
- VM isolation (E2) - Only for untrusted models/workloads
- Separate user (E3) - May break GPU access on macOS

---

## Implementation Patterns

### Incremental Addition

All options can be added via OpenWrt firewall/iptables changes:

**Method 1: UCI (persistent, recommended)**
```bash
# SSH to router
ssh root@192.168.1.1

# Add firewall rule via UCI
uci add firewall rule
uci set firewall.@rule[-1].name='Connection-Limit'
uci set firewall.@rule[-1].src='vpn'
uci set firewall.@rule[-1].dest='dmz'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='11434'
# ... rule-specific config ...

# Commit and apply
uci commit firewall
/etc/init.d/firewall reload
```

**Method 2: Direct iptables (testing, not persistent)**
```bash
# Add rule temporarily
iptables -A FORWARD -i wg0 -o br-dmz -p tcp --dport 11434 -m connlimit --connlimit-above 10 -j DROP

# View current rules
iptables -L FORWARD -v -n

# Delete rule (by line number)
iptables -D FORWARD 5
```

**Method 3: Custom script (complex rules)**
```bash
# Create /etc/firewall.user for custom iptables rules
# Executes on firewall reload

cat >> /etc/firewall.user <<'EOF'
# Custom Ollama hardening rules
iptables -A FORWARD -i wg0 -o br-dmz -p tcp --dport 11434 \
    -m connlimit --connlimit-above 10 -j DROP
EOF

/etc/init.d/firewall reload
```

### Testing Strategy

Before production:
1. Test rule on router with temporary iptables command
2. Measure impact (connection success rate, latency)
3. Tune thresholds based on real traffic
4. Make persistent via UCI or /etc/firewall.user
5. Monitor logs for false positives
6. Document rollback procedure

### Rollback Safety

**UCI method** - Config versioned, can rollback:
```bash
# Backup before changes
uci export firewall > /tmp/firewall.backup

# If issue, restore
uci import firewall < /tmp/firewall.backup
uci commit firewall
/etc/init.d/firewall reload
```

**iptables method** - Flush and rebuild:
```bash
# Remove problematic rule
iptables -D FORWARD <rule-number>

# Or flush all custom rules
/etc/init.d/firewall reload  # Reloads from UCI config
```

**Persistence**: Only UCI and /etc/firewall.user changes survive reboot. Direct iptables commands are lost on reboot (good for testing).

---

## Summary

This document provides:

> **A catalog of optional controls, not requirements**

Key principles:
- ✅ Base architecture is secure (two-layer defense: Router/VPN/DMZ/Firewall + Ollama)
- ✅ Most options are additive (router firewall rules)
- ✅ Some options require architectural changes (reverse proxy for endpoint filtering)
- ✅ Prioritize based on actual threats (not theory)
- ✅ Measure before optimizing (logs first, controls second)
- ✅ Keep it simple (operational complexity is a cost)

**Start with visibility (connection logs), add controls only when data justifies them.**

The current baseline (WireGuard VPN + DMZ isolation + Port-specific firewall rules) is strong. Don't add hardening prematurely—add it when you have evidence it's needed.

**v2 architecture trade-offs**:
- ✅ Simpler: No application-layer proxy to maintain
- ✅ Lower latency: Direct Ollama access (no HAProxy hop)
- ❌ Coarser control: Network-level only (no endpoint allowlisting without adding proxy)
- ❌ Limited visibility: Connection logs, not HTTP request details (unless adding proxy or packet capture)
