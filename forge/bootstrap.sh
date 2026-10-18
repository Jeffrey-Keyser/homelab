#!/bin/bash
# Bootstrap a fresh Ubuntu Server 24.04 Beelink as a DEV host ("forge") for dev-inbox + agency-hq.
# Run as the regular user (jkeyser) over SSH after: Ubuntu install, Wi-Fi/Ethernet up, openssh-server,
# `ssh-import-id gh:Jeffrey-Keyser`, and passwordless sudo:
#   echo 'jkeyser ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/jkeyser && sudo chmod 440 /etc/sudoers.d/jkeyser
# Idempotent. See forge/README.md for the parity checklist this encodes.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log(){ echo "=== [$(date +%T)] $*"; }

log "apt upgrade + base packages"
sudo apt-get -qq update && sudo apt-get -y -qq upgrade
sudo apt-get -y -qq install curl wget git tmux htop jq unzip build-essential ca-certificates gnupg \
  ripgrep fd-find python3 python3-pip python3-venv golang-go wpasupplicant rsync \
  bubblewrap expect sqlite3 shellcheck cmake pkg-config pipx ffmpeg xvfb rclone whois ncdu postgresql-client

log "user namespaces for bwrap (dev-inbox sandbox wrapper exits 96 without this)"
sudo install -m 644 "$HERE/sysctl.d/99-codex-userns.conf" /etc/sysctl.d/99-codex-userns.conf
sudo sysctl --system >/dev/null

log "sshd: key-only (drop-in must sort BEFORE cloud-init's 50-*.conf)"
sudo install -m 644 "$HERE/sshd_config.d/00-forge.conf" /etc/ssh/sshd_config.d/00-forge.conf
sudo sshd -t && sudo systemctl reload ssh

log "tailscale"
command -v tailscale >/dev/null || curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable --now tailscaled

log "docker"
if ! command -v docker >/dev/null; then
  sudo apt-get -y -qq install docker.io docker-compose-v2
  sudo usermod -aG docker "$USER"
fi

log "node 24 (matches prod)"
if ! command -v node >/dev/null || [[ "$(node -v)" != v24* ]]; then
  curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash - >/dev/null
  sudo apt-get -y -qq install nodejs
fi

log "gh cli"
if ! command -v gh >/dev/null; then
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get -qq update && sudo apt-get -y -qq install gh
fi

log "google chrome (mockup/storyboard loops)"
if ! command -v google-chrome >/dev/null; then
  curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
  sudo apt-get -qq update && sudo apt-get -y -qq install google-chrome-stable
fi

log "PATH + env ABOVE the interactive guard in ~/.bashrc (non-interactive shells need it)"
grep -q 'forge-bootstrap PATH' ~/.bashrc || sed -i '1i # forge-bootstrap PATH (must precede the interactive-shell return below)\nexport PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.kimi-code/bin:$HOME/.codex/bin:$PATH"\n[ -f ~/.config/environment.d/50-forge-prod-endpoints.conf ] && { set -a; . ~/.config/environment.d/50-forge-prod-endpoints.conf; set +a; }' ~/.bashrc
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

log "npm global prefix + agent CLIs"
mkdir -p ~/.npm-global && npm config set prefix ~/.npm-global
command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash
npm i -g @openai/codex opencode-ai @google/gemini-cli @github/copilot pnpm serve clawdhub >/dev/null
command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
ln -sfn ~/.kimi-code/bin/kimi ~/.local/bin/kimi 2>/dev/null || true

log "systemd user session survives logout"
sudo loginctl enable-linger "$USER"

log "prod loopback bridge unit (edit the port list when services move)"
mkdir -p ~/.config/systemd/user ~/bin
install -m 644 "$HERE/systemd/prod-loopback-bridge.service" ~/.config/systemd/user/
install -m 755 "$HERE/bin/agency-hq-remote-deploy.sh" ~/bin/
systemctl --user daemon-reload

log "DONE. Manual follow-ups:"
cat <<'NEXT'
  1. sudo tailscale up --hostname forge --accept-dns=false   (open the printed URL)
  2. ssh key: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_github; add .pub at github.com/settings/keys;
     add Host github.com / Host beelink blocks to ~/.ssh/config; append forge .pub to prod ~/.ssh/authorized_keys
  3. copy from prod: ~/.claude (settings, CLAUDE.md, commands, hooks, skills, plugins, .credentials.json, projects/-home-jkeyser/memory),
     ~/.codex (auth.json, config.toml, rules, skills, plugins), ~/.kimi-code, ~/.opencode, ~/.config/dev-inbox*, ~/.config/agency-hq,
     ~/.config/*.env, ~/.tmux.conf, ~/.local/bin/tmux (forensics shim), GITHUB_TOKEN/COPILOT_GITHUB_TOKEN exports
  4. write ~/.config/environment.d/50-forge-prod-endpoints.conf (see forge/README.md), then: systemctl --user enable --now prod-loopback-bridge
  5. clone repos (SSH remotes), then dev-inbox: make all + scripts/install-systemd-units.sh; copy ~/.config/systemd/user/dev-inbox-*.service.d
     and ~/.local/share/dev-inbox (release store) + ~/dev-inbox/{results,plans,queue,releases,data,.env} from prod
NEXT
