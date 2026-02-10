# remote-ollama ai-server – Setup Instructions

Target: Apple Silicon Mac (high memory recommended) running recent macOS

## Prerequisites

- Administrative access
- Homebrew package manager
- Tailscale account (free personal tier sufficient)

## Step-by-Step Setup

### 1. Install Tailscale

```bash
brew install tailscale
open -a Tailscale          # complete login and device approval
```

### 2. Install Ollama (if not already present)

```bash
brew install ollama
```

### 3. Configure Ollama to listen on all interfaces

Create user-level launch agent:

```bash
mkdir -p ~/Library/LaunchAgents
cat > ~/Library/LaunchAgents/com.ollama.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ollama</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/ollama</string>
        <string>serve</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>OLLAMA_HOST</key>
        <string>0.0.0.0</string>
    </dict>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/ollama.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/ollama.stderr.log</string>
</dict>
</plist>
EOF

launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ollama.plist
```

### 4. Restart Ollama service (if needed)

```bash
launchctl kickstart -k gui/$(id -u)/com.ollama
```

### 5. (Optional) Pre-pull large models for testing

```bash
ollama pull <model-name>   # repeat for desired models
```

### 6. Configure Tailscale ACLs

In Tailscale admin console at tailscale.com:

1. Assign a machine name e.g. "remote-ollama"
2. Create tags e.g. tag:ai-client
3. Add ACL rule example:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:ai-client"],
      "dst": ["tag:ai-server:11434"]
    }
  ]
}
```

### 7. Verify server reachability

#### OpenAI-Compatible API (for Aider and OpenAI-compatible tools)

From an authorized client machine:

```bash
curl http://remote-ollama:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "any-available-model",
    "messages": [{"role": "user", "content": "Say hello"}]
  }'
```

#### Anthropic-Compatible API (for Claude Code, requires Ollama 0.5.0+)

Test the Anthropic Messages API endpoint:

```bash
curl http://remote-ollama:11434/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: ollama" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "any-available-model",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Say hello"}]
  }'
```

**Expected response format:**
```json
{
  "id": "msg_abc123",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "Hello! How can I help you today?"
    }
  ],
  "stop_reason": "end_turn",
  "usage": {
    "input_tokens": 10,
    "output_tokens": 15
  }
}
```

**Test streaming (optional):**

```bash
curl http://remote-ollama:11434/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: ollama" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "any-available-model",
    "max_tokens": 1024,
    "stream": true,
    "messages": [{"role": "user", "content": "Say hello"}]
  }'
```

This returns Server-Sent Events (SSE) with event types: `message_start`, `content_block_start`, `content_block_delta`, `content_block_stop`, `message_delta`, `message_stop`.

**Note**: The Anthropic-compatible API is experimental in Ollama and requires version 0.5.0 or later. See `server/specs/ANTHROPIC_COMPATIBILITY.md` for complete details on supported features and limitations.

## Server is now operational

Clients must join the same tailnet and receive the appropriate tag to connect.

## Managing the Ollama Service

The Ollama service runs as a user-level LaunchAgent and starts automatically at login.

### Check Status
```bash
# Check if service is loaded
launchctl list | grep com.ollama

# Test OpenAI API availability
curl -sf http://localhost:11434/v1/models

# Test Anthropic API availability (Ollama 0.5.0+)
curl -sf http://localhost:11434/v1/messages \
  -X POST \
  -H "Content-Type: application/json" \
  -H "x-api-key: test" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model":"test","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}'
```

### Start Service
```bash
# The service starts automatically, but you can manually start it with:
launchctl kickstart gui/$(id -u)/com.ollama
```

### Stop Service
```bash
# Temporarily stop the service (will restart on next login)
launchctl stop gui/$(id -u)/com.ollama
```

### Restart Service
```bash
# Kill and immediately restart the service
launchctl kickstart -k gui/$(id -u)/com.ollama
```

### Disable Service (Prevent Auto-Start)
```bash
# Completely unload the service
launchctl bootout gui/$(id -u)/com.ollama
```

### Re-enable Service
```bash
# Load the service again
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ollama.plist
```

### View Logs
```bash
# Monitor standard output
tail -f /tmp/ollama.stdout.log

