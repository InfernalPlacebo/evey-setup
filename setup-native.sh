#!/bin/bash
# Hermes Agent Stack Setup — Phase 1.5: Native Services
# Installs Ollama and hermes-agent natively on the host.
# Ollama:        Linux via ollama.ai/install.sh (systemd + NVIDIA auto-detect)
#                macOS via Homebrew (launchd via brew services)
# hermes-agent:  Both OSes via hermes-agent.nousresearch.com/install.sh
#                Linux: hermes gateway install (systemd user unit)
#                macOS: launchd plist at ~/Library/LaunchAgents/
#
# Usage: bash setup-native.sh
# Prev:  bash setup.sh
# Next:  bash setup-services.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# ── Banner ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}"
echo "  ============================================"
echo "   Hermes Agent Stack Setup — Phase 1.5 of 4"
echo "         Native Services Installation"
echo "  ============================================"
echo -e "${NC}"

# ── OS detection ────────────────────────────────────────────────────────────
OS="$(uname -s)"
if [ "$OS" != "Linux" ] && [ "$OS" != "Darwin" ]; then
    err "Unsupported OS: $OS (supported: Linux, Darwin/macOS)"
    exit 1
fi
log "OS: $OS"

# ── Resolve install dir and load stack .env ──────────────────────────────────
INSTALL_DIR="$(resolve_install_dir)"
if [ ! -f "$INSTALL_DIR/.env" ]; then
    err "Stack .env not found at $INSTALL_DIR/.env"
    err "Run setup.sh first."
    exit 1
fi

log "Install directory: $INSTALL_DIR"

# Load stack .env into current shell so variables are available for heredoc expansion
set -a
# shellcheck disable=SC1090
source "$INSTALL_DIR/.env"
set +a

# ── hermes paths ─────────────────────────────────────────────────────────────
HERMES_HOME_DIR="${HERMES_HOME:-$HOME/.hermes}"
HERMES_BIN="$HERMES_HOME_DIR/bin/hermes"

echo ""

# ════════════════════════════════════════════════════════════════════════════
# OLLAMA
# ════════════════════════════════════════════════════════════════════════════

log "Installing Ollama..."

if command -v ollama &>/dev/null; then
    log "  Ollama already installed: $(ollama --version 2>/dev/null | head -1 || echo 'version unknown')"
else
    if [ "$OS" = "Linux" ]; then
        log "  Running Ollama Linux installer (may require sudo)..."
        curl -fsSL https://ollama.ai/install.sh | sh
    elif [ "$OS" = "Darwin" ]; then
        if ! command -v brew &>/dev/null; then
            err "Homebrew is required on macOS to install Ollama."
            err "Install it first: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            exit 1
        fi
        brew install ollama
    fi
fi

log "Starting Ollama service..."
if [ "$OS" = "Linux" ]; then
    if command -v systemctl &>/dev/null; then
        sudo systemctl enable ollama 2>/dev/null || true
        sudo systemctl start ollama  2>/dev/null || true
    fi
elif [ "$OS" = "Darwin" ]; then
    brew services start ollama 2>/dev/null || true
fi

log "Waiting for Ollama to be ready (up to 30s)..."
TRIES=0
OLLAMA_UP=0
while [ $TRIES -lt 6 ]; do
    if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
        OLLAMA_UP=1
        break
    fi
    TRIES=$(( TRIES + 1 ))
    sleep 5
done

if [ "$OLLAMA_UP" -eq 1 ]; then
    log "  Ollama is up: http://localhost:11434"
else
    warn "  Ollama did not respond in 30s — it may still be starting. Continuing."
fi

echo ""

# ════════════════════════════════════════════════════════════════════════════
# HERMES-AGENT BINARY
# ════════════════════════════════════════════════════════════════════════════

log "Installing hermes-agent..."

if [ -f "$HERMES_BIN" ]; then
    log "  hermes-agent already installed at $HERMES_BIN"
else
    log "  Running hermes-agent installer..."
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup
    # Installer may add ~/.hermes/bin to PATH only after shell reload.
    # Use full path for all subsequent hermes calls.
    export PATH="$HERMES_HOME_DIR/bin:$PATH"
fi

if [ ! -f "$HERMES_BIN" ]; then
    err "hermes binary not found at $HERMES_BIN after installation."
    err "Check the installer output above for errors."
    exit 1
fi

log "  hermes binary: $HERMES_BIN"

echo ""

