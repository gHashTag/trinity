#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY HARDWARE DEPLOYMENT — Bootstrap real hardware nodes (SINGLE + MULTI-NODE)
# ═══════════════════════════════════════════════════════════════════════════════
#
# Usage:
#   Single node: ./scripts/hardware-deploy.sh [platform] [port]
#   Multi-node:  ./scripts/hardware-deploy.sh multi [count]
#   Status:      ./scripts/hardware-deploy.sh status
#   Stop all:    ./scripts/hardware-deploy.sh stop-all
#
#   platform: raspberry-pi | macos | linux (auto-detected if omitted)
#   port: HTTP port (default: 9001)
#   count: Number of nodes for multi-mode (default: 10)
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
MULTI_DIR=".tri-multi"
DEFAULT_NODE_COUNT=10

# Multi-node mode check
if [ "$1" = "multi" ]; then
    NODE_COUNT="${2:-$DEFAULT_NODE_COUNT}"
    exec > >(tee -i "$LOG_DIR/multi-deploy.log")
    exec 2>&1
    echo -e "${GOLDEN}════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${GOLDEN}  TRINITY MULTI-NODE DEPLOYMENT v1.0${RESET}"
    echo -e "${GOLDEN}  Deploying $NODE_COUNT nodes for global mesh${RESET}"
    echo -e "${GOLDEN}════════════════════════════════════════════════════════════════${RESET}"
    echo ""

    # Detect platform
    if [ -f /proc/device-tree/model ] && grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
        DETECTED_PLATFORM="raspberry-pi"
    elif [ "$(uname)" = "Darwin" ]; then
        DETECTED_PLATFORM="macos"
    elif [ "$(uname)" = "Linux" ]; then
        DETECTED_PLATFORM="linux"
    else
        echo -e "${RED}Unknown platform!${RESET}"
        exit 1
    fi
    echo -e "${CYAN}Platform:${RESET} $DETECTED_PLATFORM"

    # Detect hardware
    ARCH=$(uname -m)
    case "$ARCH" in
        arm64|aarch64) ARCH_DETECTED="arm64" ;;
        x86_64) ARCH_DETECTED="x86_64" ;;
        *) ARCH_DETECTED="unknown" ;;
    esac
    if [ "$(uname)" = "Darwin" ]; then
        CORES=$(sysctl -n hw.ncpu)
        MEM_MB=$(sysctl -n hw.memsize | awk '{print $1/1024/1024}')
    else
        CORES=$(nproc 2>/dev/null || echo "4")
        MEM_MB=$(free -m | awk '/Mem:/ {print $2}')
    fi
    echo -e "${CYAN}Hardware:${RESET} $ARCH_DETECTED, $CORES cores, ${MEM_MB}MB RAM"
    echo ""

    # Create multi-node directory
    mkdir -p "$MULTI_DIR"
    mkdir -p "$LOG_DIR"

    # Check if TRI binary exists
    if [ ! -f "./zig-out/bin/tri" ]; then
        echo -e "${RED}ERROR: ./zig-out/bin/tri not found!${RESET}"
        echo -e "${CYAN}Run: zig build tri${RESET}"
        exit 1
    fi

    # Start nodes in parallel
    echo -e "${GREEN}=== STARTING $NODE_COUNT NODES ===${RESET}"
    START_PORT=9001
    SUCCESS_COUNT=0
    FAILED_COUNT=0

    for i in $(seq 1 $NODE_COUNT); do
        PORT=$((START_PORT + i - 1))
        PID_FILE="$MULTI_DIR/node-$i.pid"
        LOG_FILE="$LOG_DIR/multi-node-$i.log"

        # Check if already running
        if [ -f "$PID_FILE" ]; then
            EXISTING_PID=$(cat "$PID_FILE")
            if ps -p "$EXISTING_PID" > /dev/null 2>&1; then
                echo -e "${GOLDEN}Node $i already running (PID: $EXISTING_PID, Port: $PORT)${RESET}"
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                continue
            fi
        fi

        # Start node
        echo -e "${CYAN}Starting node $i on port $PORT...${RESET}"
        ./zig-out/bin/tri serve --port "$PORT" --daemon > "$LOG_FILE" 2>&1 &
        NODE_PID=$!

        # Save PID
        echo "$NODE_PID" > "$PID_FILE"

        # Small delay between starts
        sleep 0.2

        # Verify
        if ps -p "$NODE_PID" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Node $i started (PID: $NODE_PID)${RESET}"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            echo -e "${RED}❌ Node $i failed to start${RESET}"
            rm -f "$PID_FILE"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    done

    echo ""
    echo -e "${GREEN}=== DEPLOYMENT SUMMARY ===${RESET}"
    echo -e "${CYAN}Started:${RESET} $SUCCESS_COUNT/$NODE_COUNT nodes"
    if [ $FAILED_COUNT -gt 0 ]; then
        echo -e "${RED}Failed:${RESET} $FAILED_COUNT nodes"
    fi
    echo ""
    echo -e "${CYAN}Port range:${RESET} $START_PORT - $((START_PORT + NODE_COUNT - 1))"
    echo -e "${CYAN}PID files:${RESET} $MULTI_DIR/"
    echo -e "${CYAN}Logs:${RESET} $LOG_DIR/"
    echo ""
    echo -e "${GOLDEN}To check status:${RESET} ./scripts/hardware-deploy.sh status"
    echo -e "${GOLDEN}To stop all:${RESET} ./scripts/hardware-deploy.sh stop-all"

    # Wait and verify health
    echo ""
    echo -e "${GREEN}=== HEALTH CHECK (waiting 3s for startup) ===${RESET}"
    sleep 3

    HEALTHY_COUNT=0
    if command -v curl > /dev/null 2>&1; then
        for i in $(seq 1 $NODE_COUNT); do
            PORT=$((START_PORT + i - 1))
            PID_FILE="$MULTI_DIR/node-$i.pid"
            if [ -f "$PID_FILE" ]; then
                PID=$(cat "$PID_FILE")
                if ps -p "$PID" > /dev/null 2>&1; then
                    if curl -s "http://127.0.0.1:$PORT/health" > /dev/null 2>&1; then
                        echo -e "${GREEN}✅ Node $i (port $PORT) healthy${RESET}"
                        HEALTHY_COUNT=$((HEALTHY_COUNT + 1))
                    else
                        echo -e "${GOLDEN}⚠ Node $i (port $PORT) running but health not ready${RESET}"
                    fi
                fi
            fi
        done
    fi

    echo ""
    echo -e "${GOLDEN}════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${GREEN}GLOBAL MESH READY: $HEALTHY_COUNT healthy nodes${RESET}"
    echo -e "${GOLDEN}════════════════════════════════════════════════════════════════${RESET}"
    exit 0
