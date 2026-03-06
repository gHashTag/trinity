#!/bin/bash
# =============================================================================
# Build and Flash UART Bridge for ESP32-FPGA Connection
# =============================================================================
#
# Usage:
#   ./build_uart_bridge.sh          # Build only
#   ./build_uart_bridge.sh flash    # Build + Flash
#   ./build_uart_bridge.sh clean    # Clean build files
#
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENXC7_DIR="$SCRIPT_DIR/openxc7-synth"
DESIGN="uart_bridge"
TOP_MODULE="uart_bridge"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
check_docker() {
    if ! docker ps &> /dev/null; then
        log_error "Docker is not running. Please start Docker."
        exit 1
    fi
}

# Check if openxc7 image exists
check_image() {
    if ! docker images | grep -q "regymm/openxc7"; then
        log_warn "openXC7 Docker image not found. Pulling..."
        docker pull regymm/openxc7:latest
    fi
}

# Build with openXC7
build_fpga() {
    log_info "Building FPGA UART Bridge..."
    cd "$OPENXC7_DIR"

    # Check if design file exists
    if [ ! -f "${DESIGN}.v" ]; then
        log_error "Design file not found: ${DESIGN}.v"
        exit 1
    fi

    # Check if XDC exists, create if not
    if [ ! -f "${DESIGN}.xdc" ]; then
        log_info "Creating XDC constraints..."
        cat > "${DESIGN}.xdc" << 'EOF'
# Clock
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# UART RX (from ESP32 TX - Pin L20)
set_property LOC L20 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

# UART TX (to ESP32 RX - Pin K20)
set_property LOC K20 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]

# Status LED
set_property LOC T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
EOF
    fi

    # Synthesize with Yosys
    log_info "Synthesizing with Yosys..."
    docker run --rm --platform linux/amd64 \
        -v "$(pwd):/work" -w /work \
        regymm/openxc7 \
        yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top ${TOP_MODULE}; \
                  write_json ${DESIGN}.json" \
        ${DESIGN}.v

    # Place and route with nextpnr-xilinx
    log_info "Place & Route with nextpnr-xilinx..."
    docker run --rm --platform linux/amd64 \
        -v "$(pwd):/work" -w /work \
        regymm/openxc7 \
        nextpnr-xilinx --json ${DESIGN}.json \
        --fasm ${DESIGN}.fasm \
        --xdc ${DESIGN}.xdc

    # Convert FASM to bitstream
    log_info "Converting FASM to bitstream..."
    docker run --rm --platform linux/amd64 \
        -v "$(pwd):/work" -w /work \
        regymm/openxc7 \
        bash -c "fasm2frames ${DESIGN}.fasm > ${DESIGN}.frames && \
                 xc7frames2bit --part_file xc7a100tfgg676 \
                 --part_name xc7a100t-test \
                 --output_file ${DESIGN}.bit < ${DESIGN}.frames"

    log_info "Build complete! Bitstream: ${DESIGN}.bit"
}

# Flash to FPGA
flash_fpga() {
    log_info "Flashing FPGA..."

    # Check if JTAG cable is connected
    if ! system_profiler SPUSBDataType 2>/dev/null | grep -q "0x03fd"; then
        log_error "Xilinx JTAG cable not found!"
        exit 1
    fi

    # Load firmware
    log_info "Loading JTAG cable firmware..."
    sudo "$SCRIPT_DIR/tools/fxload" \
        -v -t fx2 \
        -d 03fd:0013 \
        -i "$SCRIPT_DIR/tools/xusb_xp2.hex"

    log_warn "Please replug the JTAG cable now..."
    log_warn "Press Enter when ready..."
    read

    # Flash bitstream
    log_info "Programming FPGA with ${DESIGN}.bit..."
    sudo "$SCRIPT_DIR/tools/jtag_program" "$OPENXC7_DIR/${DESIGN}.bit"

    log_info "Flash complete!"
}

# Clean build files
clean_build() {
    log_info "Cleaning build files..."
    cd "$OPENXC7_DIR"
    rm -f ${DESIGN}.{json,fasm,frames,bit}
    log_info "Clean complete!"
}

# Show wiring info
show_wiring() {
    cat << 'EOF'

╔══════════════════════════════════════════════════════════════════════╗
║                    UART Bridge Wiring Guide                          ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  ESP32 DIYTZT Board              FPGA Artix-7                        ║
║  ─────────────────              ────────────                         ║
║  GPIO4 (TX) ──────────────────> L20 (UART_RX)                       ║
║  GPIO5 (RX) <────────────────── K20 (UART_TX)                       ║
║  GND ────────────────────────── GND (CRITICAL!)                     ║
║                                                                      ║
║  Serial Monitor Commands:                                            ║
║    p - PING           (Test communication)                           ║
║    o - LED ON         (Turn on FPGA LED)                             ║
║    f - LED OFF        (Turn off FPGA LED)                            ║
║    b - LED BLINK      (Blink FPGA LED)                               ║
║    t - Test sequence  (Run all tests)                                ║
║    s - Status         (Show statistics)                              ║
║    h - Help           (Show this info)                               ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

EOF
}

# Main
main() {
    case "${1:-build}" in
        build)
            check_docker
            check_image
            build_fpga
            show_wiring
            ;;
        flash)
            flash_fpga
            ;;
        all)
            check_docker
            check_image
            build_fpga
            flash_fpga
            ;;
        clean)
            clean_build
            ;;
        *)
            echo "Usage: $0 {build|flash|all|clean}"
            exit 1
            ;;
    esac
}

main "$@"
