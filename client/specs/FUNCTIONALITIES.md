# self-sovereign-ollama ai-client Functionalities (v2.0.0)

## Core Functionality

- One-time installer that makes remote Ollama immediately usable by OpenAI-compatible tools
- Installs and configures WireGuard VPN client
- Generates WireGuard keypair (client keeps private key, sends public key to admin)
- Sets all required environment variables pointing to remote Ollama server (see API_CONTRACT.md)
- Modifies shell profile (`~/.zshrc` or `~/.bashrc`) to source environment file automatically (with user consent)
- Installs Aider and ensures it connects to remote Ollama automatically
- Uninstaller that removes only client-side changes
- Comprehensive test script for automated validation of all client functionality

## Extended Functionality

### Optional Ollama Backend Integration

- Optionally configure Claude Code to use local Ollama server instead of Anthropic cloud API
- Create `claude-ollama` shell alias for easy backend switching
- Provide clear documentation of capabilities and limitations vs cloud API
- User consent required before creating alias (opt-in)

### Analytics Infrastructure

- **Empirical measurement tools** for validating Ralph loop performance in **both plan mode (Opus) and build mode (Sonnet)**
- `loop-with-analytics.sh` - Enhanced loop script that captures and analyzes:
  - Tool usage per iteration (Read, Bash, Edit, Write, Grep, Glob, Task spawns, etc.)
  - Token usage (input, cache creation, cache reads, output)
  - Cache efficiency (hit rate percentage)
  - Workload classification (shallow vs deep operations)
  - Actual subagent spawn counts vs theoretical maximums
  - Differences between Opus (planning) and Sonnet (execution) resource usage
- `compare-analytics.sh` - Compare performance between two runs (e.g., cloud vs Ollama, plan vs build)
- Structured output saved to `analytics/run-TIMESTAMP/` with:
  - Raw JSON logs per iteration
  - Parsed analysis files
  - Aggregate summary with insights
- **Purpose**: Make informed decisions about remote Ollama feasibility based on empirical data, not prompt rhetoric
- **First test**: Measure plan mode with Opus (`./loop-with-analytics.sh plan 1 -g "..."`) to establish baseline and validate infrastructure

### Version Compatibility Management

- `check-compatibility.sh` - Verify Claude Code and Ollama versions are tested together
- `pin-versions.sh` - Pin both tools to known-working versions
- `downgrade-claude.sh` - Downgrade Claude Code to last working version if update breaks
- **Purpose**: Prevent breaking changes from tool updates; maintain stable production environment

## After Installation

### With Aider

- **Connect to VPN**: Establish WireGuard connection
- User can run `aider` or `aider --yes` and it will connect to remote Ollama
- Any other tool that honors `OPENAI_API_BASE` + `OPENAI_API_KEY` will work without extra flags

### With Claude Code

- **Connect to VPN**: Establish WireGuard connection (required for Ollama backend)
- **Default behavior**: Claude Code uses Anthropic cloud API (high quality, full features, no VPN needed)
- **Optional Ollama backend**: Run `claude-ollama --model qwen3-coder` to use local server (requires VPN)
- **Ralph loops**: Run `./loop.sh` (cloud) or `./loop-with-analytics.sh` (cloud + analytics)
- **Analytics**: Use `loop-with-analytics.sh` to measure actual performance characteristics

### Runtime Characteristics

- **No persistent daemon or service** – the client is WireGuard VPN + environment configuration
- VPN connection required to reach server
- Backend selection via environment variables or shell alias
- VPN can be connected/disconnected as needed

## Client Responsibilities

### Core

- Guarantee that after `./scripts/install.sh`, the environment matches API_CONTRACT.md exactly
- Verify connectivity to remote Ollama server (optional test curl in installer)
- Provide clear error messages if WireGuard VPN is not connected or configured

### Extended

- Provide accurate documentation of Ollama backend limitations for Claude Code
- Enable empirical measurement before committing to Ollama backend
- Maintain version compatibility between client tools and server
- Guide users toward appropriate backend choice (cloud vs local) based on use case

## Use Case Guidance

### When to Use Remote Ollama Backend (Claude Code)

✅ **Good for:**
- Interactive single-session coding (no parallelism)
- Quick file edits and refactoring
- Privacy-critical work (stays on private WireGuard VPN network)
- Simple reconnaissance tasks (file reads, greps)
- Build mode (Sonnet) for simple tasks only (after testing)

❌ **Never use for:**
- **Plan mode (Opus)** - Quality critical, requires Anthropic cloud
- Complex planning tasks (model quality gap vs Opus)

❌ **Not recommended for:**
- Ralph loops with high parallelism (>20 subagents)
- Cache-heavy workloads (no prompt caching on Ollama)
- Production autonomous workflows (stability risk)

### When to Use Anthropic Cloud API (Claude Code)

✅ **Always use for:**
- **Plan mode (PROMPT_plan.md with Opus)** - Planning quality critical, cache-dependent
- Complex architectural planning and deep reasoning
- Production autonomous agents
- Cache-heavy workloads (>60% hit rate)

✅ **Recommended for:**
- Build mode (PROMPT_build.md with Sonnet) - Higher quality, faster with caching
- High-parallelism scenarios (>20 concurrent subagents)
- Tasks requiring prompt caching

### Empirical Validation Workflow

**Phase 1: Test plan mode with Opus**
1. Run `./loop-with-analytics.sh plan 1 -g "client & server full spec implementation"` with Anthropic cloud
2. Establishes baseline for planning phase (reconnaissance, deep analysis)
3. Validates analytics infrastructure captures realistic workloads
4. Measures cache dependency (expect 70-85% hit rate after first iteration)

**After Phase 1: Analyze plan mode results**
1. Review `analytics/run-TIMESTAMP/summary.md`
2. Check actual subagent count (expect 5-15 per iteration)
3. Check cache hit rate progression (0% → 70-85%)
4. Check tool usage patterns (Read/Grep/Glob dominant)
5. Document token usage (high for Opus)
6. Assess planning quality and completeness

**Phase 2: Test build mode with Sonnet**
1. Run `./loop-with-analytics.sh` (defaults to build mode, continues from plan)
2. Establishes baseline for execution phase (parallel implementation)
3. Measures build-specific resource usage patterns
4. Tests cache dependency during execution (expect 60-75% hit rate after first iteration)

**After Phase 2: Analyze build mode results and compare**
1. Review build mode `analytics/run-TIMESTAMP/summary.md`
2. Check subagent count (expect 8-20 per iteration)
3. Check cache hit rate (if >60%, remote Ollama will be significantly slower)
4. Compare tool patterns vs plan mode (more Edit/Write)
5. Compare token usage vs Opus (should be lower)
6. Use `./compare-analytics.sh` to compare plan vs build runs
7. Assess quality metrics (test pass rate, iteration count)

**Final Decision**
1. **Plan mode (Opus)**: Always use Anthropic cloud (quality critical, cache-dependent)
2. **Build mode (Sonnet)**: Consider remote Ollama only for simple builds if metrics favorable
3. Base decision on empirical data from both phases, not assumptions or prompt rhetoric
