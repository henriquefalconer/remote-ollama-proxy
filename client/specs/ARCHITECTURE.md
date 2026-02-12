# self-sovereign-ollama ai-client Architecture (v2.0.0)

## Responsibilities of self-sovereign-ollama ai-client

- Install and configure WireGuard VPN client
- Generate WireGuard keypair and send public key to admin
- Create and source environment variables that exactly match the self-sovereign-ollama ai-server API contract (see API_CONTRACT.md)
- Install and configure AI coding tools (Aider, optionally Claude Code)
- Provide optional Ollama backend integration (alternative to Anthropic cloud API for Claude Code)
- Provide analytics infrastructure for measuring tool performance
- Provide version compatibility management between client tools and server
- Provide clean uninstallation
- Document the API contract so future interfaces can be added without changing the installer

## Responsibilities of self-sovereign-ollama ai-server (from client perspective)

- Guarantee the exact HTTP contract in API_CONTRACT.md
- Support both OpenAI-compatible API (for Aider) and Anthropic-compatible API (for Claude Code)
- Be reachable at static DMZ IP (default: `192.168.100.10`)
- Accept connections only from authorized VPN clients (WireGuard peers)

## Client Runtime

- No daemon, no wrapper binary, no persistent process
- Only environment configuration + WireGuard VPN + tool installation
- All API calls are performed by the user-chosen interface (Aider, Claude Code, or other compatible tools)
- **VPN requirement**: WireGuard VPN must be connected to reach server

## Supported Interfaces

### Primary

**Aider** - OpenAI-compatible CLI coding assistant
- Uses `OPENAI_API_BASE` and `OLLAMA_API_BASE` environment variables
- Connects to Ollama's OpenAI-compatible `/v1` endpoints
- Installed via pipx

### Extended

**Claude Code** - Anthropic-native CLI coding assistant with advanced orchestration
- Uses `ANTHROPIC_BASE_URL` environment variable
- Connects to Ollama's Anthropic-compatible `/v1/messages` endpoint
- Can use either Anthropic cloud API (default) or local Ollama server (optional)
- Supports Ralph loops (PROMPT_plan.md / PROMPT_build.md) for autonomous multi-agent workflows
- Analytics infrastructure provided for measuring empirical performance

**Backend Options for Claude Code:**
1. **Anthropic Cloud API** (default, recommended)
   - Full model capabilities (Opus 4.6, Sonnet 4.5)
   - Prompt caching support
   - Distributed infrastructure (high parallelism)
   - Pay-per-use pricing

2. **Local Ollama Server** (optional, experimental)
   - Privacy (all inference on private network)
   - No API costs
   - Lower quality models (qwen3-coder, glm-4.7, etc.)
   - No prompt caching
   - Limited parallelism (single server queuing)
   - Best for: simple tasks, file reads, quick edits
   - Not recommended for: Ralph loops with high parallelism

## Architecture Principles

- **Tool agnostic**: Environment setup works with any OpenAI or Anthropic-compatible tool
- **Empirical measurement**: Analytics infrastructure for validating assumptions about workload characteristics
- **Version stability**: Compatibility checking prevents breaking changes from tool updates
- **Hybrid flexibility**: Claude Code can use Anthropic cloud API (quality) and Ollama (privacy) selectively

## Out of Scope

- Any code that makes direct HTTP calls
- Linux/Windows installers
- IDE plugins
- Custom auth beyond WireGuard VPN + dummy API key
- Built-in model serving (server responsibility)
- Load balancing across multiple Ollama servers (would require separate orchestration layer)
