#!/bin/bash
# setup.sh — Install or reinstall NanoClaw on the Beelink homelab
# Run as jkeyser (not root)
set -euo pipefail

NANOCLAW_DIR="/home/jkeyser/nanoclaw"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== NanoClaw Setup ==="

# Clone if not present
if [ ! -d "$NANOCLAW_DIR" ]; then
  echo "Cloning NanoClaw..."
  git clone https://github.com/qwibitai/nanoclaw "$NANOCLAW_DIR"
fi

# Install dependencies
echo "Installing npm dependencies..."
cd "$NANOCLAW_DIR"
npm install

# Apply Telegram skill
echo "Applying Telegram channel skill..."
npx tsx scripts/apply-skill.ts --init 2>/dev/null || true
npx tsx scripts/apply-skill.ts .claude/skills/add-telegram

# Create .env if not present
if [ ! -f "$NANOCLAW_DIR/.env" ]; then
  echo "Creating .env..."
  cp "$SCRIPT_DIR/env.example" "$NANOCLAW_DIR/.env"
fi

# Sync env to container path
mkdir -p "$NANOCLAW_DIR/data/env"
cp "$NANOCLAW_DIR/.env" "$NANOCLAW_DIR/data/env/env"

# Build TypeScript
echo "Building TypeScript..."
npm run build

# Build Docker container image
echo "Building Docker container image..."
bash "$NANOCLAW_DIR/container/build.sh"

# Install systemd unit
echo "Installing systemd user unit..."
mkdir -p "$SYSTEMD_USER_DIR"
cp "$SCRIPT_DIR/nanoclaw.service" "$SYSTEMD_USER_DIR/nanoclaw.service"
systemctl --user daemon-reload
systemctl --user enable nanoclaw
systemctl --user restart nanoclaw

echo ""
echo "=== Setup Complete ==="
echo "Service status: $(systemctl --user is-active nanoclaw)"
echo ""
echo "NEXT STEP: Set TELEGRAM_BOT_TOKEN in $NANOCLAW_DIR/.env"
echo "See nanoclaw/README.md for Telegram bot setup instructions."
