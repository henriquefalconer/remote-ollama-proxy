# Claude Code Integration Specification

## Overview

Claude Code is Anthropic's official CLI tool for autonomous coding with Claude models. This specification documents its integration with the remote-ollama infrastructure, including optional Ollama backend support.

## Architecture

### Default Configuration (Recommended)

**Backend**: Anthropic Cloud API
- Full access to Opus 4.6 and Sonnet 4.5
- Prompt caching enabled (critical for Ralph loops)
- Unlimited parallelism via distributed infrastructure
- Highest quality output
- Pay-per-use pricing

**Environment**:
```bash
export ANTHROPIC_API_KEY=sk-ant-...  # Real API key
# No ANTHROPIC_BASE_URL (uses cloud by default)
```

### Optional Ollama Backend

**Backend**: Local Ollama Server
- Privacy (all inference on private network)
- No API costs (hardware costs only)
- Lower quality models (qwen3-coder, glm-4.7, etc.)
- No prompt caching
- Limited parallelism (single server queuing)
- Experimental stability

**Environment**:
```bash
export ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_API_KEY=""
export ANTHROPIC_BASE_URL=http://remote-ollama:11434
```

**Shell Alias** (recommended for easy switching):
```bash
alias claude-ollama='ANTHROPIC_AUTH_TOKEN=ollama ANTHROPIC_API_KEY="" ANTHROPIC_BASE_URL=http://remote-ollama:11434 claude --dangerously-skip-permissions'
```

## Ralph Loop Workflows

### What are Ralph Loops?

**Ralph loops** are autonomous multi-agent workflows using Claude Code with specialized prompts:

- `PROMPT_plan.md` - Planning phase (uses Opus for deep reasoning)
- `PROMPT_build.md` - Build phase (uses Sonnet for execution)

**Key characteristics:**
- Spawn multiple subagents for parallel reconnaissance
- Use prompt caching for efficiency
- Iterate until completion or max iterations
- Support both headless and interactive modes

### Orchestration Scripts

**`loop.sh`** - Standard Ralph loop runner
```bash
# Plan mode (Opus)
./loop.sh plan 1 -g "client & server full spec implementation"

# Build mode (Sonnet)
./loop.sh
```

**`loop-with-analytics.sh`** - Enhanced with performance measurement
```bash
# Same usage as loop.sh, plus analytics
./loop-with-analytics.sh plan 1 -g "goal text"
```

Captures:
- Tool usage counts (Read, Bash, Edit, Write, Grep, Glob, Task spawns)
- Token usage (input, cache creation, cache reads, output)
- Cache efficiency (hit rate)
- Workload classification (shallow vs deep operations)
- Actual subagent spawn counts

### Prompt Rhetoric vs Empirical Reality

**Prompt text says:**
- "up to 250 parallel Sonnet subagents"
- "use up to 500 Sonnet subagents"

**Empirical reality:**
- Typical spawn count: 5-30 subagents per iteration
- Most subagents do shallow work (file reads, greps)
- 1-2 subagents do deep synthesis (planning, editing)
- Parallelism is sparse, not maximal

**Implication**: Single Ollama server can handle typical Ralph loop workloads (if quality acceptable).

## Tool Use Capabilities

### Supported Tools (via Claude Code)

- `Task` - Spawn subagents for parallel work
- `TaskOutput` - Retrieve subagent results
- `Bash` - Execute shell commands
- `Glob` - File pattern matching
- `Grep` - Content search
- `Read` - File reading
- `Edit` - File editing (exact string replacement)
- `Write` - File creation/overwriting
- `NotebookEdit` - Jupyter notebook editing
- `WebFetch` - HTTP content retrieval
- `WebSearch` - Web search
- `TodoWrite` - Task list management
- `AskUserQuestion` - Interactive prompts
- `Skill` - Execute specialized skills
- `EnterPlanMode` / `ExitPlanMode` - Planning workflow control

### Tool Use with Ollama Backend

**What works well:**
- ✅ Read, Grep, Glob (file reconnaissance)
- ✅ Bash (simple commands)
- ✅ Edit, Write (straightforward changes)
- ✅ Task spawning (if count <20)

**What struggles:**
- ⚠️ Complex multi-step tool orchestration
- ⚠️ Tool_choice not supported (cannot force specific tool)
- ⚠️ Quality of tool call generation (model-dependent)
- ⚠️ Error recovery (less sophisticated reasoning)

## Empirical Measurement Requirements

**CRITICAL**: Do not commit to Ollama backend for Ralph loops without empirical validation using two-phase testing.

### Two-Phase Testing Workflow (with Anthropic API)

**Phase 1: Test plan mode with Opus**
```bash
./loop-with-analytics.sh plan 1 -g "client & server full spec implementation"
```

This establishes:
- Opus performance baseline during planning phase
- Actual subagent spawn patterns for reconnaissance
- Cache hit rate across planning iterations
- Tool usage patterns (Read-heavy reconnaissance vs synthesis)
- Token consumption characteristics

