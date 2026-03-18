#!/bin/bash
# ============================================================================
# TRINITY FPGA MONITOR DAEMON — Cycle 123
# Autonomous FPGA flashing daemon with health checks and scheduled updates
# phi^2 + 1/phi^2 = 3 = TRINITY
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$HOME/.trinity/fpga"
LOG_FILE="$LOG_DIR/monitor.log"
PID_FILE="$LOG_DIR/monitor.pid"
PIPE="/tmp/fpga_control_pipe"

FLASH_SCRIPT="$SCRIPT_DIR/flash_no_sudo.sh"
BITSTREAM_DIR="$SCRIPT_DIR/../openxc7-synth"

HEALTH_CHECK_INTERVAL=60  # seconds - health check only, NO scheduled flashing

# Colors for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# LOGGING
# ============================================================================

log() {
    local level="$1"
    shift
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
    echo -e "$msg" >> "$LOG_FILE"
    case "$level" in
        INFO)  echo -e "${BLUE}$msg${NC}" ;;
        OK)    echo -e "${GREEN}$msg${NC}" ;;
        WARN)  echo -e "${YELLOW}$msg${NC}" ;;
        ERROR) echo -e "${RED}$msg${NC}" ;;
    esac
}

# ============================================================================
# FPGA HEALTH CHECK
# ============================================================================

check_fpga_health() {
    local pid
    pid=$(python3 -c "import usb.core; dev = usb.core.find(idVendor=0x03fd); print(hex(dev.idProduct))" 2>/dev/null || echo "none")

    if [ "$pid" = "none" ]; then
        log ERROR "JTAG cable not found"
        return 1
    fi

    if [ "$pid" = "0x13" ]; then
        log WARN "Cable not initialized (PID 0x0013)"
        return 2
    fi

    log INFO "Cable OK (PID $pid)"
    return 0
}

# ============================================================================
# FLASH BITSTREAM
# ============================================================================

flash_bitstream() {
    local name="$1"
    local bitstream

    # Check if it's a full path or just a name
    if [[ "$name" == /* ]]; then
        # Full path
        bitstream="$name"
        name=$(basename "$name" .bit)
    else
        # Just a name - assume quantum_bridge_*.bit
        bitstream="$BITSTREAM_DIR/quantum_bridge_${name}.bit"
    fi

    if [ ! -f "$bitstream" ]; then
        log ERROR "Bitstream not found: $bitstream"
        return 1
    fi

    log INFO "Flashing: $name ($bitstream)"
    if "$FLASH_SCRIPT" "$bitstream" >> "$LOG_FILE" 2>&1; then
        log OK "Flash successful: $name"
        echo "{\"status\":\"ok\",\"bitstream\":\"$(basename $bitstream)\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"path\":\"$bitstream\"}" > "$LOG_DIR/current_state.json"
        return 0
    else
        log ERROR "Flash failed: $name"
        return 1
    fi
}

# ============================================================================
# CONTROL PIPE HANDLER
# ============================================================================

handle_command() {
    local cmd="$1"
    log INFO "Received command: $cmd"

    case "$cmd" in
        flash:*)
            local name="${cmd#flash:}"
            flash_bitstream "$name"
            ;;
        status)
            check_fpga_health
            if [ -f "$LOG_DIR/current_state.json" ]; then
                cat "$LOG_DIR/current_state.json"
            fi
            ;;
        health)
            check_fpga_health
            ;;
        quit)
            log INFO "Quit command received"
            exit 0
            ;;
        *)
            log WARN "Unknown command: $cmd"
            ;;
    esac
}

# ============================================================================
# DAEMON MAIN LOOP
# ============================================================================

daemon_loop() {
    log INFO "=== FPGA Monitor Daemon Started ==="
    log INFO "Health check interval: ${HEALTH_CHECK_INTERVAL}s"
    log INFO "Control pipe: $PIPE"
    log INFO "Mode: MANUAL CONTROL (no scheduled flashing)"

    # Create control pipe
    rm -f "$PIPE"
    mkfifo "$PIPE"

    # Main loop with timeout for pipe reading
    while true; do
        # Health check only
        check_fpga_health

        # Wait for command with timeout
        if read -t "$HEALTH_CHECK_INTERVAL" cmd < "$PIPE"; then
            handle_command "$cmd"
        fi
    done
}

# ============================================================================
# START/STOP/STATUS
# ============================================================================

start_daemon() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "Daemon already running (PID $pid)"
            return 1
        fi
        rm -f "$PID_FILE"
    fi

    mkdir -p "$LOG_DIR"
    nohup bash "$0" --daemon-loop >> "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"

    echo "Daemon started (PID $pid)"
    echo "Log: $LOG_FILE"
    log OK "Daemon started (PID $pid)"
}

stop_daemon() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Daemon not running"
        return 1
    fi

    local pid=$(cat "$PID_FILE")
    if ps -p "$pid" > /dev/null 2>&1; then
        kill "$pid"
        rm -f "$PID_FILE"
        echo "Daemon stopped"
        log OK "Daemon stopped (PID $pid)"
    else
        rm -f "$PID_FILE"
        echo "Daemon was not running"
        return 1
    fi
}

status_daemon() {
    if [ ! -f "$PID_FILE" ]; then
        echo "Daemon: stopped"
        return 1
    fi

    local pid=$(cat "$PID_FILE")
    if ps -p "$pid" > /dev/null 2>&1; then
        echo "Daemon: running (PID $pid)"
        check_fpga_health
        if [ -f "$LOG_DIR/current_state.json" ]; then
            echo "Current state:"
            cat "$LOG_DIR/current_state.json"
        fi
        return 0
    else
        echo "Daemon: stopped (stale PID file)"
        rm -f "$PID_FILE"
        return 1
    fi
}

show_logs() {
    if [ -f "$LOG_FILE" ]; then
        tail -n 50 "$LOG_FILE"
    else
        echo "No log file found"
    fi
}

# ============================================================================
# ENTRY POINT
# ============================================================================

case "${1:-}" in
    --daemon-loop)
        daemon_loop
        ;;
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    restart)
        stop_daemon
        sleep 1
        start_daemon
        ;;
    status)
        status_daemon
        ;;
    logs)
        show_logs
        ;;
    "")
        echo "Usage: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "Control commands (via $PIPE):"
        echo "  echo 'flash:violation' > $PIPE"
        echo "  echo 'status' > $PIPE"
        echo "  echo 'health' > $PIPE"
        exit 1
        ;;
    *)
        echo "Unknown command: $1"
        exit 1
        ;;
esac
