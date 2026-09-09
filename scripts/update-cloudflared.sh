#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_SOURCE="$REPO_DIR/cloudflared/config.yml"
CONFIG_DESTINATION="/etc/cloudflared/config.yml"
KEYRING_DESTINATION="/usr/share/keyrings/cloudflare-main.gpg"
APT_SOURCE_DESTINATION="/etc/apt/sources.list.d/cloudflared.list"

if [ ! -f "$CONFIG_SOURCE" ]; then
  echo "Missing tracked cloudflared config: $CONFIG_SOURCE" >&2
  exit 1
fi

temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT

echo "Installing the official Cloudflare package source..."
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
  -o "$temporary_dir/cloudflare-main.gpg"
printf '%s\n' \
  'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' \
  > "$temporary_dir/cloudflared.list"
sudo install -m 0644 "$temporary_dir/cloudflare-main.gpg" "$KEYRING_DESTINATION"
sudo install -m 0644 "$temporary_dir/cloudflared.list" "$APT_SOURCE_DESTINATION"

echo "Installing the latest cloudflared package..."
sudo apt-get update
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y cloudflared

echo "Validating the tracked ingress configuration..."
cloudflared tunnel --config "$CONFIG_SOURCE" ingress validate

credentials_file="$(awk '$1 == "credentials-file:" { print $2; exit }' "$CONFIG_SOURCE")"
if [ -z "$credentials_file" ] || [ ! -f "$credentials_file" ]; then
  echo "Missing tunnel credentials file declared by $CONFIG_SOURCE" >&2
  exit 1
fi

echo "Installing ingress configuration and restarting cloudflared..."
if [ -f "$CONFIG_DESTINATION" ]; then
  sudo install -m 0644 "$CONFIG_DESTINATION" "${CONFIG_DESTINATION}.previous"
fi
sudo install -m 0644 "$CONFIG_SOURCE" "$CONFIG_DESTINATION"
sudo systemctl restart cloudflared.service
sudo systemctl is-active --quiet cloudflared.service

cloudflared --version
echo "cloudflared is active with the tracked ingress configuration."
