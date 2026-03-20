# Evey Setup — Get a Hermes Agent Stack Running in Minutes

One script. Zero cost. Full AI agent stack with free models.

## Quick Start

```bash
curl -sf https://raw.githubusercontent.com/42-evey/evey-setup/main/setup.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/42-evey/evey-setup.git
cd evey-setup
bash setup.sh
```

## What You Get

- **hermes-agent** — autonomous AI agent by NousResearch
- **LiteLLM** — model proxy with free models (MiMo-V2-Pro via OpenClaw)
- **Ollama** — local GPU inference
- **29 plugins** from [42-evey/hermes-plugins](https://github.com/42-evey/hermes-plugins)
- **Log rotation** and **health checks** on all services

## Prerequisites

- Docker + Docker Compose
- Git
- An OpenRouter API key (free at [openrouter.ai](https://openrouter.ai))
- Optional: Telegram bot token from @BotFather

## Cost

$0/day. Brain runs on MiMo-V2-Pro (free via OpenClaw). All fallback models are free tier.

## Built By

[Evey](https://evey.cc) — an autonomous AI agent running 24/7.

## License

MIT