# Monitor errors
tail -f /tmp/ollama.stderr.log
```

### Check Current Models
```bash
# List all pulled models
ollama list

# Pull a new model
ollama pull <model-name>
```

### (Optional) Warm Models for Faster First Response

The `warm-models.sh` script eliminates cold-start latency by pre-loading models into memory. This is particularly useful for large models that take significant time to load on first request.

```bash
# Navigate to server directory if not already there
cd /path/to/remote-ollama/server

# Warm specific models
./scripts/warm-models.sh qwen2.5-coder:32b deepseek-r1:70b
```

The script will:
1. Verify Ollama is running
2. Pull each model (if not already downloaded)
3. Send a minimal inference request to load the model into memory
4. Report success/failure for each model

This step is optional but recommended if you want immediate response times after server boot or restart. You can also integrate this into launchd for automatic warmup at boot - see the script's inline comments for details.

## Troubleshooting

### Service Not Starting

**Symptom**: `launchctl list | grep com.ollama` shows nothing, or service won't load.

**Solutions**:
- Check if another Ollama instance is running: `ps aux | grep ollama`
- If Homebrew services is running Ollama, stop it: `brew services stop ollama`
- Verify plist exists: `ls -l ~/Library/LaunchAgents/com.ollama.plist`
- Check plist syntax: `plutil -lint ~/Library/LaunchAgents/com.ollama.plist`
- Try manually loading: `launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ollama.plist`
- Check logs for errors: `tail -20 /tmp/ollama.stderr.log`

### Port 11434 Already in Use

**Symptom**: Service fails to start, logs show "address already in use".

**Solutions**:
- Find what's using the port: `lsof -i :11434`
- Stop conflicting service (usually Homebrew's Ollama): `brew services stop ollama`
- Kill the conflicting process: `kill <PID>` (from lsof output)
- Restart the LaunchAgent: `launchctl kickstart -k gui/$(id -u)/com.ollama`

### API Not Responding

**Symptom**: `curl http://localhost:11434/v1/models` times out or refuses connection.

**Solutions**:
- Verify service is running: `launchctl list | grep com.ollama` (should show PID in first column)
- Check if process is actually running: `ps aux | grep "[o]llama serve"`
- Verify port is open: `nc -zv localhost 11434` or `lsof -i :11434`
- Check environment variable in plist: `plutil -p ~/Library/LaunchAgents/com.ollama.plist | grep OLLAMA_HOST` (should be `0.0.0.0`)
- Review logs: `tail -50 /tmp/ollama.stdout.log` and `tail -50 /tmp/ollama.stderr.log`

### Models Not Loading

**Symptom**: API responds but model inference requests fail.

**Solutions**:
- Verify models are pulled: `ollama list`
- Pull the model manually: `ollama pull <model-name>`
- Check available memory: Large models require significant RAM
- Review stderr log for out-of-memory errors: `tail -50 /tmp/ollama.stderr.log`

### Client Cannot Connect

**Symptom**: Client can reach Tailscale IP but gets connection refused on port 11434.

**Solutions**:
- Verify OLLAMA_HOST=0.0.0.0 in plist (not 127.0.0.1): `plutil -p ~/Library/LaunchAgents/com.ollama.plist`
- Test localhost first: `curl http://localhost:11434/v1/models` (should work)
- Test Tailscale IP from server itself: `curl http://$(tailscale ip -4):11434/v1/models`
- If localhost works but Tailscale IP doesn't, verify OLLAMA_HOST: restart service after fixing plist
- Check Tailscale ACLs: client must have appropriate tag or device access
- Verify no firewall blocking port 11434 (macOS firewall typically allows local binaries)

### Running the Test Suite

If unsure about the state of your installation, run the comprehensive test suite:

```bash
# Run all 20 tests
./scripts/test.sh

# Skip model inference tests (faster)
./scripts/test.sh --skip-model-tests

# Show detailed request/response data
./scripts/test.sh --verbose
```

The test suite will identify specific issues with service status, API endpoints, security configuration, or network binding.