# ════════════════════════════════════════════════════════════════════════════
# WRITE ~/.hermes/.env
# ════════════════════════════════════════════════════════════════════════════

log "Writing $HERMES_HOME_DIR/.env..."
mkdir -p "$HERMES_HOME_DIR/logs"

cat > "$HERMES_HOME_DIR/.env" << HENVEOF
# Written by evey-setup setup-native.sh
# Re-run setup-native.sh to regenerate from $INSTALL_DIR/.env
# hermes-agent connects to LiteLLM on localhost (not the Docker network name)
HERMES_PROVIDER=litellm
LITELLM_BASE_URL=http://localhost:4000/v1
LITELLM_KEY=${LITELLM_MASTER_KEY:-}
OPENAI_BASE_URL=http://localhost:4000/v1
OPENAI_API_KEY=${LITELLM_MASTER_KEY:-}
OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:-}
DISCORD_BOT_TOKEN=${DISCORD_BOT_TOKEN:-}
API_SERVER_ENABLED=true
API_SERVER_PORT=8642
API_SERVER_HOST=0.0.0.0
API_SERVER_KEY=${API_SERVER_KEY:-}
SESSION_IDLE_MINUTES=240
SESSION_RESET_HOUR=3
TZ=${TZ:-UTC}
# Native Ollama settings
OLLAMA_KEEP_ALIVE=30m
OLLAMA_MAX_LOADED_MODELS=2
OLLAMA_NUM_PARALLEL=2
OLLAMA_FLASH_ATTENTION=1
# Services-tier and above (Docker ports exposed on localhost)
MQTT_HOST=localhost
MQTT_PORT=1883
SEARXNG_URL=http://localhost:8888
QDRANT_URL=http://localhost:6333
# Full-tier only
LANGFUSE_HOST=http://localhost:3100
LANGFUSE_PUBLIC_KEY=${LANGFUSE_PUBLIC_KEY:-}
LANGFUSE_SECRET_KEY=${LANGFUSE_SECRET_KEY:-}
HENVEOF

chmod 600 "$HERMES_HOME_DIR/.env"
log "  Written and chmod 600"

echo ""

# ════════════════════════════════════════════════════════════════════════════
# REGISTER HERMES-AGENT SERVICE
# ════════════════════════════════════════════════════════════════════════════

log "Registering hermes-agent service..."

if [ "$OS" = "Linux" ]; then
    # hermes gateway install creates a systemd user unit and starts it.
    if "$HERMES_BIN" gateway install 2>/dev/null; then
        log "  systemd user unit installed"
    else
        warn "  hermes gateway install failed — check systemd --user availability"
        warn "  You can start manually: $HERMES_BIN gateway"
    fi

    # Inject EnvironmentFile so systemd reads our .env on start.
    UNIT_FILE="$HOME/.config/systemd/user/hermes-agent.service"
    if [ -f "$UNIT_FILE" ] && ! grep -q "EnvironmentFile" "$UNIT_FILE"; then
        sed -i "/^\[Service\]/a EnvironmentFile=$HERMES_HOME_DIR/.env" "$UNIT_FILE"
        systemctl --user daemon-reload
        systemctl --user restart hermes-agent 2>/dev/null || true
        log "  EnvironmentFile=$HERMES_HOME_DIR/.env added to unit"
    fi

elif [ "$OS" = "Darwin" ]; then
    PLIST_DIR="$HOME/Library/LaunchAgents"
    PLIST_FILE="$PLIST_DIR/com.nousresearch.hermes.plist"
    mkdir -p "$PLIST_DIR"
    mkdir -p "$HERMES_HOME_DIR/logs"

    # Unload any existing plist before overwriting
    if launchctl list com.nousresearch.hermes > /dev/null 2>&1; then
        launchctl unload "$PLIST_FILE" 2>/dev/null || true
        log "  Unloaded existing LaunchAgent"
    fi

    # Write plist. Shell wrapper sources ~/.hermes/.env before exec so all
    # env vars are available to the hermes process.
    cat > "$PLIST_FILE" << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.nousresearch.hermes</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>-c</string>
    <string>set -a; . "${HERMES_HOME_DIR}/.env"; set +a; exec "${HERMES_BIN}" gateway</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${HERMES_HOME_DIR}/logs/gateway.log</string>
  <key>StandardErrorPath</key>
  <string>${HERMES_HOME_DIR}/logs/gateway.log</string>
