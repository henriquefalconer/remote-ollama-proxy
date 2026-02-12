# Ralph Loop Analytics

Tools for measuring and comparing empirical performance of Ralph loops (PROMPT_plan.md / PROMPT_build.md).

## Quick Start

### Run with Analytics

Use `loop-with-analytics.sh` instead of `loop.sh`:

```bash
# Plan mode with analytics
./loop-with-analytics.sh plan 1 -g "client & server full spec implementation"

# Build mode with analytics
./loop-with-analytics.sh
```

**Everything works exactly like `loop.sh`** — same flags, same behavior, plus analytics.

### What Gets Tracked

For each iteration:
- **Tool usage**: Read, Bash, Edit, Write, Grep, Glob, Task (subagents), TodoWrite
- **Token usage**: Input, cache creation, cache reads, output
- **Cache efficiency**: Hit rate percentage
- **Workload classification**: Shallow vs deep operations

### Output

Analytics are saved to `analytics/run-TIMESTAMP/`:
```
analytics/run-20260210-143022/
├── iteration-1.json          # Raw JSON from Claude Code
├── iteration-1-analysis.txt  # Parsed metrics
├── iteration-2.json
├── iteration-2-analysis.txt
└── summary.md                # Full report with insights
```

**Real-time display**: After each iteration, you'll see:
```
═══════════════════════════════════════════════════════
   Iteration 1 Analytics
═══════════════════════════════════════════════════════
Tool Usage:
  Read: 12 | Bash: 3 | Edit: 2 | Write: 1
  Grep: 5 | Glob: 8 | Subagents: 6 | Todo: 2
  Total tools: 39

Token Usage:
  Input: 15,234 | Cache creation: 34,428 | Cache read: 13,697
  Output: 1,842 | Cache hit rate: 72%

Workload:
  Shallow ops (reads/greps/globs): 25
  Deep ops (edits/writes): 3
  Shallow:Deep ratio = 25:3
═══════════════════════════════════════════════════════
```

### Final Summary

At the end of all iterations:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Final Analytics Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Across 3 iterations:
  Total subagents spawned: 18
  Average per iteration: 6

  Total file reads: 36
  Total edits/writes: 9
  Average reads per iteration: 12

  Total cache creation: 103,284 tokens
  Total cache reads: 41,091 tokens
  Overall cache hit rate: 72%

Full report saved to: analytics/run-20260210-143022/summary.md
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Comparing Runs

### Compare Two Runs

```bash
./compare-analytics.sh analytics/run-20260210-143022 analytics/run-20260210-150015
```

Output:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Analytics Comparison
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Run 1: 20260210-143022 (Anthropic API)
Run 2: 20260210-150015 (Ollama)

Metric                         Run 1           Run 2       Diff
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Iterations                          3               3          0
Total subagents                    18              16         -2
Avg subagents/iter                  6               5         -1
Total reads                        36              34         -2
Avg reads/iter                     12              11         -1
Total edits/writes                  9               9          0
Cache creation tokens         103,284         120,156    16,872
Cache read tokens              41,091               0   -41,091
Cache hit rate (%)                 72               0        -72
Output tokens                   5,526           6,234       708

Key Insights:
  ✓ Both runs used modest parallelism (<50 subagents/iter)
    → Single Ollama server likely sufficient
  ⚠ Run 1 benefited significantly from caching (72%)
    → Ollama (no caching) would be slower
  ✓ Workload is read-heavy (12:3 read:edit ratio)
    → Local models suitable for majority of operations
```

### Typical Comparison Scenarios

**Before/After Optimization:**
```bash
# Before optimization
./loop-with-analytics.sh plan 1 -g "optimize build system"

# After optimization
./loop-with-analytics.sh plan 1 -g "verify build optimizations"

# Compare
./compare-analytics.sh analytics/run-BEFORE analytics/run-AFTER
```

**Anthropic vs Ollama:**
```bash
# Run with Anthropic (current setup)
./loop-with-analytics.sh plan 1 -g "test feature"

# Run with Ollama (after setup)
ANTHROPIC_BASE_URL=http://192.168.100.10:11434 \
./loop-with-analytics.sh plan 1 -g "test feature"

