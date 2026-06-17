# Design: Native hermes-agent and Ollama (Linux + macOS)

**Date:** 2026-06-16  
**Branch:** eval/claude  
**Status:** Approved

---

## Problem

hermes-agent and Ollama currently run as Docker containers. This prevents native GPU
acceleration (Metal on macOS, full NVIDIA on Linux without container toolkit), adds
container overhead to a latency-sensitive AI process, and makes the setup more complex
than necessary given both tools ship their own native installers.

## Goal

Move hermes-agent and Ollama out of Docker onto the host. All other services (LiteLLM,
MQTT, SearXNG, Qdrant, ntfy, n8n, Langfuse, Uptime Kuma, Postgres) stay containerized
and untouched.

---

## Approach: Lean on Official Installers

Call each tool's own native installer; supplement only where gaps exist.

- hermes-agent provides `curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash`  
  which installs Python 3.11 + uv, the `hermes` CLI, and (on Linux) a systemd user unit via
  `hermes gateway install`. macOS has no official launchd support — we write the plist.
- Ollama provides `curl -fsSL https://ollama.ai/install.sh | sh` on Linux (creates
  `/etc/systemd/system/ollama.service`, handles NVIDIA detection). On macOS:
  `brew install ollama && brew services start ollama` (Homebrew manages launchd).
- Docker containers reach native processes via `host.docker.internal` with
  `extra_hosts: ["host.docker.internal:host-gateway"]` added to every service (required
  on Linux Engine; harmless on macOS Desktop).

**Why this approach:** official tools own their service lifecycle (GPU detection, venv
paths, systemd units). We add ~50 lines of glue. Future `hermes update` and Ollama
updates work without touching our scripts.

---

## Data Layout

hermes-agent writes to `HERMES_HOME` (`~/.hermes/` by default). This is the standard
location the official installer expects and where `hermes update` looks. We do not
override it.

```
~/.hermes/
  config.yaml          # agent behavior (brain model, compression, etc.)
  .env                 # agent API keys (written by setup-native.sh from stack .env)
  plugins/             # installed plugins
  skills/
  cron/
  sessions/
  logs/
    gateway.log        # macOS fallback log

~/hermes-stack/        # INSTALL_DIR (unchanged)
  .env                 # stack secrets (source of truth)
  config/
    litellm.yaml       # updated: host.docker.internal:11434
  data/
    claude-bridge/     # still Docker-bind-mounted for LiteLLM/n8n access
  scripts/
    hermes-ctl.sh      # NEW: platform-aware start/stop/restart/status/logs
    setup-crons.sh     # updated: direct `hermes cron add` (no docker exec)
    pair-telegram.sh   # updated: direct `hermes pairing request`
  docker-compose.yml   # no hermes-agent or ollama blocks
```

---

## Setup Flow

```
bash setup.sh            # Phase 1 — unchanged: scaffold, .env, clone hermes source
bash setup-native.sh     # Phase 1.5 — NEW: install Ollama + hermes-agent natively
bash setup-services.sh   # Phase 2 — Docker-only (hermes-agent + Ollama removed)
bash install-plugins.sh  # Phase 3 — unchanged except restart command
bash configure.sh        # Phase 4 — unchanged except docker exec removed
```

---

## setup-native.sh (new script)

### OS detection

```bash
OS="$(uname -s)"   # "Linux" or "Darwin"
```

### Ollama installation

**Linux:**
```bash
curl -fsSL https://ollama.ai/install.sh | sh
# installer detects NVIDIA, creates /etc/systemd/system/ollama.service, starts it
systemctl is-active ollama   # verify
```

**macOS:**
```bash
# Require Homebrew — fail with install URL if missing
brew install ollama
brew services start ollama
```

### hermes-agent installation

**Both OSes:**
```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup
# --skip-setup skips interactive API key wizard (keys come from our .env)
```

**Linux — register systemd user unit:**
```bash
# The hermes binary lands in ~/.hermes/bin/ which may not be on PATH yet.
# Use the full path or source the shell profile first.
HERMES_BIN="${HERMES_HOME:-$HOME/.hermes}/bin/hermes"
"$HERMES_BIN" gateway install
```

