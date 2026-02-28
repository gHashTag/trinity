#!/bin/bash
# Trinity Eternal Monitor Manager
# Unified control interface for eternal monitoring

TRINITY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$TRINITY_ROOT"

PID_FILE="/tmp/trinity-eternal-monitor.pid"
LOG_FILE="$HOME/.trinity/eternal-monitor.log"

# Colors
GOLD='\033[38;5;220m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

print_banner() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     TRINITY ETERNAL MONITOR — CONTROL CENTER            ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║  φ² + 1/φ² = 3 = TRINITY                                 ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

start_monitor() {
    print_banner

    if is_running; then
        local pid=$(cat "$PID_FILE")
        echo -e "${YELLOW}⚠ Eternal monitor already running${NC} (PID: $pid)"
        echo ""
        echo "Commands:"
        echo "  $0 status   — Show detailed status"
        echo "  $0 logs     — View live logs"
        echo "  $0 health   — Run health check"
        echo "  $0 stop     — Stop monitoring"
        return 1
    fi

    echo -e "${GOLD}Starting Eternal Monitoring...${NC}"
    echo ""

    # Build if needed
    if [ ! -f "zig-out/bin/tri" ]; then
        echo "Building TRI..."
        zig build tri
        echo ""
    fi

    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"

    # Start in background
    nohup ./zig-out/bin/tri monitor --eternal --verbose > "$LOG_FILE" 2>&1 &
    local pid=$!
    echo $pid > "$PID_FILE"

    # Verify it started
    sleep 1
    if ps -p "$pid" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Eternal monitoring started${NC}"
        echo ""
        echo "  PID:       $pid"
        echo "  Interval:  1.618s (φ)"
        echo "  Log file:  $LOG_FILE"
        echo ""
        echo "Commands:"
        echo "  $0 status   — Show detailed status"
        echo "  $0 logs     — View live logs"
        echo "  $0 health   — Run health check"
        echo "  $0 stop     — Stop monitoring"
    else
        echo -e "${RED}✗ Failed to start monitor${NC}"
        rm -f "$PID_FILE"
        return 1
    fi
}

stop_monitor() {
    print_banner

    if ! is_running; then
        echo -e "${YELLOW}⚠ Eternal monitor not running${NC}"
        if [ -f "$PID_FILE" ]; then
            echo "Cleaning up stale PID file..."
            rm -f "$PID_FILE"
        fi
        return 1
    fi

    local pid=$(cat "$PID_FILE")
    echo -e "${GOLD}Stopping eternal monitor${NC} (PID: $pid)..."

    kill "$pid" 2>/dev/null || true

    # Wait for graceful shutdown
    local count=0
    while ps -p "$pid" > /dev/null 2>&1 && [ $count -lt 10 ]; do
        sleep 1
        count=$((count + 1))
    done

    if ps -p "$pid" > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Force killing...${NC}"
        kill -9 "$pid" 2>/dev/null || true
        sleep 1
    fi

    rm -f "$PID_FILE"
    echo -e "${GREEN}✓ Eternal monitor stopped${NC}"
}

show_status() {
    print_banner

    if ! is_running; then
        echo -e "${YELLOW}⚠ Eternal monitor not running${NC}"
        echo ""
        echo "Start with: $0 start"
        return 1
    fi

    local pid=$(cat "$PID_FILE")
    echo -e "${GREEN}✓ Eternal monitor running${NC}"
    echo ""
    echo "  PID:       $pid"
    echo "  Uptime:    $(ps -o etime= -p "$pid" | tr -d ' ')"
    echo "  Memory:    $(ps -o rss= -p "$pid" | awk '{printf "%.1f MB", $1/1024}')"
    echo "  Log file:  $LOG_FILE"
    echo ""

    # Run health check
    echo -e "${CYAN}Health Check:${NC}"
    ./zig-out/bin/tri monitor --health
}

show_logs() {
    if ! is_running; then
        echo -e "${YELLOW}⚠ Eternal monitor not running${NC}"
        return 1
    fi

    echo "Showing live logs (Ctrl+C to exit)..."
    echo ""
    tail -f "$LOG_FILE"
}

show_health() {
    ./zig-out/bin/tri monitor --health
}

show_alerts() {
    ./zig-out/bin/tri monitor --alerts
}

restart_monitor() {
    stop_monitor
    sleep 2
    start_monitor
}

show_help() {
    print_banner
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start     — Start eternal monitoring (default)"
    echo "  stop      — Stop monitoring"
    echo "  restart   — Restart monitoring"
    echo "  status    — Show detailed status"
    echo "  logs      — View live logs (tail -f)"
    echo "  health    — Run health check"
    echo "  alerts    — Show recent alerts"
    echo "  help      — Show this help"
    echo ""
    echo "Sacred Intervals:"
    echo "  Monitor runs at φ-second intervals (1.618s)"
    echo "  Sacred ratio = failures / checks"
    echo "  χ = 0.0618 (warning threshold)"
    echo "  ε = 0.333 (critical threshold)"
}

# Main dispatch
case "${1:-start}" in
    start)
        start_monitor
        ;;
    stop)
        stop_monitor
        ;;
    restart)
        restart_monitor
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    health)
        show_health
        ;;
    alerts)
        show_alerts
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