# Compare performance
./compare-analytics.sh analytics/run-TIMESTAMP1 analytics/run-TIMESTAMP2
```

## Use Cases

### 1. Validate Parallelism Assumptions

**Question**: Do Ralph loops really spawn 250-500 subagents?

**Test**:
```bash
./loop-with-analytics.sh plan 1 -g "full spec audit"
```

**Look for**: "Total subagents spawned" in final summary

**Expected**: 5-30 (not 250+)

### 2. Measure Cache Efficiency

**Question**: How much does prompt caching help?

**Test**:
```bash
./loop-with-analytics.sh
```

**Look for**: "Cache hit rate" per iteration

**Expected**: 60-80% after first iteration

### 3. Classify Workload

**Question**: Is the workload read-heavy or edit-heavy?

**Test**:
```bash
./loop-with-analytics.sh
```

**Look for**: "Shallow:Deep ratio" in iteration analytics

**Expected**: 3:1 to 10:1 (read-heavy = suitable for local models)

### 4. Benchmark Ollama Performance

**Setup**:
```bash
# Create claude-ollama alias (see client install.sh)
alias claude-ollama='ANTHROPIC_AUTH_TOKEN=ollama ANTHROPIC_API_KEY="" ANTHROPIC_BASE_URL=http://192.168.100.10:11434 claude --dangerously-skip-permissions'

# Modify loop-with-analytics.sh line 277 to use claude-ollama
```

**Test**:
```bash
# Anthropic baseline
./loop-with-analytics.sh plan 1 -g "test task"

# Ollama test (after modification)
./loop-with-analytics.sh plan 1 -g "test task"

# Compare
./compare-analytics.sh analytics/run-TIMESTAMP1 analytics/run-TIMESTAMP2
```

**Look for**:
- Subagent count difference
- Token usage difference
- Output quality (manual review)

## Key Metrics Explained

### Subagents (Task calls)

- **What it is**: Number of times `Task` tool is called to spawn a subagent
- **Why it matters**: Directly impacts parallelism requirements
- **Ollama impact**: >50 = may need multiple servers; <20 = single server fine

### Cache Hit Rate

- **What it is**: Percentage of tokens served from cache vs processed fresh
- **Why it matters**: Cache misses = slower + more compute
- **Ollama impact**: 0% on Ollama (no caching) = expect 2-3x slower if original rate was >50%

### Shallow:Deep Ratio

- **What it is**: (Reads + Greps + Globs) : (Edits + Writes)
- **Why it matters**: Shallow ops suitable for smaller models
- **Ollama impact**: High ratio (>5:1) = most work can use local models

## Tips

### Get Latest Runs

```bash
ls -lt analytics/ | head -5
```

### Quick Summary of Last Run

```bash
cat analytics/$(ls -t analytics/ | head -1)/summary.md
```

### Watch Live (during execution)

```bash
# In another terminal
tail -f analytics/run-*/iteration-*.json | grep '"name"'
```

### Export for Spreadsheet

```bash
# Extract CSV-friendly data
for run in analytics/run-*/summary.md; do
    echo "Run: $(basename $(dirname $run))"
    grep "Total subagents" $run
    grep "Average subagents" $run
    grep "Cache hit rate" $run
done
```

## FAQ

### Q: Does this slow down execution?

**A**: Negligibly (~1-2 seconds per iteration for JSON parsing). The overhead is from `tee` (capturing output) and `grep` (counting patterns).

### Q: Can I use this with `--no-sandbox`?

**A**: Yes! Works with both sandbox and direct modes.

### Q: What if I want even more detailed metrics?

**A**: The raw JSON logs (`iteration-N.json`) contain everything Claude Code outputs. You can write custom parsers for specific use cases.

### Q: Can I compare more than 2 runs?

**A**: Currently the compare script only supports 2 runs. For multi-run analysis, check the individual `summary.md` files or write a custom aggregator.

## Next Steps

After collecting baseline analytics:

1. **Validate assumptions**: Check if subagent counts match expectations
2. **Identify bottlenecks**: Look for cache-heavy vs compute-heavy patterns
3. **Test Ollama**: Run same tasks with Ollama backend
4. **Make informed decisions**: Use empirical data to choose Anthropic vs Ollama vs Hybrid

---

**See also**:
- `loop.sh` - Original loop script (no analytics)
- `PROMPT_plan.md` - Planning prompt (Opus)
- `PROMPT_build.md` - Build prompt (Sonnet)
- `client/scripts/check-compatibility.sh` - Version compatibility checker
