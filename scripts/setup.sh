#!/bin/bash
set -e

echo "=== Homelab Setup Script ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please run this script as a regular user, not root"
    exit 1
fi

# Update system
echo ""
echo "=== Updating System ==="
sudo apt update && sudo apt upgrade -y
print_status "System updated"

# Install essential packages
echo ""
echo "=== Installing Essential Packages ==="
sudo apt install -y curl wget git tmux htop
print_status "Essential packages installed"

# Install Tailscale
echo ""
echo "=== Installing Tailscale ==="
if command -v tailscale &> /dev/null; then
    print_warning "Tailscale already installed"
else
    curl -fsSL https://tailscale.com/install.sh | sh
    print_status "Tailscale installed"
fi

# Install Docker
echo ""
echo "=== Installing Docker ==="
if command -v docker &> /dev/null; then
    print_warning "Docker already installed"
else
    sudo apt install -y docker.io docker-compose-v2
    sudo usermod -aG docker "$USER"
    print_status "Docker installed"
    print_warning "You may need to log out and back in for Docker permissions"
fi

# Install Node.js
echo ""
echo "=== Installing Node.js 22.x ==="
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    print_warning "Node.js already installed ($NODE_VERSION)"
else
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt install -y nodejs
    print_status "Node.js installed ($(node --version))"
fi

# Install Claude Code CLI
echo ""
echo "=== Installing Claude Code CLI ==="
if command -v claude &> /dev/null; then
    print_warning "Claude Code CLI already installed"
else
    npm install -g @anthropic-ai/claude-code
    print_status "Claude Code CLI installed"
fi

# Setup tmux config
echo ""
echo "=== Setting Up tmux Config ==="
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$REPO_DIR/.tmux.conf" ]; then
    cp "$REPO_DIR/.tmux.conf" ~/.tmux.conf
    print_status "tmux config copied to ~/.tmux.conf"
else
    print_warning "No .tmux.conf found in repo, skipping"
fi

# Final status
echo ""
echo "=== Setup Complete ==="
echo ""
print_status "All components installed"
echo ""
echo "Next steps:"
echo "  1. Run 'sudo tailscale up' to connect to Tailscale"
echo "  2. Log out and back in (for Docker permissions)"
echo "  3. Run 'tmux new -s claude' to start a session"
echo "  4. Run 'claude' to start Claude Code CLI"
echo ""
