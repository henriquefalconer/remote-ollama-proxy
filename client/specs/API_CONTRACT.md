# remote-ollama ai-server API Contract (client view)

The remote-ollama ai-server exposes two API surfaces for different client tools:

1. **OpenAI-compatible API** - For Aider and OpenAI-compatible tools
2. **Anthropic-compatible API** - For Claude Code and Anthropic-compatible tools

Both APIs are served by the same Ollama server on port 11434.

---

## OpenAI-Compatible API (v1)

The remote-ollama ai-server exposes a strict subset of the OpenAI API at the following base URL:

## Base URL

`http://remote-ollama:11434/v1`

- Hostname is fixed; resolved via Tailscale
- Port is always 11434

## Authentication

- `Authorization: Bearer <any-value>` or `api_key` parameter is required by SDKs but ignored by the server
- Recommended dummy value: `ollama`

## Supported Endpoints

All others return 404.

| Endpoint                     | Method | Key Capabilities (client can rely on)                          | Limitations (client must not assume) |
|------------------------------|--------|----------------------------------------------------------------|--------------------------------------|
| `/v1/chat/completions`       | POST   | streaming (`stream: true`), JSON mode (`response_format: { "type": "json_object" }`), tools/tool_choice, vision (image_url), temperature/top_p/max_tokens/seed/stop/n | No stateful conversation memory; no previous_response_id |
| `/v1/models`                 | GET    | Returns list of available models with id, created, owned_by   | created = last-modified timestamp only |
| `/v1/models/{model}`         | GET    | Single model details                                           | Same as above |
| `/v1/responses`              | POST   | Non-stateful responses, streaming, tools/function calling      | No previous_response_id or conversation support; requires Ollama 0.5.0+ (experimental) |

## Common Request Fields (guaranteed)

- `model` (string – any model name available on server)
- `messages` (array of role/content objects; content can be text or image_url)
- `stream`, `stream_options.include_usage`
- `tools`, `tool_choice` (supported when model implements it)
- `response_format.type = "json_object"`
- `temperature`, `top_p`, `max_tokens`, `seed`, `stop`, `n`

## Environment Variables the client must set

```bash
OLLAMA_API_BASE=http://remote-ollama:11434
OPENAI_API_BASE=http://remote-ollama:11434/v1
OPENAI_API_KEY=ollama
AIDER_MODEL=ollama/<model-name>                       # optional
```

**Rationale**:
- `OLLAMA_API_BASE` (no `/v1` suffix): Used by Ollama-aware tools (like Aider/LiteLLM) for model metadata via Ollama's native `/api/show` endpoint. This endpoint exists on the server but is not part of the guaranteed API contract.
- `OPENAI_API_BASE` (with `/v1` suffix): Used by OpenAI-compatible tools for chat completions. This is the primary supported interface.
- `OPENAI_API_KEY`: Required by most SDKs/tools but ignored by server (Tailscale ACLs provide security).
- `AIDER_MODEL`: Optional default model selection for Aider.

## Error Behavior (client must handle)

- 404 / connection refused → Tailscale not connected or server unreachable
- 429 → server-side concurrency limit (rare)
- 500 → inference error (model unloaded, OOM, etc.)

## This contract is the only API surface the client may depend on

Do not make assumptions about server internals, model availability, or features not explicitly listed above.

---

## Anthropic-Compatible API (v2+)

The remote-ollama ai-server also exposes Anthropic Messages API compatibility at:

### Base URL

`http://remote-ollama:11434/v1/messages`

- Same hostname and port as OpenAI API
- Different endpoint path (`/v1/messages` vs `/v1/chat/completions`)

### Authentication

- `x-api-key` header or `ANTHROPIC_API_KEY` environment variable required by SDKs but ignored by server
- `anthropic-version` header accepted but not validated
- Recommended dummy value for API key: `ollama`

### Supported Endpoints

| Endpoint | Method | Capabilities | Limitations |
|----------|--------|--------------|-------------|
| `/v1/messages` | POST | Messages, streaming, system prompts, multi-turn, vision (base64 images), tools, tool results, thinking blocks | No `tool_choice`, no prompt caching, no PDF support, no URL images |

### Supported Request Fields

- ✅ `model` (string)
- ✅ `max_tokens` (integer, required)
- ✅ `messages` (array)
  - ✅ Text content
  - ✅ Image content (base64 only, no URLs)
  - ✅ Array of content blocks
  - ✅ `tool_use` blocks
  - ✅ `tool_result` blocks
  - ✅ `thinking` blocks
- ✅ `system` (string or array)
- ✅ `stream` (boolean)
- ✅ `temperature` (float)
- ✅ `top_p` (float)
- ✅ `top_k` (integer)
- ✅ `stop_sequences` (array)
- ✅ `tools` (array)
- ✅ `thinking` (object)
- ❌ `tool_choice` - **NOT SUPPORTED** (cannot force specific tool use)
- ❌ `metadata` - Not supported