</dict>
</plist>
PLISTEOF

    launchctl load "$PLIST_FILE"
    log "  LaunchAgent loaded: $PLIST_FILE"
fi

echo ""

# ════════════════════════════════════════════════════════════════════════════
# WAIT FOR HERMES-AGENT
# ════════════════════════════════════════════════════════════════════════════

log "Waiting for hermes-agent to be ready (up to 60s)..."
TRIES=0
HERMES_UP=0
while [ $TRIES -lt 12 ]; do
    if curl -sf http://localhost:8642/health > /dev/null 2>&1; then
        HERMES_UP=1
        break
    fi
    TRIES=$(( TRIES + 1 ))
    sleep 5
done

if [ "$HERMES_UP" -eq 1 ]; then
    log "  hermes-agent is up: http://localhost:8642"
else
    warn "  hermes-agent did not respond in 60s — it may still be starting."
    warn "  Check logs: bash $INSTALL_DIR/scripts/hermes-ctl.sh logs"
fi

echo ""

# ════════════════════════════════════════════════════════════════════════════
# WRITE hermes-ctl.sh
# ════════════════════════════════════════════════════════════════════════════

log "Writing scripts/hermes-ctl.sh..."
mkdir -p "$INSTALL_DIR/scripts"

cat > "$INSTALL_DIR/scripts/hermes-ctl.sh" << 'CTLEOF'
#!/bin/bash
# hermes-agent lifecycle management — generated by setup-native.sh
# Usage: bash scripts/hermes-ctl.sh {start|stop|restart|status|logs}
set -euo pipefail

OS="$(uname -s)"
CMD="${1:-status}"

case "$CMD" in
    start)
        if [ "$OS" = "Linux" ]; then
            systemctl --user start hermes-agent
        else
            launchctl start com.nousresearch.hermes
        fi
        echo "hermes-agent started."
        ;;
    stop)
        if [ "$OS" = "Linux" ]; then
            systemctl --user stop hermes-agent
        else
            launchctl stop com.nousresearch.hermes
        fi
        echo "hermes-agent stopped."
        ;;
    restart)
        if [ "$OS" = "Linux" ]; then
            systemctl --user restart hermes-agent
        else
            launchctl stop com.nousresearch.hermes 2>/dev/null || true
            sleep 2
            launchctl start com.nousresearch.hermes
        fi
        echo "hermes-agent restarted."
        ;;
    status)
        echo "=== Service ==="
        if [ "$OS" = "Linux" ]; then
            systemctl --user status hermes-agent --no-pager 2>/dev/null || echo "  Service not found"
        else
            launchctl list com.nousresearch.hermes 2>/dev/null || echo "  Service not running"
        fi
        echo ""
        echo "=== API Health ==="
        if curl -sf http://localhost:8642/health > /dev/null 2>&1; then
            echo "  hermes-agent: OK  (http://localhost:8642)"
        else
            echo "  hermes-agent: NOT RESPONDING (http://localhost:8642)"
        fi
        echo ""
        echo "=== Ollama ==="
        if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
            echo "  ollama: OK  (http://localhost:11434)"
        else
            echo "  ollama: NOT RESPONDING (http://localhost:11434)"
        fi
        ;;
    logs)
        if [ "$OS" = "Linux" ]; then
            journalctl --user -u hermes-agent -f
        else
            tail -f "${HERMES_HOME:-$HOME/.hermes}/logs/gateway.log"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        exit 1
        ;;
esac
CTLEOF

chmod +x "$INSTALL_DIR/scripts/hermes-ctl.sh"
log "  Written: $INSTALL_DIR/scripts/hermes-ctl.sh"

# ════════════════════════════════════════════════════════════════════════════
# DONE
# ════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}"
echo "  ============================================"
echo "   Phase 1.5 Complete — Native Services"
echo "  ============================================"
echo -e "${NC}"
echo "  Ollama:         http://localhost:11434"
echo "  hermes-agent:   http://localhost:8642"
echo "  Agent data:     $HERMES_HOME_DIR/"
echo ""
echo "  Service management:"
echo "    bash $INSTALL_DIR/scripts/hermes-ctl.sh status"
echo "    bash $INSTALL_DIR/scripts/hermes-ctl.sh restart"
echo "    bash $INSTALL_DIR/scripts/hermes-ctl.sh logs"
echo ""
echo -e "  ${BOLD}Next: bash setup-services.sh${NC}"
echo "  Start Docker services (LiteLLM and optional tier services)."
echo ""
