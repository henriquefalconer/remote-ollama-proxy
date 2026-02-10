<!--
 Copyright (c) 2026 Henrique Falconer. All rights reserved.
 SPDX-License-Identifier: Proprietary
-->

# Implementation Plan

**Last Updated**: 2026-02-10
**Current Version**: v0.0.4

v1 (Aider/OpenAI API) is complete and tested on hardware. v2+ (Claude Code/Anthropic API, version management, analytics) has documentation foundations done; core implementation remains.

---

## Current Status

### v1 Implementation - COMPLETE

All 8 scripts delivered (server: 4, client: 3 + env.template). 48 tests passing (20 server, 28 client). Full spec compliance verified. Critical `OLLAMA_API_BASE` bug fixed in v0.0.4 (see "Lessons Learned" below).

### v2+ Implementation - IN PROGRESS

Phase 1 (documentation foundations) complete: 7/22 items done. Specs updated for Anthropic API, env.template extended, README/SCRIPTS/SETUP docs prepared. **15 items remain** across 3 phases of implementation.

---

## Remaining Tasks

### Phase 2: Core Implementation (6 items, parallelizable)

| ID | Task | Priority | Effort | Target Files | Dependencies |
|----|------|----------|--------|-------------|-------------|
| H1-3 | Add Anthropic `/v1/messages` tests to server test.sh (4-6 tests: non-streaming, streaming SSE, system prompts, error handling). Bump `TOTAL_TESTS` from 20 to ~25-26. Add `--skip-anthropic-tests` flag. | H1 | Medium | `server/scripts/test.sh` | None (H1-2 spec done) |
| H4-4 | Fix `show_progress()` never called in server test.sh. Add calls before each test; `CURRENT_TEST` currently stuck at 0. | H4 | Small | `server/scripts/test.sh` | None |
| H1-4 | Add optional Claude Code setup to client install.sh. Prompt user, create `claude-ollama` shell alias with marker comments for clean removal. | H1 | Medium | `client/scripts/install.sh` | None (H1-5 env done) |
| H1-6 | Sync embedded env template in install.sh (lines 311-319) with canonical `env.template` -- add missing Anthropic variable comments (lines 9-12 of template). | H1 | Trivial | `client/scripts/install.sh` | None |
| H2-1 | Create `check-compatibility.sh`. Detect Claude Code + Ollama versions, check compatibility matrix, report status with exit codes 0/1/2/3. | H2 | Medium | New: `client/scripts/check-compatibility.sh` | None |
| H2-2 | Create `pin-versions.sh`. Detect versions, pin via npm/brew, create `~/.ai-client/.version-lock`. | H2 | Medium | New: `client/scripts/pin-versions.sh` | None |

**Bundling**: H1-3 + H4-4 (same file). H1-4 + H1-6 (same file).

**Specs**: H2-1 -> `client/specs/VERSION_MANAGEMENT.md` lines 66-131. H2-2 -> same spec lines 133-178.

### Phase 3: Dependent Implementation (3 items, sequential)

| ID | Task | Priority | Effort | Target Files | Dependencies |
|----|------|----------|--------|-------------|-------------|
| H2-3 | Create `downgrade-claude.sh`. Read `.version-lock`, downgrade Claude Code to recorded version via npm/brew. | H2 | Small-Med | New: `client/scripts/downgrade-claude.sh` | H2-2 (lock file format) |
| H2-4 | Add v2+ cleanup to client uninstall.sh. Remove `claude-ollama` alias markers from shell profile. | H2 | Small | `client/scripts/uninstall.sh` | H1-4 (must know marker format) |
| H2-5 | Add v2+ tests to client test.sh (8-10 tests: Claude Code binary, alias, `/v1/messages` connectivity, version scripts, `.version-lock` format). Add `--skip-claude`, `--v1-only`, `--v2-only` flags. | H2 | Medium | `client/scripts/test.sh` | H1-3, H1-4, H2-1, H2-2, H2-3 |

**Spec**: H2-3 -> `client/specs/VERSION_MANAGEMENT.md` lines 180-226.

### Phase 4: Validation and Polish (6 items)

