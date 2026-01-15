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
| tmux | Terminal multiplexer for persistent sessions |

### Optional Services (Docker)

| Service | Purpose |
|---------|---------|
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

# Install tmux
sudo apt install -y tmux

# Copy tmux config
cp .tmux.conf ~/.tmux.conf
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