**Required: Analyze plan mode results before proceeding**
1. Review `analytics/run-TIMESTAMP/summary.md`
2. Document key metrics:
   - Total subagent spawns (expect 5-15 per iteration)
   - Cache hit rate progression (0% → 70-85%)
   - Tool usage distribution (Read/Grep/Glob dominant)
   - Token consumption (high for Opus)
3. Assess planning quality and iteration count
4. Validate analytics infrastructure working correctly

**Phase 2: Test build mode with Sonnet** (after analyzing plan mode)
```bash
./loop-with-analytics.sh
```
(Defaults to build mode, continues from plan mode results)

This measures:
- Sonnet performance baseline during execution phase
- Build-specific tool usage patterns (more Edit/Write)
- Cache dependency for repeated context
- Iteration count for quality assessment
- Comparison with plan mode resource usage

**Required: Analyze build mode results and compare**
1. Review build mode `analytics/run-TIMESTAMP/summary.md`
2. Document key metrics:
   - Total subagent spawns (expect 8-20 per iteration)
   - Cache hit rate (expect 60-75% after first iteration)
   - Tool usage distribution (more Edit/Write than plan mode)
   - Token consumption (lower than Opus)
3. Compare with plan mode using:
   ```bash
   ./compare-analytics.sh analytics/run-PLAN analytics/run-BUILD
   ```
4. Make data-driven decision about remote Ollama viability

**Check final summaries for**:
- Average subagents per iteration (both modes)
- Cache hit rate comparison (both cache-heavy)
- Shallow:deep operation ratio (plan = reads, build = edits)
- Total iterations required (plan + build)
- Token usage patterns (Opus vs Sonnet)

### Ollama Testing (optional)

1. Modify `loop-with-analytics.sh` to use `claude-ollama` alias
2. Run same task: `./loop-with-analytics.sh plan 1 -g "same task"`
3. Compare using `./compare-analytics.sh`

### Decision Criteria

| Metric | Threshold | Implication |
|--------|-----------|-------------|
| Avg subagents/iter | <20 | Single Ollama server sufficient |
| Avg subagents/iter | >50 | Need multiple servers or stick with cloud |
| Cache hit rate | >60% | Expect 2-3x slower on Ollama |
| Shallow:deep ratio | >5:1 | Most work suitable for local models |
| Model quality | Manual | Compare plan quality, code quality, iteration count |

## Use Case Classification

### ✅ Good for Ollama Backend

- Interactive single-session coding
- Quick file edits and refactoring
- Simple file reconnaissance (reads, searches)
- Privacy-critical work
- Offline development

### ❌ Not Recommended for Ollama Backend

- **Ralph loops in plan mode with Opus** (quality critical, cache-dependent)
- **Complex multi-step planning** (requires Opus-level reasoning)
- High-parallelism workflows (>20 concurrent)
- Cache-heavy workloads (repeated context)
- Production autonomous agents (stability risk)

### 🤔 Requires Testing (Use Analytics to Decide)

- **Ralph loops in build mode with Sonnet** (may work for simple builds after Opus planning)
- Medium parallelism (10-20 subagents)
- Mixed shallow/deep workloads
- Non-critical automation

**Test with analytics first**: Run baseline with Anthropic cloud, then test same workload with Ollama, compare using `compare-analytics.sh`.

## Installation Integration

### Standard Installation (Aider only)

```bash
./client/scripts/install.sh
```

Installs:
- Tailscale
- Python 3.10+
- pipx
- Aider
- Environment configuration for Ollama OpenAI API

### Extended Installation (with Claude Code option)

```bash
./client/scripts/install.sh
```

After Aider installation, prompt user:
```
───────────────────────────────────────
Optional: Claude Code + Ollama Integration
───────────────────────────────────────

You can use Claude Code with your local Ollama server.

Benefits:
  • Privacy: All inference stays on your network
  • Cost: No API charges
  • Speed: Low latency to local server

Limitations:
  • Model quality lower than real Claude
  • No prompt caching (slower on repeated contexts)
  • Best for: Simple tasks, file reads, quick edits

Create 'claude-ollama' shell alias? (y/N)
```

If yes, append to shell profile:
```bash
# >>> claude-ollama >>>
# Claude Code with local Ollama backend
alias claude-ollama='ANTHROPIC_AUTH_TOKEN=ollama ANTHROPIC_API_KEY="" ANTHROPIC_BASE_URL=http://remote-ollama:11434 claude --dangerously-skip-permissions'
# <<< claude-ollama <<<
```

## Version Compatibility

### Challenge

- Claude Code updates frequently
- Ollama's Anthropic compatibility is new
- API changes may break compatibility
- Risk: 15-30% chance of breaking change in 12 months

### Solution

**Version Management Scripts** (see `VERSION_MANAGEMENT.md`):
- `check-compatibility.sh` - Verify versions are tested together
- `pin-versions.sh` - Pin to known-working versions
- `downgrade-claude.sh` - Downgrade if update breaks

### Recommended Practice

