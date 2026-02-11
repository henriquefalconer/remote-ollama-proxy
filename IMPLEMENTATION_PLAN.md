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
| **Client** | 100% | All 6 scripts, env.template, SETUP.md implemented. 40 tests passing. All bugs fixed. |
| **Root Analytics** | 100% | loop.sh, loop-with-analytics.sh, compare-analytics.sh, ANALYTICS_README.md all match specs. |
| **Server** | ~100% | Ollama API surface works (OpenAI + Anthropic). HAProxy proxy layer implemented with 34 tests passing. |

**Architecture**: Fully spec-compliant
```
Client → Tailscale → HAProxy (100.x.x.x:11434) → Ollama (127.0.0.1:11434)
```

---

## Remaining Tasks

### P4: Hardware Validation

**Effort**: Medium | **Dependencies**: None (all components implemented)

Run full test suites on Apple Silicon server hardware:
- Server tests (`server/scripts/test.sh --verbose`) - should pass all 34 tests
- Client tests (`client/scripts/test.sh --verbose`) - should pass all 40 tests
- Manual Claude Code + Ollama integration validation
- Version management and analytics script validation
- End-to-end workflow testing with real models

---

## Dependency Graph

```
P4 (hardware validation) ─── ready to execute
```

**Suggested order**: P4 (all implementation complete)

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