### Supported Response Fields

- ✅ `id` (string)
- ✅ `type` (string)
- ✅ `role` (string)
- ✅ `model` (string)
- ✅ `content` (array of text, tool_use, thinking blocks)
- ✅ `stop_reason` (end_turn, max_tokens, tool_use)
- ✅ `usage` (input_tokens, output_tokens)

### Streaming Events

- ✅ `message_start`
- ✅ `content_block_start`
- ✅ `content_block_delta` (text_delta, input_json_delta, thinking_delta)
- ✅ `content_block_stop`
- ✅ `message_delta`
- ✅ `message_stop`
- ✅ `ping`
- ✅ `error`

### Environment Variables for Claude Code

**Using Anthropic Cloud API (default, recommended):**
```bash
export ANTHROPIC_API_KEY=sk-ant-...
# No ANTHROPIC_BASE_URL needed (uses cloud by default)
```

**Using Local Ollama Server (optional):**
```bash
export ANTHROPIC_AUTH_TOKEN=ollama
export ANTHROPIC_API_KEY=""
export ANTHROPIC_BASE_URL=http://remote-ollama:11434
```

**Shell alias for easy switching:**
```bash
# Recommended: alias for local backend
alias claude-ollama='ANTHROPIC_AUTH_TOKEN=ollama ANTHROPIC_API_KEY="" ANTHROPIC_BASE_URL=http://remote-ollama:11434 claude --dangerously-skip-permissions'

# Usage:
claude --model opus-4-6        # Uses Anthropic cloud
claude-ollama --model qwen3-coder  # Uses local Ollama
```

### Differences from Real Anthropic API

**Behavior differences:**
- API key accepted but not validated (Tailscale provides security)
- `anthropic-version` header accepted but not used
- Token counts are approximations based on underlying model's tokenizer
- Model quality significantly lower (qwen3-coder, glm-4.7 vs Opus/Sonnet)

**Not supported:**
- ❌ `/v1/messages/count_tokens` endpoint
- ❌ `tool_choice` parameter (cannot force specific tool or disable tools)
- ❌ `metadata` (user_id)
- ❌ **Prompt caching** (no `cache_control` blocks) - **MAJOR LIMITATION**
- ❌ Batches API
- ❌ Citations content blocks
- ❌ PDF support (document content blocks)
- ❌ URL-based image content (only base64)

**Partial support:**
- ⚠️ Extended thinking (basic support; `budget_tokens` accepted but not enforced)

### Performance Characteristics

**Compared to Anthropic Cloud API:**

| Metric | Anthropic Cloud | Local Ollama | Impact |
|--------|----------------|--------------|--------|
| Model quality | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | Lower quality output |
| Prompt caching | ✅ | ❌ | 2-3x slower on repeated contexts |
| Parallelism | Unlimited | Queued | Single server serializes requests |
| Latency (simple request) | ~1-2s | ~2-5s | Slightly slower |
| Latency (with caching) | ~0.5s | ~2-5s | Much slower (no cache) |
| Privacy | Cloud | Private | Stays on network |
| Cost | Pay-per-use | Free (hardware cost) | Trade-off |

### Empirical Validation Required

**CRITICAL**: Do not assume Ollama backend suitability for your workflow. Use analytics tools to measure:

1. **Actual subagent spawn count**: Prompt says "up to 500" but reality is typically 5-30
2. **Cache hit rate**: If >60%, Ollama will be significantly slower (no caching)
3. **Shallow:deep ratio**: If >5:1, Ollama suitable for read-heavy workloads
4. **Tool use complexity**: Simple Read/Grep works well; complex multi-tool orchestration may struggle

**Measurement tools provided:**
- `loop-with-analytics.sh` - Capture performance metrics
- `compare-analytics.sh` - Compare Anthropic vs Ollama runs
- See `ANALYTICS.md` for complete specification

### Stability and Version Compatibility

**Risk level**: MEDIUM-HIGH

Ollama's Anthropic compatibility is relatively new and may diverge from Anthropic's API over time. Breaking changes possible within 6-12 months.

**Mitigation strategies:**
1. Pin Claude Code version (use `pin-versions.sh`)
2. Pin Ollama version on server
3. Test updates in staging before production
4. Maintain fallback to Anthropic cloud API
5. Use compatibility checking scripts before updates

**See `VERSION_MANAGEMENT.md` for complete specification.**

### Error Behavior (client must handle)

- 404 / connection refused → Tailscale not connected or server unreachable
- 500 → Inference error (model unloaded, OOM, unsupported feature)
- Tool use errors → Model may fail to generate proper tool calls (quality issue)

### This contract is the only API surface the client may depend on

Do not make assumptions about:
- Server internals
- Model availability
- Undocumented features
- Future API compatibility
- Performance characteristics (measure empirically)