1. **Pin versions in production**
2. **Test updates in staging first**
3. **Maintain fallback to Anthropic cloud API**
4. **Monitor GitHub repos for breaking changes**

## Performance Characteristics

### Anthropic Cloud API (Baseline)

**Plan mode with Opus (1-2 iterations, deep reasoning):**
- Wall time: 3-8 minutes per iteration
- Subagent spawns: 5-15 per iteration (reconnaissance)
- Cache hit rate: 0% first iteration, 70-85% subsequent
- Tool calls: 40-80 per iteration
- Token usage: High (Opus verbose, detailed planning)
- Quality: Excellent (deep reasoning, comprehensive plans)

**Build mode with Sonnet (3-5 iterations, execution):**
- Wall time: 2-5 minutes per iteration
- Subagent spawns: 8-20 per iteration (parallel execution)
- Cache hit rate: 0% first iteration, 60-75% subsequent
- Tool calls: 60-120 per iteration
- Token usage: Moderate (Sonnet concise, action-oriented)
- Quality: Excellent (reliable execution, follows plan)

### Ollama Backend (Estimated - Build Mode Only)

**Important**: Ollama backend **not recommended** for plan mode (Opus). Only consider for build mode (Sonnet) after establishing baseline with cloud API.

**Build mode with Sonnet-equivalent local model (e.g., qwen3-coder):**
- Wall time: 5-12 minutes per iteration (2-3x slower, no caching)
- Subagent spawns: 8-20 per iteration (same logical work)
- Cache hit rate: 0% (not supported)
- Tool calls: 60-120 (similar patterns)
- Quality: Good to Fair (depends on model and task complexity)
  - qwen3-coder: Best local option for coding
  - glm-4.7:cloud: Good for general tasks
  - May require more iterations to reach same outcome

**Degradation factors:**
- No prompt caching: +50-100% latency per iteration
- Lower model quality: +20-50% iteration count (more iterations needed)
- Serial processing: +0-50% if high parallelism
- Combined: ~2-3x total time, variable quality

**Plan mode with Opus-equivalent (NOT RECOMMENDED):**
- No local model matches Opus reasoning quality
- Critical planning phase requires best model
- Cache-dependent (70-85% hit rate with cloud)
- Recommendation: **Always use Anthropic cloud for plan mode**

## Security Considerations

### Cloud API (Default)

- Data transmitted to Anthropic servers
- Subject to Anthropic's data policies
- Secure TLS connections
- API key authentication

### Ollama Backend

- All data stays on private Tailscale network
- Zero external transmission
- Tailscale ACL-based security
- No built-in authentication (network-level only)

### Best Practice

- Use cloud API for non-sensitive code
- Use Ollama backend for proprietary/sensitive work
- Never commit API keys to repositories
- Rotate API keys periodically

## Maintenance and Support

### Official Support

- **Claude Code**: Anthropic (official)
- **Ollama Anthropic API**: Ollama community (experimental)
- **Integration scripts**: This project (custom)

### Support Channels

- Claude Code issues: https://github.com/anthropics/claude-code/issues
- Ollama issues: https://github.com/ollama/ollama/issues
- Integration issues: This project's issue tracker

### Breaking Change Protocol

1. **Detection**: Version compatibility check fails
2. **Response**: Downgrade to pinned version
3. **Investigation**: Test new version in staging
4. **Update**: Add to compatibility matrix if working
5. **Document**: Update IMPLEMENTATION_PLAN.md with findings

## Future Enhancements

### Potential Improvements

1. **Hybrid orchestration**: Opus (cloud) for planning, Sonnet (local) for execution
2. **Load balancing**: Multiple Ollama servers for parallelism
3. **Prompt caching simulation**: Local cache layer (complex)
4. **Model quality improvements**: Newer open models (ongoing)
5. **Anthropic API stability**: Versioned endpoints, compatibility guarantees

### Out of Scope

- Building custom model serving infrastructure
- Replacing Ollama with custom inference server
- Implementing Anthropic API from scratch
- Creating web UI for Claude Code
- Multi-language client support (macOS only in v1)

## Summary

Claude Code integration provides:
- **Default**: High-quality autonomous coding with Anthropic cloud API
- **Optional**: Privacy-preserving remote Ollama backend for simple tasks
- **Analytics**: Empirical measurement before committing to remote backend
- **Stability**: Version pinning and compatibility checking

**Recommendations**:
1. **Plan mode (Opus)**: Always use Anthropic cloud API (quality critical, cache-dependent)
2. **Build mode (Sonnet)**: Consider remote Ollama only after empirical validation via two-phase analytics testing
3. **Testing workflow**:
   - Phase 1: Run `./loop-with-analytics.sh plan 1 -g "client & server full spec implementation"` (Opus)
   - Analyze plan mode results thoroughly
   - Phase 2: Run `./loop-with-analytics.sh` (Sonnet)
   - Analyze build mode results and compare with plan mode
4. **Interactive sessions**: Remote Ollama suitable for simple file edits and quick tasks
