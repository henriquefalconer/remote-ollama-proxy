#!/bin/bash
set -euo pipefail   # Exit on error, undefined vars, and pipe failures

# Usage: ./loop-with-analytics.sh [plan] [max_iterations] [--goal <text> | -g <text> | ...]
# Examples:
#   ./loop-with-analytics.sh plan --goal "repo with full spec implementation"
#   ./loop-with-analytics.sh plan 8 -g "repo with full spec implementation"
#   ./loop-with-analytics.sh --goal "repo with full spec implementation" 10
#   ./loop-with-analytics.sh plan                                      # ← will ask you interactively

# Color and style definitions
GREEN_BOLD="\033[1;38;2;40;254;20m"    # #28FE14 + bold
YELLOW_BOLD="\033[1;33m"
RED_BOLD="\033[1;31m"
BLUE_BOLD="\033[1;34m"
CYAN_BOLD="\033[1;36m"
RESET="\033[0m"

# ────────────────────────────────────────────────
# Parse flags & positional arguments
# ────────────────────────────────────────────────

USE_SANDBOX=true
GOAL_TEXT=""
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-sandbox)
            USE_SANDBOX=false
            shift
            ;;
        --goal|--project-goal|-g|--project_specific_goal)
            shift
            [[ $# -eq 0 ]] && { echo -e "${RED_BOLD}Error: --goal requires a value${RESET}"; exit 1; }
            GOAL_TEXT="$1"
            shift
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL[@]:-}"   # restore positional parameters

# ────────────────────────────────────────────────
# Mode, iterations, prompt file
# ────────────────────────────────────────────────

if [ "${1:-}" = "plan" ]; then
    MODE="plan"
    PROMPT_FILE="PROMPT_plan.md"
    shift
    MAX_ITERATIONS="${1:-0}"
    [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]] && shift || MAX_ITERATIONS=0
