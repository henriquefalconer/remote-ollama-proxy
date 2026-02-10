# remote-ollama ai-client Scripts

## scripts/install.sh

### Functionality
- Validates macOS 14+ (Sonoma or later)
- Checks / installs Homebrew, Python 3.10+, Tailscale
- Installs both Tailscale GUI (for user) and CLI (for connection detection)
- Opens Tailscale app for login + device approval if not already connected
- Prompts for server hostname (default: remote-ollama)
- Creates `~/.ai-client/` directory
- Generates `~/.ai-client/env` with exact variables from API_CONTRACT.md
- Prompts for user consent before modifying shell profile
- Appends `source ~/.ai-client/env` to `~/.zshrc` or `~/.bashrc` with marker comments
- Installs pipx if needed, runs `pipx ensurepath`
- Installs Aider via pipx (isolated, no global pollution)
- Copies uninstall.sh to `~/.ai-client/` for curl-pipe users
- Runs connectivity test (warns but does not abort if server unreachable)

### UX Requirements
- **Homebrew noise suppression** - Set HOMEBREW_NO_ENV_HINTS and HOMEBREW_NO_INSTALL_CLEANUP
- **Color-coded output** - Use echo -e with GREEN/YELLOW/RED/BLUE for messages
- **Clear sections** - Use boxed or visually separated sections for major steps
- **Progress tracking** - Show what's being installed/configured at each step
- **Interactive consent** - Always ask before modifying shell profile
- **Dual-mode support** - Work both as local clone and curl-pipe installation:
  - Embed env.template content as heredoc fallback
  - Copy uninstall.sh to `~/.ai-client/` for later access
- **Comprehensive Tailscale guidance** - Similar to server install:
  - Warn about sudo password prompt
  - List all permissions (System Extension, Notifications, Start on login)
  - Mention VPN activation in System Settings if needed
  - Note survey and tutorial can be skipped
