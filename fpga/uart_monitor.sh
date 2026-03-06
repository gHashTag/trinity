#!/bin/bash
# =============================================================================
# Trinity UART Monitor - Quick Launch Script
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR="$SCRIPT_DIR/uart_monitor/uart_monitor.py"

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed"
    exit 1
fi

# Check dependencies
if ! python3 -c "import serial" 2>/dev/null; then
    echo "Installing dependencies..."
    pip3 install -r "$SCRIPT_DIR/uart_monitor/requirements.txt"
fi

# Run monitor
case "${1:-list}" in
    list|--list|-l)
        python3 "$MONITOR" --list
        ;;
    *)
        python3 "$MONITOR" "$@"
        ;;
esac