| ID | Task | Priority | Effort | Target Files | Dependencies |
|----|------|----------|--------|-------------|-------------|
| H3-1 | Fix analytics bugs: (a) `compare-analytics.sh` lines 88-91 divide-by-zero -- no zero check on `ITER1`/`ITER2` before division; (b) `loop-with-analytics.sh` line 268 cache hit rate formula uses `total_input` denominator, spec requires `cache_creation + cache_read`. | H3 | Medium | `compare-analytics.sh`, `loop-with-analytics.sh` | None |
| H3-6 | Implement decision matrix output per `client/specs/ANALYTICS.md` lines 474-485. Neither analytics script outputs this. | H3 | Medium | `loop-with-analytics.sh`, `compare-analytics.sh` | None |
| H3-2 | Hardware testing: run all tests with `--verbose` on Apple Silicon server, manual Claude Code + Ollama validation, version management script testing. | H3 | Large | Manual | All H1 + H2 items |
| H3-3 | Update `server/README.md`: new test count, Anthropic test sample output, `--skip-anthropic-tests` flag docs. | H3 | Trivial | `server/README.md` | H1-3, H3-2 |
| H3-5 | Update `client/SETUP.md`: Claude Code integration section, version management quick-start, analytics overview. | H3 | Small | `client/SETUP.md` | H1-4, H2-1, H2-2, H2-3 |
| H4-3 | Auto-resolved when H2-1 is created (stale reference in `ANALYTICS_README.md`). | H4 | None | N/A | H2-1 |

**Bundling**: H3-1 + H3-6 (same files, related analytics work).

---

## Dependency Graph

```
Phase 2 (parallelizable):
  H1-3 + H4-4 ─── no blockers
  H1-4 + H1-6 ─── no blockers
  H2-1 ─────────── no blockers
  H2-2 ─────────── no blockers

Phase 3 (sequential):
  H2-3 ─────────── depends on H2-2
  H2-4 ─────────── depends on H1-4
  H2-5 ─────────── depends on H1-3, H1-4, H2-1, H2-2, H2-3

Phase 4 (polish):
  H3-1 + H3-6 ─── no blockers (can start anytime)
  H3-2 ─────────── depends on ALL Phase 2 + Phase 3
  H3-3 ─────────── depends on H1-3, H3-2
  H3-5 ─────────── depends on H1-4, H2-1, H2-2, H2-3
  H4-3 ─────────── auto-resolved by H2-1
```

## Recommended Execution Order

**Batch 1** (parallel, no blockers):
1. H1-3 + H4-4 -- Server Anthropic tests + progress fix
2. H1-4 + H1-6 -- Client Claude Code install + template sync
3. H2-1 -- check-compatibility.sh
4. H2-2 -- pin-versions.sh
5. H3-1 + H3-6 -- Analytics bug fixes + decision matrix

**Batch 2** (after Batch 1):
6. H2-3 -- downgrade-claude.sh (needs H2-2)
7. H2-4 -- Uninstall v2+ cleanup (needs H1-4)

**Batch 3** (after Batch 2):
8. H2-5 -- Client v2+ tests (needs all scripts to exist)

**Batch 4** (after Batch 3):
9. H3-2 -- Hardware testing
10. H3-3 -- Server README update
11. H3-5 -- Client SETUP update

---

## Effort Summary

| Category | Items | Effort |
|----------|-------|--------|
| Server test.sh (Anthropic tests + progress fix) | H1-3, H4-4 | Medium |
| Client install.sh (Claude Code + template sync) | H1-4, H1-6 | Medium |
| Version management (3 new scripts) | H2-1, H2-2, H2-3 | Medium-Large |
| Client uninstall.sh (v2+ cleanup) | H2-4 | Small |
| Client test.sh (v2+ tests) | H2-5 | Medium |
| Analytics fixes + decision matrix | H3-1, H3-6 | Medium |
| Hardware testing | H3-2 | Large |
| Documentation updates | H3-3, H3-5 | Small |

**New files**: 3 (`check-compatibility.sh`, `pin-versions.sh`, `downgrade-claude.sh`)
**Modified files**: ~8 existing files
**Estimated total**: 5-7 focused development days + hardware testing session

---

## Implementation Constraints

1. **Security**: Tailscale-only network. No public exposure. No built-in auth.
2. **API contract**: `client/specs/API_CONTRACT.md` is the single source of truth for server-client interface.
3. **Idempotency**: All scripts must be safe to re-run without side effects.
4. **No stubs**: Implement completely or not at all. No TODO/FIXME/HACK in production code.
5. **Claude Code integration is optional**: Always prompt for user consent. Anthropic cloud is default; Ollama is an alternative.
6. **curl-pipe install**: Client `install.sh` must work when executed via `curl | bash`.

---

## Lessons Learned (v0.0.4)

All 48 automated tests passed, but first real Aider usage failed. Root cause: `OLLAMA_API_BASE` included `/v1` suffix, breaking Ollama native endpoints (`/api/*`). Fix: separate `OLLAMA_API_BASE` (no suffix) from `OPENAI_API_BASE` (with `/v1`). Lesson: end-to-end integration tests with actual tools are mandatory.

---

## Spec Baseline

All work must comply with:
- `server/specs/*.md` (8 files including ANTHROPIC_COMPATIBILITY)
- `client/specs/*.md` (9 files including ANALYTICS, CLAUDE_CODE, VERSION_MANAGEMENT)

Specs are authoritative. Implementation deviations must be corrected unless there is a compelling reason to update the spec.
