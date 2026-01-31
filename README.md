# Homelab

Personal home server setup for remote Claude Code CLI access via Tailscale.

## Hardware

| Device | Model | Purpose |
|--------|-------|---------|
| **Server** | [Beelink ME Mini N150](https://www.bee-link.com/products/beelink-me-mini-n150) | Docker host, Claude Code CLI |
| **Travel Router** | [GL.iNet Beryl AX (GL-MT3000)](https://www.gl-inet.com/products/gl-mt3000/) | Tailscale access from anywhere |
| **Remote KVM** | [GL.iNet Comet PoE (GL-RM1PE)](https://store-us.gl-inet.com/products/comet-poe-gl-rm1pe-remote-kvm-control-over-internet) | BIOS-level emergency access |

### Server Specs (Beelink ME Mini N150)

- **CPU**: Intel Twin Lake N150 (4 cores, 4 threads, 3.6 GHz burst)
- **RAM**: 16GB LPDDR5-4800
- **Storage**: 1TB NVMe SSD (5 empty M.2 slots for expansion)
- **Network**: Dual 2.5G LAN (Intel i226-V), WiFi 6, Bluetooth 5.2
- **Dimensions**: 99 x 99 x 99 mm

## Software Stack

| Component | Purpose |
|-----------|---------|
| Ubuntu Server 24.04 LTS | Operating system |
| Tailscale | Secure mesh VPN (free tier) |
| Docker | Container runtime |
| Claude Code CLI | AI coding assistant |
| [OpenClaw](https://docs.openclaw.ai) | AI gateway with messaging channel integrations |
| tmux | Terminal multiplexer for persistent sessions |

### Docker Services

| Service | Purpose |
|---------|---------|
| GitHub Actions Runner | Self-hosted CI/CD for Jeffrey-Keyser repos |
| Cron HQ (local) | Dev/staging instance for scheduled job orchestration |
| Caddy | Reverse proxy with auto-TLS |
| Uptime Kuma | Service health monitoring |

## Network Architecture

The home Windows PC acts as the central hub. When traveling, RDP into the Windows PC, then access everything else with minimal latency:

```
┌──────────────────────────────────────────────────────────────────┐
│                       From Travel Laptop                          │
│                              │                                    │
│                      RDP via Tailscale                            │
│                         (50-100ms)                                │
│                              ▼                                    │
│                   ┌──────────────────┐                            │
│                   │  Home Windows PC  │                           │
│                   │      (hub)        │                           │
│                   └────────┬─────────┘                            │
│                            │                                      │
│           ┌────────────────┼────────────────┐                     │
│           ▼                ▼                ▼                     │
│     ┌──────────┐    ┌───────────┐    ┌───────────┐               │
│     │ Beelink  │    │  Work PC  │    │ Comet KVM │               │
│     │ SSH/tmux │    │    RDP    │    │ (backup)  │               │
│     └──────────┘    └───────────┘    └───────────┘               │
│        ~1ms           ~10-20ms         if needed                  │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

This avoids nested RDP (which degrades quality). From the Windows hub:
- **SSH to Beelink** for Claude Code sessions (instant)
- **RDP to Work PC** as a single hop (feels local)
- **Comet KVM** web interface if Beelink needs emergency access

## Setup

### Quick Start

```bash
git clone https://github.com/Jeffrey-Keyser/homelab.git
cd homelab
chmod +x scripts/setup.sh
./scripts/setup.sh
```

### Manual Setup

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Install Docker
sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER
newgrp docker

# Install Node.js 22.x
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# Install Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Install OpenClaw
curl -fsSL https://openclaw.bot/install.sh | bash
# Add npm global bin to PATH
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
# Run onboarding wizard
openclaw onboard --install-daemon

# Install tmux
sudo apt install -y tmux

# Copy tmux config
cp .tmux.conf ~/.tmux.conf
```

## GitHub Actions Runner

Self-hosted runner for the Jeffrey-Keyser organization. Provides free CI/CD minutes and access to the Tailscale network during builds.

```bash
# Start the runner
docker compose up -d github-runner
```

Register the runner at: https://github.com/organizations/Jeffrey-Keyser/settings/actions/runners

Benefits:
- Unlimited build minutes (vs GitHub's 2000/month free tier)
- Access to local services via Tailscale during CI
- Faster builds with local caching

## Scheduled Claude Code Tasks

Use cron to send commands to a running Claude Code session via tmux. This enables automated tasks like dependency updates, test runs, or code reviews.

### Setup

```bash
# Create a dedicated tmux session for scheduled tasks
tmux new-session -d -s claude-scheduled

# Add cron jobs
crontab -e
```

### Example Cron Jobs

```bash
# Run tests every morning at 8am
0 8 * * * tmux send-keys -t claude-scheduled 'cd ~/projects/myapp && claude "run the test suite and fix any failures"' Enter

# Check for dependency updates weekly (Sunday 2am)
0 2 * * 0 tmux send-keys -t claude-scheduled 'cd ~/projects/myapp && claude "check for outdated dependencies and create a summary"' Enter

# Daily standup prep (weekdays 8:30am)
30 8 * * 1-5 tmux send-keys -t claude-scheduled 'cd ~/projects/myapp && claude "summarize git commits from yesterday and list open issues"' Enter
```

### Viewing Output

```bash
# Attach to see results
tmux attach -t claude-scheduled

# Or capture to a log file
tmux capture-pane -t claude-scheduled -p > ~/logs/claude-$(date +%Y%m%d).log
```

## OpenClaw Gateway

OpenClaw provides AI assistant access via messaging channels (WhatsApp, Telegram, Discord, etc.) and a local web dashboard.

### Setup

```bash
# Run the onboarding wizard (if not done during install)
openclaw onboard --install-daemon

# Check gateway status
openclaw gateway status

# Start gateway manually (if needed)
openclaw gateway --port 18789 --verbose
```

### Web Dashboard

Access the dashboard at `http://127.0.0.1:18789/` on the Beelink, or via Tailscale at `http://100.99.136.81:18789/`.

### Messaging Channels

```bash
# WhatsApp - scan QR code to link
openclaw channels login

# Check channel status
openclaw channels status
```

See [OpenClaw documentation](https://docs.openclaw.ai) for Telegram, Discord, and other channel setup.

## Costs

| Item | Cost |
|------|------|
| Ubuntu Server | Free |
| Docker | Free |
| Tailscale | Free (personal tier) |
| GitHub Actions Runner | Free (self-hosted) |
| tmux | Free |
| OpenClaw | Free (uses your API keys) |
| **Claude Code CLI** | **API usage (~$20-100+/month)** |

The only recurring cost is Anthropic API usage for Claude Code and OpenClaw.

## Troubleshooting

### Can't SSH into server
1. Check Tailscale status: `tailscale status`
2. Verify server is online via Comet KVM
3. Check if SSH service is running: `sudo systemctl status ssh`

### Docker permission denied
```bash
sudo usermod -aG docker $USER
newgrp docker
# Or log out and back in
```