fi

# Status command
if [ "$1" = "status" ]; then
    echo -e "${GOLDEN}════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${GOLDEN}  TRINITY CLUSTER STATUS${RESET}"
    echo -e "${GOLDEN}════════════════════════════════════════════════════════════════${RESET}"
    echo ""

    # Check single node
    if [ -f "$DAEMON_PID_FILE" ]; then
        PID=$(cat "$DAEMON_PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Single node running (PID: $PID)${RESET}"
            if command -v curl > /dev/null 2>&1; then
                curl -s "http://127.0.0.1:9001/health" 2>/dev/null | head -5 || true
            fi
        else
            echo -e "${RED}❌ Single node PID file stale${RESET}"
        fi
    fi

    # Check multi-nodes
    if [ -d "$MULTI_DIR" ]; then
        echo ""
        echo -e "${GREEN}=== MULTI-NODE CLUSTER ===${RESET}"
        RUNNING_COUNT=0
        START_PORT=9001
        MAX_NODES=50

        for i in $(seq 1 $MAX_NODES); do
            PID_FILE="$MULTI_DIR/node-$i.pid"
            if [ -f "$PID_FILE" ]; then
                PID=$(cat "$PID_FILE")
                if ps -p "$PID" > /dev/null 2>&1; then
                    PORT=$((START_PORT + i - 1))
                    RUNNING_COUNT=$((RUNNING_COUNT + 1))
                    STATUS="${GREEN}✅${RESET}"
                    if command -v curl > /dev/null 2>&1; then
                        if curl -s "http://127.0.0.1:$PORT/health" > /dev/null 2>&1; then
                            STATUS="${GREEN}✅ HEALTHY${RESET}"
                        else
                            STATUS="${GOLDEN}⚠ STARTING${RESET}"
                        fi
                    fi
                    echo -e "Node $i (port $((START_PORT + i - 1))): PID $PID $STATUS"
                fi
            fi
        done

        echo ""
        echo -e "${CYAN}Total running:${RESET} $RUNNING_COUNT nodes"

        # Show cluster metrics if available
        if [ $RUNNING_COUNT -gt 0 ] && command -v curl > /dev/null 2>&1; then
            echo ""
            echo -e "${GREEN}=== CLUSTER METRICS ===${RESET}"
            curl -s "http://127.0.0.1:9001/cluster/nodes" 2>/dev/null || echo -e "${GOLDEN}Cluster endpoint not ready${RESET}"
        fi
    fi

    echo ""
    echo -e "${GOLDEN}════════════════════════════════════════════════════════════════${RESET}"
    exit 0
fi

# Stop-all command
if [ "$1" = "stop-all" ]; then
    echo -e "${GOLDEN}════════════════════════════════════════════════════════════════${RESET}"
    echo -e "${GOLDEN}  STOPPING ALL TRINITY NODES${RESET}"
    echo -e "${GOLDEN}════════════════════════════════════════════════════════════════${RESET}"
    echo ""

    STOPPED_COUNT=0

    # Stop single node
    if [ -f "$DAEMON_PID_FILE" ]; then
        PID=$(cat "$DAEMON_PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            kill "$PID"
            echo -e "${GREEN}✅ Stopped single node (PID: $PID)${RESET}"
            STOPPED_COUNT=$((STOPPED_COUNT + 1))
        fi
        rm -f "$DAEMON_PID_FILE"
    fi

    # Stop multi-nodes
    if [ -d "$MULTI_DIR" ]; then
        for PID_FILE in "$MULTI_DIR"/*.pid; do
            if [ -f "$PID_FILE" ]; then
                PID=$(cat "$PID_FILE")
                if ps -p "$PID" > /dev/null 2>&1; then
                    kill "$PID"
                    echo -e "${GREEN}✅ Stopped $(basename "$PID_FILE" .pid) (PID: $PID)${RESET}"
                    STOPPED_COUNT=$((STOPPED_COUNT + 1))
                fi
                rm -f "$PID_FILE"
            fi
        done
    fi

    echo ""
    echo -e "${GREEN}Total stopped: $STOPPED_COUNT nodes${RESET}"
    echo -e "${GOLDEN}════════════════════════════════════════════════════════════════${RESET}"
    exit 0
fi

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
