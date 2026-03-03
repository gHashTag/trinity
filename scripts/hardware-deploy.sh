#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY HARDWARE DEPLOYMENT — Bootstrap real hardware nodes
# ═══════════════════════════════════════════════════════════════════════════════
#
# Usage: ./scripts/hardware-deploy.sh [platform] [port]
#   platform: raspberry-pi | macos | linux (auto-detected if omitted)
#   port: HTTP port (default: 9001)
#
# φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;229;153m'
GOLDEN='\033[0;255;215;0m'
CYAN='\033[0;0;255;255'
RESET='\033[0m'

# Defaults
PLATFORM="${1:-auto}"
PORT="${2:-9001}"
UDP_PORT=9333
DAEMON_PID_FILE=".tri-hardware.pid"
LOG_DIR=".tri-hardware-logs"

echo -e "${GOLDEN}════════════════════════════════════════════════════════════════${RESET}"
echo -e "${GOLDEN}  TRINITY HARDWARE DEPLOYMENT v1.0${RESET}"
echo -e "${GOLDEN}  φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL${RESET}"
echo -e "${GOLDEN}════════════════════════════════════════════════════════════════${RESET}"
echo ""

# Detect platform
if [ "$PLATFORM" = "auto" ]; then
    if [ -f /proc/device-tree/model ] && grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
        PLATFORM="raspberry-pi"
    elif [ "$(uname)" = "Darwin" ]; then
        PLATFORM="macos"
    elif [ "$(uname)" = "Linux" ]; then
        PLATFORM="linux"
    else
        echo -e "${RED}Unknown platform!${RESET}"
        exit 1
    fi
fi

echo -e "${CYAN}Platform:${RESET} $PLATFORM"
echo -e "${CYAN}HTTP Port:${RESET} $PORT"
echo -e "${CYAN}UDP Discovery:${RESET} $UDP_PORT"
echo ""

# Create log directory
mkdir -p "$LOG_DIR"

# Check if TRI binary exists
if [ ! -f "./zig-out/bin/tri" ]; then
    echo -e "${RED}ERROR: ./zig-out/bin/tri not found!${RESET}"
    echo -e "${CYAN}Run: zig build tri${RESET}"
    exit 1
fi

# Detect hardware info
echo -e "${GREEN}=== HARDWARE DETECTION ===${RESET}"
ARCH=$(uname -m)
case "$ARCH" in
    arm64|aarch64)
        ARCH_DETECTED="arm64"
        ;;
    x86_64)
        ARCH_DETECTED="x86_64"
        ;;
    *)
        ARCH_DETECTED="unknown"
        ;;
esac
echo -e "${CYAN}Architecture:${RESET} $ARCH_DETECTED"

# CPU cores
if [ "$(uname)" = "Darwin" ]; then
    CORES=$(sysctl -n hw.ncpu)
    MEM_MB=$(sysctl -n hw.memsize | awk '{print $1/1024/1024}')
else
    CORES=$(nproc 2>/dev/null || echo "4")
    MEM_MB=$(free -m | awk '/Mem:/ {print $2}')
fi
echo -e "${CYAN}CPU Cores:${RESET} $CORES"
echo -e "${CYAN}Memory:${RESET} ${MEM_MB} MB"
echo ""

# Check if already running
if [ -f "$DAEMON_PID_FILE" ]; then
    PID=$(cat "$DAEMON_PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo -e "${GOLDEN}Node already running (PID: $PID)${RESET}"
        echo -e "${CYAN}To stop: kill $PID && rm $DAEMON_PID_FILE${RESET}"
        exit 0
    else
        echo -e "${GOLDEN}Removing stale PID file${RESET}"
        rm -f "$DAEMON_PID_FILE"
    fi
fi

# Start the node
echo -e "${GREEN}=== STARTING HARDWARE NODE ===${RESET}"
echo -e "${CYAN}Command: ./zig-out/bin/tri serve --port $PORT --daemon${RESET}"
echo ""

./zig-out/bin/tri serve --port "$PORT" --daemon > "$LOG_DIR/node-$PORT.log" 2>&1 &
NODE_PID=$!

# Save PID
echo "$NODE_PID" > "$DAEMON_PID_FILE"

# Wait for startup
sleep 2

# Verify node is running
if ps -p "$NODE_PID" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Node started successfully!${RESET}"
    echo -e "${CYAN}PID: $NODE_PID${RESET}"
    echo -e "${CYAN}Logs: $LOG_DIR/node-$PORT.log${RESET}"
    echo ""
    
    # Test health endpoint
    if command -v curl > /dev/null 2>&1; then
        echo -e "${GREEN}=== HEALTH CHECK ===${RESET}"
        if curl -s "http://127.0.0.1:$PORT/health" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Health endpoint responding${RESET}"
            echo -e "${CYAN}URL: http://127.0.0.1:$PORT/health${RESET}"
        else
            echo -e "${GOLDEN}⚠ Health endpoint not ready yet (check logs)${RESET}"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}=== NODE STATUS ===${RESET}"
    echo -e "${CYAN}To view logs: tail -f $LOG_DIR/node-$PORT.log${RESET}"
    echo -e "${CYAN}To stop node: kill $NODE_PID && rm $DAEMON_PID_FILE${RESET}"
    echo -e "${CYAN}To check status: curl http://127.0.0.1:$PORT/health${RESET}"
else
    echo -e "${RED}❌ Node failed to start!${RESET}"
    rm -f "$DAEMON_PID_FILE"
    exit 1
fi

echo ""
echo -e "${GOLDEN}════════════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}TRINITY HARDWARE NODE READY${RESET}"
echo -e "${GOLDEN}════════════════════════════════════════════════════════════════${RESET}"
