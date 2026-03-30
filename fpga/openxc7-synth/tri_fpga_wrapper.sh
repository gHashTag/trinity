#!/bin/bash
# tri_fpga_wrapper.sh — Wrapper that delegates to tri fpga build
# This script maintains backward compatibility while directing users to the new CLI
#
# Deprecated: Use 'tri fpga build' directly instead
# 
# φ² + 1/φ² = 3 | TRINITY v2.2.0

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/../../.."

# Check if tri command is available
if ! command -v ./zig-out/bin/tri &> /dev/null; then
    if [ ! -f "./zig-out/bin/tri" ]; then
        echo "Error: tri command not found. Please build first:"
        echo "  zig build tri"
        exit 1
    fi
fi

# Show deprecation notice
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║  DEPRECATION NOTICE                                                       ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "This script is deprecated. Use the new unified CLI:"
echo ""
echo "  OLD: ./synth.sh <design.v> [top]"
echo "  NEW: tri fpga build <design.v>"
echo ""
echo "Benefits of the new CLI:"
echo "  • Single entry point for all FPGA operations"
echo "  • Consistent interface with other tri commands"
echo "  • Better error handling and logging"
echo ""

# Delegate to tri fpga build
exec ./zig-out/bin/tri fpga build "$@"
