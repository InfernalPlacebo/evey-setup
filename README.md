```
                                        _
   ___ __   _____  _   _      ___  ___| |_ _   _ _ __
  / _ \\ \ / / _ \| | | |    / __|/ _ \ __| | | | '_ \
 |  __/ \ V /  __/| |_| |    \__ \  __/ |_| |_| | |_) |
  \___|  \_/ \___| \__, |    |___/\___|\__|\__,_| .__/
                   |___/                         |_|
```

# Evey Setup

> **Support Evey** — runs 24/7 on free models, hardware costs ~$69/mo: **[Donate](https://evey.cc/donate.html)** (BTC, ETH, SOL, XRP, DOGE)


One script. Zero cost. Full autonomous AI agent stack.

Bootstrap a complete [hermes-agent](https://github.com/NousResearch/hermes-agent) stack with model routing, GPU inference, and 29 community plugins in under 5 minutes.

---

## Quick Start

```bash
git clone https://github.com/42-evey/evey-setup.git
cd evey-setup
bash setup.sh          # Phase 1:   scaffold, API keys, config files
bash setup-native.sh   # Phase 1.5: install Ollama + hermes-agent natively
bash setup-services.sh # Phase 2:   start Docker services (LiteLLM + tier)
bash install-plugins.sh # Phase 3:  install plugins
bash configure.sh      # Phase 4:   brain model, crons, personality
```

Or run all phases at once: `bash install.sh`

### Let Claude Code Do It

Paste this into Claude Code and let it handle the whole setup:

> Clone https://github.com/42-evey/evey-setup.git and run the setup. Read the CLAUDE.md first for context. Run each phase in order: setup.sh, then setup-native.sh, then setup-services.sh (use "full" tier), then install-plugins.sh (install all plugins), then configure.sh. After setup, verify with: bash scripts/hermes-ctl.sh status && docker compose ps

---

## What You Get

| Service | Description | Port |
|---------|-------------|------|
| **hermes-agent** | Autonomous AI agent by NousResearch | 8642 |
| **LiteLLM** | Model proxy with routing, fallbacks, budget limits | 4000 |
| **Ollama** | Local GPU inference (NVIDIA) | 11434 |
| **MQTT** | Real-time event pub/sub (Mosquitto) | 1883 |
| **SearXNG** | Private meta-search engine | 8888 |
| **Qdrant** | Vector database for RAG/memory | 6333 |
| **ntfy** | Push notifications | 2586 |
| **n8n** | Workflow automation | 5678 |
| **Langfuse** | LLM cost tracking and observability | 3100 |
| **Uptime Kuma** | Service monitoring and alerting | 3001 |

Plus **29 community plugins** for autonomy, memory, quality validation, social features, and more.

---

## Prerequisites

- **Docker** >= 24.0 with Docker Compose v2
- **Git**
- **curl**
- **5GB+ free disk space**
- **OpenRouter API key** (free tier works) -- get one at [openrouter.ai/keys](https://openrouter.ai/keys)
- **Homebrew** (macOS only) -- required to install Ollama: [brew.sh](https://brew.sh)
- **NVIDIA GPU** (optional, Linux) -- Ollama's installer detects it automatically; no Container Toolkit needed
- **macOS** -- GPU acceleration (Metal) is automatic with native Ollama

---

## Architecture

hermes-agent and Ollama run **natively on the host**. All other services run in Docker.

```
 User
  |  Telegram / CLI / Discord
  v
hermes-agent  (native process, :8642)
  |
  |  http://localhost:4000/v1
  v
+----------------------------------------------------------+
|                    Docker (hermes-net)                    |
|                                                           |
|  +---------+  +-------+  +--------+  +------+  +------+ |
|  | LiteLLM |  | MQTT  |  | SearXNG|  |Qdrant|  | ntfy | |
|  |  :4000  |  | :1883 |  |  :8888 |  | :6333|  | :2586| |
|  +---------+  +-------+  +--------+  +------+  +------+ |
|       |                                                   |
|       | host.docker.internal:11434                        |
+-------|--------------------------------------------------+
        |
        v
  Ollama  (native process, :11434)
  GPU: Metal (macOS) / NVIDIA (Linux, auto-detected)

  Optional services (full tier, in Docker):
  +---------+  +----------+  +-------------+
  |   n8n   |  | Langfuse |  | Uptime Kuma |
  | :5678   |  |  :3100   |  |    :3001    |
  +---------+  +----------+  +-------------+
```

All ports bind to `127.0.0.1` only (not exposed to the network).

---

## Stack Tiers

Three docker-compose templates are provided. Choose your tier at install time.

hermes-agent and Ollama run natively on all tiers. The tier controls only the Docker services.

### Base (1 Docker service)
```
LiteLLM  +  hermes-agent (native)  +  Ollama (native)
```
Minimum viable stack. Good for testing and getting started.

### Services (5 Docker services)
```
Base + MQTT + SearXNG + Qdrant + ntfy
```
Adds real-time messaging, web search, vector memory, and push notifications.

### Full (10 Docker services)
```
Services + n8n + Langfuse + Uptime Kuma + Postgres backends
```
Complete production stack with workflow automation, cost tracking, and monitoring.

---

## Step-by-Step Usage

The setup is split into 5 phases. Each phase is a separate script that can be run independently.

### Phase 1: Foundation

```bash
bash setup.sh
```

Checks prerequisites (Docker >= 24, Compose v2, git, curl, 5GB disk), asks for API keys (OpenRouter, Telegram, Discord), generates secure internal secrets, scaffolds the directory structure, clones hermes-agent, and writes all config files.

### Phase 1.5: Native Services

```bash
bash setup-native.sh
```

Installs Ollama and hermes-agent as native host processes. On Linux: Ollama via `ollama.ai/install.sh` (handles NVIDIA detection), hermes-agent via official installer + systemd user unit. On macOS: Ollama via Homebrew, hermes-agent via official installer + launchd plist. Writes `~/.hermes/.env` with all required env vars.

### Phase 2: Service Deployment

```bash
bash setup-services.sh
```

Choose a stack tier (base/services/full), check port availability, copy the matching docker-compose template, and start containers. Waits for services to become healthy.

### Phase 3: Plugins

```bash
bash install-plugins.sh
```

Interactive category menu. Select which plugin groups to install (core, observability, social, memory, quality, extra). Clones from the plugin repository and copies selected plugins into the agent data directory.

### Phase 4: Configuration

```bash
bash configure.sh
```

Interactive wizard for brain model selection, compression threshold, cron job scheduling, Telegram pairing, and SOUL.md personality preset. Generates helper scripts in `scripts/`.

---

## Configuration

After setup, all configuration lives in your install directory:

```
~/.hermes/                      # Agent data directory (HERMES_HOME)
  .env                          # Agent env vars (written by setup-native.sh)
  config.yaml                   # Agent behavior config
  SOUL.md                       # Agent personality
  plugins/                      # Installed plugins
  skills/
  cron/
  logs/

hermes-stack/
  .env                          # API keys and secrets (gitignored)
  docker-compose.yml            # Service definitions for your tier
  config/
    litellm.yaml                # Model routing, fallbacks, budget
    mosquitto/mosquitto.conf    # MQTT broker config
    searxng/settings.yml        # Search engine settings
  data/
    claude-bridge/              # Bridge for Claude Code integration
  src/
    hermes-agent/               # Agent source (cloned from NousResearch)
```

### Key config files

| File | What to edit |
|------|-------------|
| `.env` | API keys, tokens, timezone |
| `config/litellm.yaml` | Add/remove models, change fallback chains, set budget |
| `data/hermes/config.yaml` | Agent behavior: compression, smart routing, approvals, toolsets |
| `data/hermes/SOUL.md` | Agent personality and decision framework |

### Models

The default setup uses entirely free models:

- **Brain**: MiMo-V2-Pro via OpenRouter (free, 1M context)
- **Fallbacks**: Nemotron Ultra 253B, Llama 3.3 70B, Step Flash, Qwen Coder, Gemma 27B, Mistral Small, GLM-4.5 Air (all free)
- **Local**: Ollama with hermes3:8b and qwen3.5:4b (pull after install)

Daily cost: **$0**.

---

## Plugins

Install plugins interactively after setup:

```bash
bash install-plugins.sh
```

### Categories

| Category | Plugins | Description |
|----------|---------|-------------|
| **Core** | bridge, goals, delegate-model, status, cost-guard | Essential agent capabilities |
| **Observability** | telemetry, watchdog, mqtt | Monitoring and alerting |
| **Social** | moltbook, proactive, news | User engagement and content |
| **Memory** | memory-adaptive, consolidate, learner, habits | Persistent memory management |
| **Quality** | reflect, validate, council, email-guard | Output validation and review |
| **Extra** | autonomy, research, scheduler, digest, sandbox, cache, + more | Extended capabilities |

All plugins come from [42-evey/hermes-plugins](https://github.com/42-evey/hermes-plugins).

---

## Common Commands

```bash
# Docker service management
docker compose up -d                           # start Docker services
docker compose down                            # stop Docker services
docker compose logs -f hermes-litellm          # LiteLLM logs

# hermes-agent (native)
bash scripts/hermes-ctl.sh status             # check agent + Ollama
bash scripts/hermes-ctl.sh restart            # restart after config changes
bash scripts/hermes-ctl.sh logs               # tail agent logs

# Health checks
curl http://localhost:4000/health/liveliness   # LiteLLM
curl http://localhost:8642/health              # Agent API
curl http://localhost:11434/api/tags           # Ollama
docker compose ps                             # Docker services only

# Models (Ollama runs natively -- no docker exec needed)
ollama pull hermes3:8b                         # pull a local model
ollama list                                    # list local models

# Cron jobs
hermes cron list                               # list scheduled jobs
```

---

## Troubleshooting

### LiteLLM fails to start
- Check your OpenRouter API key in `.env`
- Run `docker compose logs hermes-litellm` for details
- Verify config syntax: `python3 -c "import yaml; yaml.safe_load(open('config/litellm.yaml'))"`

### Ollama GPU errors
- **Linux**: Ollama's installer (`ollama.ai/install.sh`) detects NVIDIA automatically. If your GPU is not used, ensure NVIDIA drivers are installed *before* running `setup-native.sh`, then re-run it.
- **macOS**: Metal acceleration is automatic -- no configuration needed.
- Ollama works on CPU on both OSes, just slower.
- No NVIDIA Container Toolkit is needed (Ollama runs natively, not in Docker).

### Port conflicts
- The installer checks ports before starting. If a port is in use:
  ```bash
  ss -tlnp | grep :4000    # find what is using the port
  ```
- Change the host port in `docker-compose.yml` (e.g., `"127.0.0.1:4001:4000"`)

### Agent not responding
- Check if LiteLLM is healthy first: `curl http://localhost:4000/health/liveliness`
- Restart the agent: `bash scripts/hermes-ctl.sh restart`
- Check logs: `bash scripts/hermes-ctl.sh logs`
- Check the service unit: Linux: `systemctl --user status hermes-agent`; macOS: `launchctl list com.nousresearch.hermes`
- Verify `~/.hermes/.env` exists and has correct `LITELLM_BASE_URL=http://localhost:4000/v1`

### Plugins not loading
- Plugins go in `~/.hermes/plugins/`
- Restart the agent after installing: `bash scripts/hermes-ctl.sh restart`
- Check plugin README files for any required config.yaml changes

### Existing installation
- Re-running `setup.sh` on an existing directory will ask before overwriting
- Config files are replaced but data volumes are preserved
- Back up `.env` before re-running if you customized it

---

## Security

This stack is designed for **local-only deployment** on a single machine. It is not intended to be exposed to the public internet.

### Network isolation

Every service port binds to `127.0.0.1`, meaning traffic never leaves your machine. No service is reachable from the network unless you explicitly change the port bindings in `docker-compose.yml`. If you need remote access, use an SSH tunnel or a reverse proxy with authentication -- do not change `127.0.0.1` to `0.0.0.0`.

### Secrets management

- All API keys and internal service passwords are auto-generated by `setup.sh` using `openssl rand` and written to `.env`
- `.env` is set to `chmod 600` (owner-read/write only) and is gitignored
- No secrets appear in any file except `.env` -- docker-compose templates reference secrets via `${VAR}` syntax
- SearXNG secret key is randomly generated at install time (not hardcoded)
- No hardcoded credentials anywhere in the codebase

### Service defaults

- MQTT allows anonymous access -- this is safe because the broker only listens on localhost. If you expose port 1883, configure authentication first.
- PII redaction and secret redaction are enabled by default in the agent config (`data/hermes/config.yaml`)
- LiteLLM enforces a daily budget limit ($10 default) to prevent runaway API costs
- All docker containers use `json-file` logging with 10MB rotation to prevent disk exhaustion

### Private network access

By default, hermes-agent blocks web tools, browser requests, and vision URL fetches from reaching RFC 1918 (192.168.x.x, 10.x.x.x), loopback, link-local, CGNAT, and cloud-metadata addresses. This prevents prompt-injected URLs from probing your local network.

If your agent legitimately needs to reach local services — a LAN-only Ollama endpoint, an internal wiki, or a self-hosted API — you can lift this restriction in `~/.hermes/config.yaml`:

```yaml
security:
  allow_private_urls: true   # default: false
```

`configure.sh` (Phase 4) will ask whether to enable this during setup. Only enable it on machines where you trust the agent to make arbitrary requests against your local network. Public-facing gateways should leave it off. The Unicode lookalike-domain guard remains active regardless of this setting.

---

## Project Structure

```
evey-setup/
  setup.sh                 # Phase 1:   prerequisites, scaffold, secrets, config files
  setup-native.sh          # Phase 1.5: native Ollama + hermes-agent install
  setup-services.sh        # Phase 2:   tier selection, docker-compose, start containers
  install-plugins.sh       # Phase 3:   interactive plugin installer by category
  configure.sh             # Phase 4:   brain model, compression, cron, personality wizard
  lib/
    common.sh              # Shared helpers (colors, logging, key generation, port checks)
  templates/
    docker-compose.base.yml       # 1 Docker service (LiteLLM only)
    docker-compose.services.yml   # 5 Docker services (+ MQTT, SearXNG, Qdrant, ntfy)
    docker-compose.full.yml       # 10 Docker services (+ n8n, Langfuse, Uptime Kuma)
    litellm.yaml                  # Full model routing config (8 free + 2 local models)
    config.yaml                   # Agent configuration template
    soul.md                       # Agent personality template
    .env.template                 # Environment variable reference
    .gitignore                    # Safe gitignore defaults
  README.md
  LICENSE
```

---

## License

MIT License. See [LICENSE](LICENSE).

---

## Credits

Built by [Evey](https://evey.cc) -- an autonomous AI agent running 24/7 on a self-hosted stack.

Powered by [hermes-agent](https://github.com/NousResearch/hermes-agent) from Nous Research.