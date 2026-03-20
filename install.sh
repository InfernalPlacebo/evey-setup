#!/bin/bash
# Evey Stack Installer — runs all phases in sequence
# Usage: curl -sf https://raw.githubusercontent.com/42-evey/evey-setup/main/install.sh | bash
# Or: bash install.sh [install-dir]
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "  ╔══════════════════════════════════════════╗"
echo "  ║     Evey Stack — Complete Installer      ║"
echo "  ║  hermes-agent + LiteLLM + free models    ║"
echo "  ╚══════════════════════════════════════════╝"
echo ""

# If running from curl pipe, download all files first
if [ ! -f "$SCRIPT_DIR/setup.sh" ]; then
    echo "[install] Downloading setup files..."
    TMPDIR=$(mktemp -d)
    git clone --depth 1 https://github.com/42-evey/evey-setup.git "$TMPDIR/evey-setup" 2>/dev/null
    SCRIPT_DIR="$TMPDIR/evey-setup"
    cd "$SCRIPT_DIR"
fi

echo "[install] Phase 1/4 — Foundation (scaffold, .env, clone hermes)"
echo "────────────────────────────────────────────"
bash "$SCRIPT_DIR/setup.sh" "$@"

echo ""
echo "[install] Phase 2/4 — Services (Docker containers)"
echo "────────────────────────────────────────────"
bash "$SCRIPT_DIR/setup-services.sh"

echo ""
echo "[install] Phase 3/4 — Plugins"
echo "────────────────────────────────────────────"
bash "$SCRIPT_DIR/install-plugins.sh"

echo ""
echo "[install] Phase 4/4 — Configuration"
echo "────────────────────────────────────────────"
bash "$SCRIPT_DIR/configure.sh"

echo ""
echo "  ╔══════════════════════════════════════════╗"
echo "  ║          Installation Complete!          ║"
echo "  ║                                          ║"
echo "  ║  Your agent is running. Talk to it:      ║"
echo "  ║    hermes          (CLI)                 ║"
echo "  ║    Telegram        (if configured)       ║"
echo "  ║                                          ║"
echo "  ║  Dashboard:  http://localhost:8642       ║"
echo "  ║  Docs:       github.com/42-evey          ║"
echo "  ╚══════════════════════════════════════════╝"