- **Connectivity test** - Test server connection but only warn (don't fail) if unreachable
- **Final summary** - Show what was installed and next steps:
  - Remind to open new terminal or run `exec $SHELL`
  - Show example Aider command
  - Display troubleshooting resources
- **Idempotent** - Safe to re-run without breaking existing setup

## scripts/uninstall.sh

### Functionality
- Removes Aider via `pipx uninstall aider-chat`
- Removes marker-delimited block from shell profile (`~/.zshrc` and `~/.bashrc`)
- Deletes `~/.ai-client/` directory (includes env file and copied uninstall script)
- Leaves Tailscale, Homebrew, and pipx untouched (user may need them for other tools)
- Handles edge cases gracefully (Aider not installed, directory missing, profile not modified)

### UX Requirements
- **Clear banner** - Display script name and purpose at start
- **Color-coded output** - Use echo -e with GREEN/YELLOW/RED for messages
- **Progress tracking** - Show what's being removed at each step
- **Final summary** - Display boxed or clearly separated summary showing:
  - What was successfully removed
  - What was left intact (Tailscale, Homebrew, pipx)
  - Reminder to close/reopen terminal for changes to take effect
- **Graceful degradation** - Continue with remaining cleanup even if some steps fail
- **Idempotent** - Safe to re-run on already-cleaned system (no errors on missing components)

## scripts/test.sh

Comprehensive test script that validates all client functionality. Designed to run on the client machine after installation.

### Environment Configuration Tests
- Verify `~/.ai-client/env` file exists
- Verify all required environment variables are set:
  - `OLLAMA_API_BASE` (should be `http://<hostname>:11434` — no `/v1` suffix)
  - `OPENAI_API_BASE` (should be `http://<hostname>:11434/v1` — with `/v1` suffix)
  - `OPENAI_API_KEY` (should be `ollama`)
  - `AIDER_MODEL` (optional, check if set)
- Verify shell profile sources the env file (check `~/.zshrc` or `~/.bashrc` for marker comments)
- Verify environment variables are exported (available to child processes)

### Dependency Tests
- Verify Tailscale is installed and running
- Verify Tailscale is connected (not logged out)
- Verify Homebrew is installed
- Verify Python 3.10+ is available
- Verify pipx is installed
- Verify Aider is installed via pipx (`aider --version`)

### Connectivity Tests
- Test Tailscale connectivity to server hostname
- `GET /v1/models` returns JSON model list from server
- `GET /v1/models/{model}` returns model details (if models available)
- `POST /v1/chat/completions` non-streaming request succeeds
- `POST /v1/chat/completions` streaming request returns SSE chunks
- Test error handling when server unreachable (graceful failure messages)

### API Contract Validation Tests
- Verify base URL format matches contract
- Verify all endpoints return expected HTTP status codes
- Verify response structure matches OpenAI API schema
- Test JSON mode response format
- Test streaming with `stream_options.include_usage`

### Aider Integration Tests
- Verify Aider can be invoked (`which aider`)
- Verify Aider binary is in PATH
- Test Aider reads environment variables correctly (dry-run mode if available)
- Note: Full Aider conversation test requires user interaction

### Claude Code Integration Tests (v2+, Optional)

These tests validate the optional Claude Code + Ollama integration. All tests in this category should be skippable if Claude Code is not installed or if the user has not opted into the integration.

- Verify Claude Code binary is installed (`which claude`)
- Verify Claude Code binary is in PATH
- Verify `claude-ollama` alias exists in shell profile (check between `# >>> claude-ollama >>>` and `# <<< claude-ollama <<<` markers)
- Verify alias has correct environment variables (`ANTHROPIC_AUTH_TOKEN=ollama`, `ANTHROPIC_API_KEY=""`, `ANTHROPIC_BASE_URL=http://<hostname>:11434`)
- Test `POST /v1/messages` endpoint connectivity (non-streaming)
  - Verify response has required Anthropic API fields: `id`, `type: "message"`, `role: "assistant"`, `content` array, `stop_reason`, `usage`
- Test `POST /v1/messages` streaming connectivity
  - Verify SSE event types are correct: `message_start`, `content_block_start`, `content_block_delta`, `content_block_stop`, `message_delta`, `message_stop`
- Note: Full Claude Code integration test requires actual claude invocation (deferred to user acceptance)

**Flag Support**: `--skip-claude` flag to skip all Claude Code tests

### Version Management Tests (v2+, Optional)

These tests validate the version management scripts. Tests should be skippable if scripts are not present (v2+ not yet installed).

- Verify `check-compatibility.sh` exists in `client/scripts/`
- Verify `check-compatibility.sh` has valid bash syntax (`bash -n check-compatibility.sh`)
- Verify `check-compatibility.sh` is executable
- Verify `pin-versions.sh` exists in `client/scripts/`
- Verify `pin-versions.sh` has valid bash syntax
- Verify `pin-versions.sh` is executable
- Verify `downgrade-claude.sh` exists in `client/scripts/`
- Verify `downgrade-claude.sh` has valid bash syntax
- Verify `downgrade-claude.sh` is executable
- If `~/.ai-client/.version-lock` exists, verify format:
  - File is readable
  - Contains `CLAUDE_CODE_VERSION=X.Y.Z`
  - Contains `OLLAMA_VERSION=X.Y.Z`
  - Contains `TESTED_DATE=YYYY-MM-DD`
  - Contains `STATUS=working` (or other valid status)

**Flag Support**: Version management tests auto-skip if scripts don't exist

**Note**: Full specification of check-compatibility.sh, pin-versions.sh, and downgrade-claude.sh can be found in `client/specs/VERSION_MANAGEMENT.md`.

### Script Behavior Tests
- Verify install.sh idempotency (safe to re-run)
- Verify uninstall.sh availability (local clone or `~/.ai-client/uninstall.sh`)
- Test uninstall.sh on clean system (should not error)

### Output Format
- **Per-test results** - Clear pass/fail/skip for each test with brief description
- **Summary statistics** - Final count (X passed, Y failed, Z skipped)
- **Exit codes** - 0 if all tests pass, non-zero otherwise
- **Verbose mode** - `--verbose` or `-v` flag for detailed output (request/response bodies)
- **Colorized output** - Use echo -e with color codes:
  - GREEN for passed tests
  - RED for failed tests
  - YELLOW for skipped tests
- **Progress indication** - Show test number / total (e.g., "Running test 12/27...")
- **Grouped results** - Organize output by test category (Environment, Dependencies, Connectivity, etc.)

### UX Requirements
- **Clear banner** - Display script name, purpose, and test count at start
- **Real-time feedback** - Show results as tests run (don't wait until end)
- **Minimal noise** - Suppress verbose curl output unless --verbose flag used
- **Helpful failures** - When test fails, show:
  - What was expected
  - What was received
  - Suggested troubleshooting steps (e.g., "Run install.sh to configure")
- **Skip guidance** - If tests are skipped, explain why and how to enable them
- **Final summary box** - Visually separated summary section with:
  - Overall pass/fail status
  - Statistics
  - Next steps if failures occurred (e.g., "Run install.sh", "Check server status")

### Test Modes
- `--skip-server` - Skip connectivity tests (for offline testing)
- `--skip-aider` - Skip Aider-specific tests (v1)
- `--skip-claude` - Skip Claude Code integration tests (v2+)
- `--quick` - Run only critical tests (env vars, dependencies, basic connectivity)
- `--v1-only` - Run only v1/Aider tests (equivalent to `--skip-claude`)
- `--v2-only` - Run only v2+/Claude Code tests (equivalent to `--skip-aider`)

## config/env.template

- Template showing the exact variables required by the contract
- Used by install.sh to create `~/.ai-client/env`
