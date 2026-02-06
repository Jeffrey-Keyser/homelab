#!/bin/bash
# Launch Playwright Chromium with stealth settings

PROFILE_DIR="${HOME}/.playwright-profiles/jeff"
PORT=${1:-6080}
VNC_PORT=${2:-5900}

cleanup() {
    echo "🧹 Cleaning up..."
    kill $NOVNC_PID $X11VNC_PID $XVFB_PID 2>/dev/null
    exit 0
}
trap cleanup SIGINT SIGTERM

# Start Xvfb with better settings
export DISPLAY=:99
Xvfb :99 -screen 0 1920x1080x24 -ac &
XVFB_PID=$!
sleep 2

# Start x11vnc
x11vnc -display :99 -nopw -forever -shared -rfbport $VNC_PORT &
X11VNC_PID=$!
sleep 1

# Start noVNC
websockify --web=/usr/share/novnc/ $PORT localhost:$VNC_PORT &
NOVNC_PID=$!

IP=$(hostname -I | awk '{print $1}')
echo "=========================================="
echo "🌐 Browser ready for login!"
echo ""
echo "Open in your browser:"
echo "  http://${IP}:${PORT}/vnc.html"
echo ""
echo "Or via Tailscale:"
echo "  http://beelink:${PORT}/vnc.html"
echo ""
echo "Press Ctrl+C when done logging in."
echo "=========================================="

URL=${2:-"https://google.com"}

# Use Playwright with stealth-like args
npx playwright open \
    --user-data-dir="$PROFILE_DIR" \
    --browser=chromium \
    "$URL"

cleanup
