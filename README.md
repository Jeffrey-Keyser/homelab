# Homelab

Personal home server setup for remote Claude Code CLI access via Tailscale.

## Hardware

| Device | Model | Purpose |
|--------|-------|---------|
| **Server** | [Beelink ME Mini N150](https://www.bee-link.com/products/beelink-me-mini-n150) | Docker host, Tailscale exit node |
| **Travel Router** | [GL.iNet Beryl AX (GL-MT3000)](https://www.gl-inet.com/products/gl-mt3000/) | Remote Tailscale access from anywhere |
| **Remote KVM** | [GL.iNet Comet PoE (GL-RM1PE)](https://store-us.gl-inet.com/products/comet-poe-gl-rm1pe-remote-kvm-control-over-internet) | BIOS-level remote access |

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
| tmux | Terminal multiplexer for persistent sessions |

### Optional Services (Docker)

| Service | Purpose |
|---------|---------|
| Caddy | Reverse proxy with auto-TLS |
| Uptime Kuma | Service health monitoring |

## Setup

### Quick Start

```bash
# Clone and run setup
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

# Install tmux
sudo apt install -y tmux

# Copy tmux config
cp .tmux.conf ~/.tmux.conf
```

## Usage

### Starting Claude Code

```bash
# Create a named tmux session
tmux new -s claude

# Run Claude Code
claude
```

### Remote Access

From any device on your Tailscale network:

```bash
# SSH into server
ssh user@homelab.tailnet-name.ts.net

# Attach to existing session
tmux attach -t claude
```

### tmux Basics

| Command | Action |
|---------|--------|
| `Ctrl+b d` | Detach from session (keeps running) |
| `Ctrl+b c` | Create new window |
| `Ctrl+b n` | Next window |
| `Ctrl+b p` | Previous window |
| `Ctrl+b [` | Enter scroll mode (q to exit) |
| `exit` | Close current pane/window |

## Network Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Tailscale Network                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐ │
│  │   Laptop     │     │  Beelink     │     │  Beryl AX    │ │
│  │  (anywhere)  │────▶│   Server     │◀────│  (travel)    │ │
│  └──────────────┘     └──────┬───────┘     └──────────────┘ │
│                              │                               │
│                       ┌──────┴───────┐                       │
│                       │  Comet KVM   │                       │
│                       │ (emergency)  │                       │
│                       └──────────────┘                       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Costs

| Item | Cost |
|------|------|
| Ubuntu Server | Free |
| Docker | Free |
| Tailscale | Free (personal tier) |
| tmux | Free |
| **Claude Code CLI** | **API usage (~$20-100+/month)** |

The only recurring cost is Anthropic API usage for Claude Code.

## Backup Strategy

Consider implementing backups for:
- Claude Code configuration (`~/.claude/`)
- Docker volumes
- Any project repositories

## Troubleshooting

### Can't SSH into server
1. Check Tailscale status: `tailscale status`
2. Verify server is online via Comet KVM
3. Check if SSH service is running: `sudo systemctl status ssh`

### tmux session lost
Sessions persist through SSH disconnects but not server reboots. Consider:
- Using `tmux-resurrect` plugin for session persistence
- Running Claude Code in a systemd service

### Docker permission denied
```bash
sudo usermod -aG docker $USER
newgrp docker
# Or log out and back in
```