**macOS — write launchd user agent:**
```xml
<!-- ~/Library/LaunchAgents/com.nousresearch.hermes.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>         <string>com.nousresearch.hermes</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>source ~/.hermes/.env && exec hermes gateway</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <!-- populated from $INSTALL_DIR/.env by setup-native.sh -->
  </dict>
  <key>RunAtLoad</key>     <true/>
  <key>KeepAlive</key>     <true/>
  <key>StandardOutPath</key> <string>/Users/USER/.hermes/logs/gateway.log</string>
  <key>StandardErrorPath</key><string>/Users/USER/.hermes/logs/gateway.log</string>
</dict>
</plist>
```
Then: `launchctl load ~/Library/LaunchAgents/com.nousresearch.hermes.plist`

### Environment injection

hermes-agent needs the same env vars previously passed via compose `environment:` block.
`setup-native.sh` reads `$INSTALL_DIR/.env` and:
- Linux: writes `~/.hermes/.env` (sourced by the systemd unit via `EnvironmentFile=`)
- macOS: writes the `EnvironmentVariables` dict in the plist before loading it

Variables written to `~/.hermes/.env`:
```
HERMES_PROVIDER=litellm
LITELLM_BASE_URL=http://localhost:4000/v1
LITELLM_KEY=<from stack .env>
OPENAI_BASE_URL=http://localhost:4000/v1
OPENAI_API_KEY=<from stack .env>
OPENROUTER_API_KEY=<from stack .env>
TELEGRAM_BOT_TOKEN=<from stack .env>
DISCORD_BOT_TOKEN=<from stack .env>
API_SERVER_ENABLED=true
API_SERVER_PORT=8642
API_SERVER_HOST=0.0.0.0
API_SERVER_KEY=<from stack .env>
SESSION_IDLE_MINUTES=240
SESSION_RESET_HOUR=3
# Services tier and above (written only when TIER != base)
MQTT_HOST=localhost
MQTT_PORT=1883
SEARXNG_URL=http://localhost:8888
QDRANT_URL=http://localhost:6333
# Full tier only
LANGFUSE_HOST=http://localhost:3100
LANGFUSE_PUBLIC_KEY=<from stack .env>
LANGFUSE_SECRET_KEY=<from stack .env>
OLLAMA_KEEP_ALIVE=30m
OLLAMA_MAX_LOADED_MODELS=2
OLLAMA_NUM_PARALLEL=2
OLLAMA_FLASH_ATTENTION=1
```

Note: `LITELLM_BASE_URL` changes from `http://hermes-litellm:4000/v1` (compose service
name) to `http://localhost:4000/v1` because hermes now runs on the host.

### Health checks

```bash
# Ollama
curl -sf http://localhost:11434/api/tags   # retry up to 30s

# hermes-agent
curl -sf http://localhost:8642/health     # retry up to 60s
```

### hermes-ctl.sh (generated by setup-native.sh)

Written to `$INSTALL_DIR/scripts/hermes-ctl.sh`. Platform-aware wrapper:

| Command | Linux | macOS |
|---------|-------|-------|
| `start` | `systemctl --user start hermes-agent` | `launchctl start com.nousresearch.hermes` |
| `stop` | `systemctl --user stop hermes-agent` | `launchctl stop com.nousresearch.hermes` |
| `restart` | `systemctl --user restart hermes-agent` | stop + start |
| `status` | `systemctl --user status hermes-agent` + curl health | `launchctl list com.nousresearch.hermes` + curl health |
| `logs` | `journalctl --user -u hermes-agent -f` | `tail -f ~/.hermes/logs/gateway.log` |

---

## Docker Compose Template Changes

### Remove from all three templates
- `hermes-agent` service block (entire block)
- `hermes-ollama` service block (entire block)
- `ollama-data` named volume
- `depends_on` entries for `hermes-ollama` in any remaining service

### Add to every remaining service in all three templates
```yaml
extra_hosts:
  - "host.docker.internal:host-gateway"
```
Required on Linux Docker Engine. Harmless on macOS Docker Desktop.

### litellm.yaml template — Ollama api_base
```yaml
# Before
api_base: http://hermes-ollama:11434
# After
api_base: http://host.docker.internal:11434
```
Applies to `hermes3-8b` and `qwen35-4b` model entries.

Also update the comment:
```yaml
# Pull models: ollama pull hermes3:8b
```

---

## setup-services.sh Changes

- Remove port checks for 8642 and 11434 (managed by `setup-native.sh`)
- Remove entire GPU detection block (Ollama handles this natively)
- Update service summary printout: hermes-agent and Ollama listed as "native (see setup-native.sh)"
- Health check at end still hits `http://localhost:8642/health` and `http://localhost:11434` — unchanged

