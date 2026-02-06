#!/bin/bash
set -e

echo "🎭 Installing Playwright Browser Automation..."

# Install system dependencies
echo "📦 Installing system packages..."
sudo apt update
sudo apt install -y xvfb x11vnc novnc websockify

# Create playwright-automation directory
echo "📁 Setting up playwright-automation..."
mkdir -p ~/playwright-automation
cd ~/playwright-automation

# Initialize npm and install playwright
npm init -y
npm install playwright

# Install Chromium browser
echo "🌐 Installing Chromium..."
npx playwright install chromium
sudo npx playwright install-deps chromium

# Create profile directory
echo "🔐 Creating secure profile directory..."
mkdir -p ~/.playwright-profiles/jeff
chmod 700 ~/.playwright-profiles

# Copy helper scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/scripts/"* ~/playwright-automation/
chmod +x ~/playwright-automation/*.sh

echo ""
echo "✅ Playwright installed successfully!"
echo ""
echo "To log into sites, run:"
echo "  cd ~/playwright-automation && ./open-browser.sh"
echo ""
echo "Then open http://beelink:6080/vnc.html in your browser"
