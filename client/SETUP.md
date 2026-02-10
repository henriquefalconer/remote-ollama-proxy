# remote-ollama ai-client – Setup Instructions (macOS)

## Installation

Choose one of the following methods:

### Option 1: Quick Install (Recommended)

Run the installer directly via curl:

```bash
curl -fsSL https://raw.githubusercontent.com/henriquefalconer/remote-ollama/master/client/scripts/install.sh | bash
```

### Option 2: Clone and Install

Clone the repository and run the installer locally:

```bash
git clone https://github.com/henriquefalconer/remote-ollama.git
cd remote-ollama/client
./scripts/install.sh
```

## What the installer does

The installer will:
- Check/install Homebrew, Python, Tailscale
- Open Tailscale for login and device approval
- Prompt for server hostname (default: `ai-server`)
- Create `~/.ai-client/env` with required environment variables
- Update your shell profile (~/.zshrc) to source the environment
- Install Aider via pipx
- Run a connectivity test

## Post-Installation

### Open a new terminal

```bash
exec $SHELL
```

Or simply open a new terminal window.

### Verify installation

```bash
# Check environment variables
echo $OLLAMA_API_BASE          # http://ai-server:11434 (no /v1 suffix)
echo $OPENAI_API_BASE          # http://ai-server:11434/v1
echo $OPENAI_API_KEY           # ollama

# Check Aider
aider --version

# Test server connectivity (if server is running and you have access)
curl $OLLAMA_API_BASE/v1/models
```

## Usage

The client has **no persistent service or daemon**. It only configures environment variables.

### Run Aider
```bash
aider                     # interactive mode - uses server automatically
aider --yes               # YOLO mode
```

### Check Configuration
```bash
# Verify environment variables are set
echo $OPENAI_API_BASE    # Should show: http://ai-server:11434/v1
echo $OPENAI_API_KEY     # Should show: ollama

# Test connectivity (requires server access)
curl $OPENAI_API_BASE/models
```

### No Service Management Needed

There's nothing to start, stop, or restart on the client side. Just run tools when you need them.

## Uninstall

If you installed via local clone:
```bash
./scripts/uninstall.sh
```

If you installed via curl-pipe:
```bash
~/.ai-client/uninstall.sh
```

## Troubleshooting

### Critical v0.0.3 Bug: Aider fails with 404 errors

**Symptom**: If you installed v0.0.3 and Aider fails with 404 errors like `http://remote-ollama:11434/v1/api/show not found`.

**Root Cause**: The v0.0.3 `env.template` incorrectly set `OLLAMA_API_BASE` with a `/v1` suffix. This causes Aider/LiteLLM to construct invalid URLs.

**Solution (v0.0.4+)**: Fixed in v0.0.4. To update your v0.0.3 installation:

```bash
# Option 1: Re-run the installer (recommended)
./scripts/install.sh

# Option 2: Manual fix - edit ~/.ai-client/env
nano ~/.ai-client/env
# Change this line:
#   export OLLAMA_API_BASE=http://remote-ollama:11434/v1
# To this (remove /v1):
#   export OLLAMA_API_BASE=http://remote-ollama:11434

# Then reload your environment:
exec $SHELL
```

**Verification**: Check that your environment variables are correct:
```bash
echo $OLLAMA_API_BASE   # Should be http://remote-ollama:11434 (NO /v1)
echo $OPENAI_API_BASE   # Should be http://remote-ollama:11434/v1 (WITH /v1)
```

### "Connection refused" when testing connectivity

**Symptom**: `curl $OPENAI_API_BASE/models` fails with connection refused.

**Solutions**:
- Verify Tailscale is connected: `tailscale status` (should show "Connected")
- Check you can resolve server hostname: `ping remote-ollama` (or your custom hostname)
- Verify you're on the same Tailscale network as the server
- Check Tailscale ACLs: you must have the appropriate tag or device access granted by the admin
- Test if server is responding: ask server admin to verify `./scripts/test.sh` passes
- Verify server hostname in `~/.ai-client/env` matches your Tailscale configuration

### Environment variables not set

**Symptom**: Aider or other tools can't find the API base URL.

**Solutions**:
- Verify env file exists: `cat ~/.ai-client/env` (should show 4 variables)
- Check variables are set in current shell: `echo $OPENAI_API_BASE` (should show URL)
- Ensure you opened a **new terminal** after installation (or run `exec $SHELL`)
- Verify shell profile sources env: `grep ai-client ~/.zshrc` (should show source line with markers)
- Manually source for current session: `source ~/.ai-client/env`
- If using bash instead of zsh, check `~/.bashrc` has the sourcing line

### Aider not found

**Symptom**: `aider` command not found, or `which aider` returns nothing.

**Solutions**:
- Verify pipx is installed: `which pipx` (should return `/opt/homebrew/bin/pipx` or similar)
- Check if Aider is installed: `pipx list` (should show aider-chat)
- Ensure pipx path is in PATH: `echo $PATH | grep .local/bin` (should show `~/.local/bin`)
- Run `pipx ensurepath` to add pipx binaries to PATH, then open new terminal
- Manually check if binary exists: `ls -l ~/.local/bin/aider` (should exist)
- If missing, reinstall: `pipx install aider-chat`

### Aider connects but responses are slow

**Symptom**: Aider works but first request is very slow (30+ seconds).

**Explanation**: This is expected on first request. Large models take time to load into memory.

**Solutions**:
- Ask server admin to run warm-models script: `./scripts/warm-models.sh <model-name>`
- Subsequent requests will be much faster once model is loaded
- Use smaller models for faster initial response (e.g., qwen2.5-coder:7b instead of :32b)

### JSON mode or tools not working

**Symptom**: Aider or tools report JSON mode not supported, or tool calling fails.

**Explanation**: These features are model-dependent. Not all Ollama models support JSON mode or tool calling.

**Solutions**:
- Use a model known to support the feature (check Ollama model documentation)
- For JSON mode: qwen2.5-coder:* and deepseek-r1:* generally support it
- For tool calling: check if the specific model version supports function calling
- The client is working correctly - this is a model capability limitation

### Tailscale not connecting or staying connected

**Symptom**: `tailscale status` shows "Stopped" or connection drops frequently.

**Solutions**:
- Start Tailscale: Open the Tailscale app from Applications
- Verify you're logged in: `tailscale status` should show your email and devices
- Check for network issues: some corporate/public WiFi blocks VPNs
- Try restarting Tailscale: Quit app completely and reopen
- Re-authenticate if needed: `tailscale login` (may require browser)

### Running the Test Suite

If unsure about the state of your installation, run the comprehensive test suite:

```bash
# Run all 27 tests
./scripts/test.sh

# Skip server connectivity tests (useful if server is down)
./scripts/test.sh --skip-server

# Run only critical tests (environment + dependencies, skip API validation)
./scripts/test.sh --quick

# Show detailed request/response data
./scripts/test.sh --verbose
```

The test suite will identify specific issues with environment configuration, dependencies, server connectivity, or Aider integration.

## The client is now fully configured

All tools respecting the OpenAI API contract will work with zero per-session configuration.