elif [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    MODE="build"
    PROMPT_FILE="PROMPT_build.md"
    MAX_ITERATIONS="$1"
    shift
else
    MODE="build"
    PROMPT_FILE="PROMPT_build.md"
    MAX_ITERATIONS=0
fi

# Last positional argument can be the goal (legacy style)
if [ -z "$GOAL_TEXT" ] && [ $# -ge 1 ]; then
    GOAL_TEXT="$1"
    shift
fi

# Project-specific goal (only interactive in plan mode if missing)
if [ "$MODE" = "plan" ] && [ -z "$GOAL_TEXT" ]; then
    # ──────────────────────────────
    # Very basic raw-mode editor hack for bash 3.2
    # ──────────────────────────────

    GOAL_TEXT=""           # starting suggestion
    cursor_pos=${#GOAL_TEXT} # where cursor is (end by default)

    # Save terminal state
    old_stty=$(stty -g 2>/dev/null)

    # Enter raw mode (char-by-char, no echo)
    stty -icanon -echo min 1 time 0 2>/dev/null

    # Hide real cursor
    printf '\033[?25l'

    trap '
        stty "$old_stty" 2>/dev/null
        printf "\033[?25h"          # show cursor again
        exit 1
    ' INT TERM EXIT

    while true; do
        # Clear + redraw whole editor view
        clear 2>/dev/null || printf '\033[H\033[2J'

        printf "${GREEN_BOLD}Type your goal - Enter to select project-specific goal for the agent to cycle planning${RESET}\n\n"

        # Move cursor back visually (crude)
        printf "\rAs our next objective, we want to achieve ${GREEN_BOLD}%s_${RESET}" "${GOAL_TEXT:0:$cursor_pos}"
        if [ $cursor_pos -lt ${#GOAL_TEXT} ]; then
            printf "${YELLOW_BOLD}%s_${RESET}" "${GOAL_TEXT:cursor_pos:1}"
        fi

        printf "\n\n${YELLOW_BOLD}Examples:${RESET}\n"
        printf "  • client & server full spec implementation\n"
        printf "  • a detailed analytics system based on specs/analytics.md\n"
        printf "  • a great working ui and ux\n"
        printf "  • an AI-powered data import system based on specs/data-import.md\n\n"
        # Read one character
        IFS= read -r -n 1 -d '' c 2>/dev/null

        case "$c" in
            # Enter → finish
            "" | $'\n')
                break
                ;;

            # Backspace / Ctrl+H
            $'\177' | $'\b')
                if [ $cursor_pos -gt 0 ]; then
                    GOAL_TEXT="${GOAL_TEXT:0:$((cursor_pos-1))}${GOAL_TEXT:$cursor_pos}"
                    cursor_pos=$((cursor_pos-1))
                fi
                ;;

            # Ctrl+C → abort (handled by trap)
            $'\003')
                # trap will run
                break
                ;;

            # Printable chars
            [[:print:]])
                # Insert at cursor position (very basic — only append + end cursor supported)
                GOAL_TEXT="${GOAL_TEXT:0:$cursor_pos}${c}${GOAL_TEXT:$cursor_pos}"
                cursor_pos=$((cursor_pos+1))
                ;;

            # Ignore control chars, arrows, etc.
            *)
                ;;
        esac
    done

    # Restore terminal + show cursor
    stty "$old_stty" 2>/dev/null
    printf '\033[?25h'
    trap - INT TERM EXIT

    # Final trim
    GOAL_TEXT=$(echo "$GOAL_TEXT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    if [ -z "$GOAL_TEXT" ]; then
        echo -e "\nEmpty goal → exiting."
        exit 1
    fi

    # Confirmation screen
    clear 2>/dev/null || printf '\033[H\033[2J'
    echo -e "${GREEN_BOLD}Confirm goal${RESET}"
    echo -e "────────────────────────────────────────────────────────────────────"
    echo -e "As our next objective, we want to achieve ${GREEN_BOLD}${GOAL_TEXT}${RESET}."
    echo -e "────────────────────────────────────────────────────────────────────\n"
    echo -en "${GREEN_BOLD}Good? [Y/n] ${RESET}"
    read -n 1 -r confirm 2>/dev/null
    echo

    if [[ -n "$confirm" && ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "Cancelled."
        exit 1
    fi
fi

# Prepare final prompt
if [ ! -f "$PROMPT_FILE" ]; then
    echo -e "${RED_BOLD}Error: $PROMPT_FILE not found${RESET}"
    exit 1
fi

PROMPT_CONTENT=$(cat "$PROMPT_FILE")

if [ -n "$GOAL_TEXT" ]; then
    # Simple literal replacement – safe and exact
    FINAL_PROMPT="${PROMPT_CONTENT//\[project-specific goal\]/$GOAL_TEXT}"
else
    FINAL_PROMPT="$PROMPT_CONTENT"
fi

# Select model
if [ "$MODE" = "build" ]; then
    MODEL="sonnet"   # for speed
else
    MODEL="opus"     # complex reasoning & planning
fi

# ────────────────────────────────────────────────
# Analytics setup
# ────────────────────────────────────────────────

RUN_ID=$(date +%Y%m%d-%H%M%S)
ANALYTICS_DIR="analytics/run-${RUN_ID}"
mkdir -p "$ANALYTICS_DIR"

# Create analytics summary file
SUMMARY_FILE="${ANALYTICS_DIR}/summary.md"
cat > "$SUMMARY_FILE" << EOF
# Ralph Loop Analytics - Run ${RUN_ID}

**Mode**: $MODE
**Model**: $MODEL
**Prompt**: $PROMPT_FILE
**Goal**: ${GOAL_TEXT:-N/A}
**Started**: $(date '+%Y-%m-%d %H:%M:%S')

---

EOF

# Analytics parser function
analyze_iteration() {
    local iter_num=$1
    local json_log=$2
    local output_file="${ANALYTICS_DIR}/iteration-${iter_num}-analysis.txt"

    echo -e "${CYAN_BOLD}Analyzing iteration ${iter_num}...${RESET}"

    # Count tool uses (sanitize output to ensure single numeric value)
    local tool_read=$(grep -c '"name":"Read"' "$json_log" 2>/dev/null | head -1 || echo "0")
    tool_read=${tool_read:-0}
    local tool_bash=$(grep -c '"name":"Bash"' "$json_log" 2>/dev/null | head -1 || echo "0")
    tool_bash=${tool_bash:-0}
    local tool_edit=$(grep -c '"name":"Edit"' "$json_log" 2>/dev/null | head -1 || echo "0")
    tool_edit=${tool_edit:-0}
    local tool_write=$(grep -c '"name":"Write"' "$json_log" 2>/dev/null | head -1 || echo "0")
    tool_write=${tool_write:-0}
    local tool_grep=$(grep -c '"name":"Grep"' "$json_log" 2>/dev/null | head -1 || echo "0")
    tool_grep=${tool_grep:-0}
    local tool_glob=$(grep -c '"name":"Glob"' "$json_log" 2>/dev/null | head -1 || echo "0")
    tool_glob=${tool_glob:-0}
    local tool_task=$(grep -c '"name":"Task"' "$json_log" 2>/dev/null | head -1 || echo "0")
    tool_task=${tool_task:-0}
    local tool_todo=$(grep -c '"name":"TodoWrite"' "$json_log" 2>/dev/null | head -1 || echo "0")
    tool_todo=${tool_todo:-0}

    local total_tools=$((tool_read + tool_bash + tool_edit + tool_write + tool_grep + tool_glob + tool_task + tool_todo))

    # Extract token usage (sum all usage blocks, ensure numeric output)
    local input_tokens=$(grep -o '"input_tokens":[0-9]*' "$json_log" 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}' || echo "0")
    input_tokens=${input_tokens:-0}
    local cache_creation=$(grep -o '"cache_creation_input_tokens":[0-9]*' "$json_log" 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}' || echo "0")
    cache_creation=${cache_creation:-0}
    local cache_read=$(grep -o '"cache_read_input_tokens":[0-9]*' "$json_log" 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}' || echo "0")
    cache_read=${cache_read:-0}
    local output_tokens=$(grep -o '"output_tokens":[0-9]*' "$json_log" 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}' || echo "0")
    output_tokens=${output_tokens:-0}

    # Calculate cache efficiency
    local total_input=$((input_tokens + cache_creation + cache_read))
    local cache_hit_rate=0
    if [ $total_input -gt 0 ]; then
        cache_hit_rate=$((cache_read * 100 / total_input))
    fi

    # Write detailed analysis
    cat > "$output_file" << EOF
=== Iteration ${iter_num} Analysis ===

Tool Usage:
  Read:      ${tool_read}
  Bash:      ${tool_bash}
  Edit:      ${tool_edit}
  Write:     ${tool_write}
  Grep:      ${tool_grep}
  Glob:      ${tool_glob}
  Task:      ${tool_task} (subagent spawns)
  TodoWrite: ${tool_todo}
  ─────────
  Total:     ${total_tools}

Token Usage:
  Input tokens:          ${input_tokens}
  Cache creation:        ${cache_creation}
  Cache read:            ${cache_read}
  Output tokens:         ${output_tokens}
  ─────────────────────
  Total input:           ${total_input}
  Cache hit rate:        ${cache_hit_rate}%

Workload Classification:
  Shallow operations:    ${tool_read} reads + ${tool_grep} greps + ${tool_glob} globs = $((tool_read + tool_grep + tool_glob))
  Deep operations:       ${tool_edit} edits + ${tool_write} writes = $((tool_edit + tool_write))
  Subagent spawns:       ${tool_task}

Shallow/Deep ratio:    $((tool_read + tool_grep + tool_glob)):$((tool_edit + tool_write))

EOF

    # Display summary
    echo -e "\n${GREEN_BOLD}═══════════════════════════════════════════════════════${RESET}"
    echo -e "${GREEN_BOLD}   Iteration ${iter_num} Analytics${RESET}"
    echo -e "${GREEN_BOLD}═══════════════════════════════════════════════════════${RESET}"
    echo -e "${CYAN_BOLD}Tool Usage:${RESET}"
    echo -e "  Read: ${tool_read} | Bash: ${tool_bash} | Edit: ${tool_edit} | Write: ${tool_write}"
    echo -e "  Grep: ${tool_grep} | Glob: ${tool_glob} | ${YELLOW_BOLD}Subagents: ${tool_task}${RESET} | Todo: ${tool_todo}"
    echo -e "  ${GREEN_BOLD}Total tools: ${total_tools}${RESET}"
    echo -e ""
    echo -e "${CYAN_BOLD}Token Usage:${RESET}"
    echo -e "  Input: ${input_tokens} | Cache creation: ${cache_creation} | Cache read: ${cache_read}"
    echo -e "  Output: ${output_tokens} | ${GREEN_BOLD}Cache hit rate: ${cache_hit_rate}%${RESET}"
    echo -e ""
    echo -e "${CYAN_BOLD}Workload:${RESET}"
    echo -e "  ${BLUE_BOLD}Shallow ops (reads/greps/globs): $((tool_read + tool_grep + tool_glob))${RESET}"
    echo -e "  ${YELLOW_BOLD}Deep ops (edits/writes): $((tool_edit + tool_write))${RESET}"
    echo -e "  ${GREEN_BOLD}Shallow:Deep ratio = $((tool_read + tool_grep + tool_glob)):$((tool_edit + tool_write))${RESET}"
    echo -e "${GREEN_BOLD}═══════════════════════════════════════════════════════${RESET}\n"

    # Append to summary
    cat >> "$SUMMARY_FILE" << EOF
## Iteration ${iter_num}

| Metric | Value |
|--------|-------|
| **Tool calls** | ${total_tools} |
| Read | ${tool_read} |
| Bash | ${tool_bash} |
| Edit | ${tool_edit} |
| Write | ${tool_write} |
| Grep | ${tool_grep} |
| Glob | ${tool_glob} |
| **Subagents (Task)** | **${tool_task}** |
| TodoWrite | ${tool_todo} |
| **Tokens** | |
| Input | ${input_tokens} |
| Cache creation | ${cache_creation} |
| Cache read | ${cache_read} |
| Output | ${output_tokens} |
| **Cache hit rate** | **${cache_hit_rate}%** |
| **Workload** | |
| Shallow ops | $((tool_read + tool_grep + tool_glob)) |
| Deep ops | $((tool_edit + tool_write)) |
| Ratio (Shallow:Deep) | $((tool_read + tool_grep + tool_glob)):$((tool_edit + tool_write)) |

---

EOF
}

# ────────────────────────────────────────────────
# Header
# ────────────────────────────────────────────────

ITERATION=0
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")

echo -e "${GREEN_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN_BOLD}Mode:         $MODE${RESET}"
echo -e "${GREEN_BOLD}Model:        $MODEL${RESET}"
echo -e "${GREEN_BOLD}Prompt:       $PROMPT_FILE${RESET}"
[ -n "$GOAL_TEXT" ] && echo -e "${GREEN_BOLD}Goal:         $GOAL_TEXT${RESET}"
echo -e "${GREEN_BOLD}Branch:       $CURRENT_BRANCH${RESET}"
echo -e "${GREEN_BOLD}Execution:    $(if $USE_SANDBOX; then echo "docker sandbox"; else echo "claude CLI (direct)${RESET}"; fi)${RESET}"
[ $MAX_ITERATIONS -gt 0 ] && echo -e "${GREEN_BOLD}Max:          $MAX_ITERATIONS iterations${RESET}"
echo -e "${CYAN_BOLD}Analytics:    ${ANALYTICS_DIR}${RESET}"
echo -e "${GREEN_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

# ────────────────────────────────────────────────
# Confirmation when using --no-sandbox
# ────────────────────────────────────────────────

if ! $USE_SANDBOX; then
    echo -e ""
    echo -e "${YELLOW_BOLD}⚠️  WARNING: Running in DIRECT Claude CLI mode (--no-sandbox)${RESET}"
    echo -e "${YELLOW_BOLD}   • No sandbox isolation — Claude can run ANY shell command${RESET}"
    echo -e "${YELLOW_BOLD}   • --dangerously-skip-permissions is ON → all tool calls auto-approved${RESET}"
    echo -e "${YELLOW_BOLD}   • Model can read, write or delete files ANYWHERE your user has access${RESET}"
    echo -e "${YELLOW_BOLD}   • Only proceed if you accept full responsibility for the risk${RESET}"
    echo -e ""
    read -p "Continue without sandbox? (y/N) " -n 1 -r
    echo    # move to new line
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED_BOLD}Aborted by user.${RESET}"
        exit 1
    fi
    echo -e "${GREEN_BOLD}Confirmed — proceeding without sandbox.${RESET}\n"
fi

# ────────────────────────────────────────────────
# Main loop
# ────────────────────────────────────────────────

while true; do
    if [ $MAX_ITERATIONS -gt 0 ] && [ $ITERATION -ge $MAX_ITERATIONS ]; then
        echo -e "${GREEN_BOLD}Reached max iterations: $MAX_ITERATIONS${RESET}"
        break
    fi

    CURRENT_ITER=$((ITERATION + 1))

    START_TIME=$(date +%s)
    START_DISPLAY=$(date '+%Y-%m-%d %H:%M:%S')

    echo -e "${GREEN_BOLD}Starting iteration ${CURRENT_ITER} at ${START_DISPLAY}${RESET}"

    # Log file for this iteration
    ITER_LOG="${ANALYTICS_DIR}/iteration-${CURRENT_ITER}.json"

    if $USE_SANDBOX; then
        # Run Ralph iteration via Docker sandbox (prompt passed directly)
        # Capture JSON output to file AND display to terminal
        docker sandbox run claude . -- \
            -p \
            --output-format=stream-json \
            --model "$MODEL" \
            --verbose \
            "$FINAL_PROMPT" | tee "$ITER_LOG"
    else
        # Run Ralph iteration without sandbox with selected prompt
        # Capture JSON output to file AND display to terminal
        echo "$FINAL_PROMPT" | claude -p \
            --output-format=stream-json \
            --model "$MODEL" \
            --verbose \
            --dangerously-skip-permissions | tee "$ITER_LOG"
    fi

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    DURATION_MIN=$((DURATION / 60))
    DURATION_SEC=$((DURATION % 60))

    echo -e "${GREEN_BOLD}Iteration ${CURRENT_ITER} completed in ${DURATION_MIN}m ${DURATION_SEC}s${RESET}"

    # Analyze the iteration
    analyze_iteration "$CURRENT_ITER" "$ITER_LOG"

    # Completion check
    if [ -f .agent_complete ]; then
        echo -e "${GREEN_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        echo -e "${GREEN_BOLD}Agent signaled: COMPLETION${RESET}"
        echo -e "${GREEN_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        rm -f .agent_complete
        break
    fi

    # Push changes after each iteration
    git push origin "$CURRENT_BRANCH" || {
        echo -e "${GREEN_BOLD}Failed to push. Creating remote branch...${RESET}"
        git push -u origin "$CURRENT_BRANCH"
    }

    ITERATION=$((ITERATION + 1))
    echo -e "${GREEN_BOLD}\n\n======================== LOOP $ITERATION ========================${RESET}\n"
done

# ────────────────────────────────────────────────
# Final summary
# ────────────────────────────────────────────────

cat >> "$SUMMARY_FILE" << EOF

---

**Completed**: $(date '+%Y-%m-%d %H:%M:%S')
**Total iterations**: ${CURRENT_ITER}

## Key Findings

EOF

# Aggregate statistics across all iterations
echo -e "\n${GREEN_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN_BOLD}   Final Analytics Summary${RESET}"
echo -e "${GREEN_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

# Calculate totals across all iterations
total_subagents=0
total_reads=0
total_edits=0
total_cache_creation=0
total_cache_reads=0

for i in $(seq 1 $CURRENT_ITER); do
    iter_log="${ANALYTICS_DIR}/iteration-${i}.json"
    if [ -f "$iter_log" ]; then
        subagents=$(grep -c '"name":"Task"' "$iter_log" 2>/dev/null | head -1 || echo "0")
        subagents=${subagents:-0}
        reads=$(grep -c '"name":"Read"' "$iter_log" 2>/dev/null | head -1 || echo "0")
        reads=${reads:-0}

        edit_count=$(grep -c '"name":"Edit"' "$iter_log" 2>/dev/null | head -1 || echo "0")
        edit_count=${edit_count:-0}
        write_count=$(grep -c '"name":"Write"' "$iter_log" 2>/dev/null | head -1 || echo "0")
        write_count=${write_count:-0}
        edits=$((edit_count + write_count))

        cache_cr=$(grep -o '"cache_creation_input_tokens":[0-9]*' "$iter_log" 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}' || echo "0")
        cache_cr=${cache_cr:-0}
        cache_rd=$(grep -o '"cache_read_input_tokens":[0-9]*' "$iter_log" 2>/dev/null | awk -F: '{sum+=$2} END {print sum+0}' || echo "0")
        cache_rd=${cache_rd:-0}

        total_subagents=$((total_subagents + subagents))
        total_reads=$((total_reads + reads))
        total_edits=$((total_edits + edits))
        total_cache_creation=$((total_cache_creation + cache_cr))
        total_cache_reads=$((total_cache_reads + cache_rd))
    fi
done

# Avoid division by zero and ensure proper integer division
avg_subagents=0
avg_reads=0
if [ $CURRENT_ITER -gt 0 ]; then
    avg_subagents=$((total_subagents / CURRENT_ITER))
    avg_reads=$((total_reads / CURRENT_ITER))
fi

echo -e "${CYAN_BOLD}Across ${CURRENT_ITER} iterations:${RESET}"
echo -e "  ${YELLOW_BOLD}Total subagents spawned: ${total_subagents}${RESET}"
echo -e "  ${BLUE_BOLD}Average per iteration: ${avg_subagents}${RESET}"
echo -e ""
echo -e "  Total file reads: ${total_reads}"
echo -e "  Total edits/writes: ${total_edits}"
echo -e "  Average reads per iteration: ${avg_reads}"
echo -e ""
echo -e "  Total cache creation: ${total_cache_creation} tokens"
echo -e "  Total cache reads: ${total_cache_reads} tokens"
if [ $((total_cache_creation + total_cache_reads)) -gt 0 ]; then
    overall_cache_rate=$((total_cache_reads * 100 / (total_cache_creation + total_cache_reads)))
    echo -e "  ${GREEN_BOLD}Overall cache hit rate: ${overall_cache_rate}%${RESET}"
fi
echo -e ""
echo -e "${CYAN_BOLD}Full report saved to:${RESET} ${ANALYTICS_DIR}/summary.md"
echo -e "${GREEN_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

# Append aggregate stats to summary
cat >> "$SUMMARY_FILE" << EOF
### Aggregate Statistics

- **Total subagents spawned**: ${total_subagents}
- **Average subagents per iteration**: ${avg_subagents}
- **Total file reads**: ${total_reads}
- **Total edits/writes**: ${total_edits}
- **Cache creation tokens**: ${total_cache_creation}
- **Cache read tokens**: ${total_cache_reads}

### Analysis

The actual subagent spawn count was **${avg_subagents} per iteration** (average), significantly different from the theoretical maximum mentioned in prompts. This confirms that:

1. **Parallelism is sparse**: Most work is done with ${avg_reads} reads per iteration, not hundreds
2. **Cache efficiency**: $(if [ $((total_cache_creation + total_cache_reads)) -gt 0 ]; then echo "$((total_cache_reads * 100 / (total_cache_creation + total_cache_reads)))% cache hit rate"; else echo "N/A"; fi)
3. **Workload is ${total_reads}:${total_edits} read-heavy**: More reconnaissance than modification

### Implications for Ollama Migration

Based on empirical data:
- Single Ollama server can handle ${avg_subagents} concurrent subagents
- Prompt caching provides $(if [ $((total_cache_creation + total_cache_reads)) -gt 0 ]; then echo "$((total_cache_reads * 100 / (total_cache_creation + total_cache_reads)))%"; else echo "N/A"; fi) efficiency gain
- Shallow operations (reads) dominate the workload (suitable for local models)
EOF

echo -e "\n${GREEN_BOLD}Loop finished${RESET}"
echo -e "${CYAN_BOLD}Analytics saved to: ${ANALYTICS_DIR}${RESET}\n"