---

## install-plugins.sh Changes

Replace the final restart instruction:
```bash
# Before
echo "  docker compose restart hermes-agent"
# After
echo "  bash $INSTALL_DIR/scripts/hermes-ctl.sh restart"
```

---

## configure.sh Changes

### setup-crons.sh generation
```bash
# Before: wait for docker exec to work
while [ $TRIES -lt 12 ]; do
    if docker exec "$CONTAINER" hermes cron list &>/dev/null; then

# After: wait for HTTP health endpoint
while [ $TRIES -lt 12 ]; do
    if curl -sf http://localhost:8642/health &>/dev/null; then
```

All `docker exec "$CONTAINER" hermes cron add` become `hermes cron add` directly.

### pair-telegram.sh generation
```bash
# Before
docker exec "$CONTAINER" hermes gateway setup
docker exec -it "$CONTAINER" hermes pairing request
# After
hermes gateway setup
hermes pairing request
```

### Restart guidance at end of configure.sh
```bash
# Before
echo "    docker compose restart hermes-agent"
# After
echo "    bash $INSTALL_DIR/scripts/hermes-ctl.sh restart"
```

---

## .env.template Changes

Add new variables (with comments explaining they apply to the native hermes-agent process):
```bash
# --- Native Ollama settings (applied to hermes-agent service unit) ---
OLLAMA_KEEP_ALIVE=30m
OLLAMA_MAX_LOADED_MODELS=2
OLLAMA_NUM_PARALLEL=2
OLLAMA_FLASH_ATTENTION=1
```

---

## README.md Changes

### Prerequisites
- Add: Homebrew (macOS, for Ollama install)
- Remove: NVIDIA Container Toolkit (GPU handled by Ollama's own installer)
- Add: curl (already present on both OSes — note it explicitly)

### Quick Start
Add `bash setup-native.sh` as Phase 1.5.

### Let Claude Code Do It paste-prompt
Include `setup-native.sh` in the phase sequence. Change final verify step from
`docker compose ps` to `bash scripts/hermes-ctl.sh status`.

### Architecture diagram
hermes-agent and Ollama appear outside the Docker box.

### Stack Tiers
Base tier: "hermes-agent (native) + LiteLLM (1 Docker service)". Clarify hermes-agent
and Ollama are native on all tiers.

### Common Commands
Replace `docker exec hermes-ollama ollama ...` with `ollama ...` directly.
Replace `docker compose restart hermes-agent` with `bash scripts/hermes-ctl.sh restart`.
Add `hermes-ctl.sh logs` for agent log tailing.

### Troubleshooting — Ollama GPU errors
Replace Docker `deploy:` block instructions with:
- Linux: ensure NVIDIA drivers are installed before running `setup-native.sh`
- macOS: Metal acceleration is automatic

### Troubleshooting — Agent not responding
Replace `docker compose restart hermes-agent` with `hermes-ctl.sh restart` and
`hermes-ctl.sh logs`.

---

## CLAUDE.md Changes

- Note hermes-agent and Ollama run natively (not in Docker)
- Replace `docker exec hermes-agent hermes cron list` → `hermes cron list`
- Replace `docker compose logs -f hermes-agent` → `bash scripts/hermes-ctl.sh logs`
- Add `~/.hermes/` as the agent data directory in the directory tree

---

## Acceptance Criteria

- On a clean Linux box: Ollama on :11434, hermes-agent on :8642, neither as a container;
  remaining tier services running in Docker and reaching both native services.
- On a clean macOS box: same.
- `docker compose ps` does not list hermes-agent or ollama containers.
- `grep -r "hermes-ollama\|hermes-agent" $INSTALL_DIR/docker-compose.yml` returns nothing.
- `ollama pull hermes3:8b` and `curl http://localhost:8642/health` both succeed
  without any container running for those services.

---

## Assumptions

1. hermes-agent's `--skip-setup` flag bypasses the interactive API key wizard. Verified
   in the official installer source: it is a documented flag.
2. `hermes gateway install` on Linux creates a user-level systemd unit (not system-level),
   so no `sudo` is needed for that step.
3. Ollama's macOS Homebrew formula (`brew install ollama`) is the standard install path
   and `brew services start ollama` manages launchd correctly. Verified: Homebrew formula
   exists and is maintained by the Ollama team.
4. `host.docker.internal` resolves correctly on macOS Docker Desktop without
   `extra_hosts`. The directive is added anyway (harmless) for consistency.
