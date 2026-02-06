#!/bin/bash
# Launch browser with persistent profile for initial login
# Runs with Xvfb + x11vnc + noVNC for remote access

PROFILE_DIR="${HOME}/.playwright-profiles/jeff"
PORT=${1:-6080}
VNC_PORT=${2:-5900}

cleanup() {
    echo "🧹 Cleaning up..."
    kill $NOVNC_PID $X11VNC_PID $XVFB_PID 2>/dev/null
    exit 0
}
trap cleanup SIGINT SIGTERM

# Start Xvfb
export DISPLAY=:99
Xvfb :99 -screen 0 1280x800x24 &
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

# Launch Chromium with persistent profile
URL=${1:-"https://google.com"}
npx playwright open --user-data-dir="$PROFILE_DIR" "$URL"

cleanup
