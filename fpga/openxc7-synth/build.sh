#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VSA Pipeline Build Script — KOSCHEI Week 4
# ═══════════════════════════════════════════════════════════════════════════════
#
# Synthesizes VSA pipeline for XC7A100T using openxc7-synth
# Generates bitstream for deployment to Arty A7-100T
#
# Usage:
#   ./build.sh              # Full build (synthesis + bitstream)
#   ./build.sh synth        # Synthesis only
#   ./build.sh bitstream    # Bitstream only (skip synthesis)
#   ./build.sh clean        # Clean build artifacts
#
# φ² + 1/φ² = 3
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP_MODULE="vsa_pipeline_256_top"
PART="xc7a100tcsg324-1"
TARGET_FREQ="50"  # MHz

BUILD_DIR="$PROJECT_DIR/build"
OUTPUT_BIT="$BUILD_DIR/vsa_pipeline.bit"
OUTPUT_JSON="$BUILD_DIR/vsa_pipeline.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ═══════════════════════════════════════════════════════════════════════════════
# FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  VSA Pipeline Build — KOSCHEI Week 4                       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
}

check_dependencies() {
    log_info "Checking dependencies..."

    local missing=()

    command -v yosys >/dev/null 2>&1 || missing+=("yosys")
    command -v nextpnr-xilinx >/dev/null 2>&1 || missing+=("nextpnr-xilinx")
    command -v fasm2frames >/dev/null 2>&1 || missing+=("fasm2frames")
    command -v xc7patch >/dev/null 2>&1 || missing+=("xc7patch")
    command -z bit2frag >/dev/null 2>&1 || missing+=("bit2frag")

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        echo ""
        echo "Install with: brew install yosys"
        echo "Or build from source:"
        echo "  - nextpnr-xilinx: https://github.com/YosysHQ/nextpnr"
        echo "  - fasm2frames: https://github.com/SymbiFlow/fasm2frames"
        echo "  - xc7patch: https://github.com/SymbiFlow/prjxray"
        exit 1
    fi

    log_success "All dependencies found"
}

clean_build() {
    log_info "Cleaning build artifacts..."
    rm -rf "$BUILD_DIR"
    log_success "Clean complete"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SYNTHESIS
# ═══════════════════════════════════════════════════════════════════════════════

run_synthesis() {
    log_info "Running Yosys synthesis..."

    mkdir -p "$BUILD_DIR"

    cd "$PROJECT_DIR"

    yosys -p "
        # Read design
        read_verilog vsa_pipeline_256.v

        # Synthesize for Xilinx 7-series
        synth_xilinx -top $TOP_MODULE

        # Write JSON for nextpnr
        write_json $OUTPUT_JSON

        # Show statistics
        stat
    " 2>&1 | tee "$BUILD_DIR/synth.log"

    if [ ! -f "$OUTPUT_JSON" ]; then
        log_error "Synthesis failed: $OUTPUT_JSON not found"
        exit 1
    fi

    # Extract stats from log
    local num_cells=$(grep -oP 'Number of cells: *\K[0-9]+' "$BUILD_DIR/synth.log" || echo "unknown")
    local num_luts=$(grep -oP '   \$__XILINX_LUT.*:\s*\K[0-9]+' "$BUILD_DIR/synth.log" || echo "unknown")
    local num_ffs=$(grep -oP '   \$__XILINX_FF.*:\s*\K[0-9]+' "$BUILD_DIR/synth.log" || echo "unknown")

    log_success "Synthesis complete"
    echo "  Cells: $num_cells"
    echo "  LUTs:  $num_luts"
    echo "  FFs:   $num_ffs"
}

# ═══════════════════════════════════════════════════════════════════════════════
# PLACE AND ROUTE
# ═══════════════════════════════════════════════════════════════════════════════

run_pnr() {
    log_info "Running place and route..."

    nextpnr-xilinx --chipdb "$PROJECT_DIR/chipdb/$PART.bin" \
        --json "$OUTPUT_JSON" \
        --write "$BUILD_DIR/vsa_pipeline_routed.json" \
        --fasm "$BUILD_DIR/vsa_pipeline.fasm" \
        --part "$PART" \
        --freq "$TARGET_FREQ" \
        --report "$BUILD_DIR/timing_report.txt" \
        --xdc constraints.xdc \
        2>&1 | tee "$BUILD_DIR/pnr.log"

    # Check timing report
    if grep -q "Setup time violation" "$BUILD_DIR/timing_report.txt" 2>/dev/null; then
        log_warning "Timing violations detected (see $BUILD_DIR/timing_report.txt)"
    else
        log_success "Timing constraints met"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# BITSTREAM GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

generate_bitstream() {
    log_info "Generating bitstream..."

    # Convert FASM to frames
    fasm2frames --part "$PART" \
        "$BUILD_DIR/vsa_pipeline.fasm" \
        > "$BUILD_DIR/vsa_pipeline.frames"

    # Patch frames with database
    xc7patch --part_file "$PROJECT_DIR/chipdb/$PART.patch" \
        --output_dir "$BUILD_DIR" \
        --frm_dir "$BUILD_DIR" \
        "$BUILD_DIR/vsa_pipeline.frames"

    # Convert to bitstream
    bit2frag "$BUILD_DIR/vsa_pipeline.bit" "$BUILD_DIR/vsa_pipeline.fragments"

    if [ ! -f "$OUTPUT_BIT" ]; then
        log_error "Bitstream generation failed"
        exit 1
    fi

    local bit_size=$(stat -f%z "$OUTPUT_BIT" 2>/dev/null || stat -c%s "$OUTPUT_BIT" 2>/dev/null)
    log_success "Bitstream generated: $OUTPUT_BIT ($bit_size bytes)"
}

# ═══════════════════════════════════════════════════════════════════════════════
# DEPLOYMENT
# ═══════════════════════════════════════════════════════════════════════════════

deploy_bitstream() {
    log_info "Deploying bitstream to FPGA..."

    # Check for openocd or xc3sprog
    if command -v openocd >/dev/null 2>&1; then
        log_info "Using OpenOCD for deployment..."
        openocd -f interface/ftdi/ftdi-olimex-arm-usb-tiny-h.cfg \
            -f board/digilent_arty.cfg \
            -c "init; pld load 0 $OUTPUT_BIT; exit"
    elif command -v xc3sprog >/dev/null 2>&1; then
        log_info "Using xc3sprog for deployment..."
        xc3sprog "$OUTPUT_BIT"
    else
        log_warning "No deployment tool found. Install openocd or xc3sprog"
        log_info "Manual deployment: Copy $OUTPUT_BIT to SD card or use Vivado"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    print_header

    local target="${1:-full}"

    case "$target" in
        clean)
            clean_build
            exit 0
            ;;
        synth)
            check_dependencies
            run_synthesis
            ;;
        pnr)
            check_dependencies
            if [ ! -f "$OUTPUT_JSON" ]; then
                log_warning "No synthesized JSON found, running synthesis first"
                run_synthesis
            fi
            run_pnr
            ;;
        bitstream)
            check_dependencies
            if [ ! -f "$BUILD_DIR/vsa_pipeline.fasm" ]; then
                log_warning "No FASM file found, running PnR first"
                run_pnr
            fi
            generate_bitstream
            ;;
        deploy)
            deploy_bitstream
            ;;
        full|"")
            check_dependencies
            run_synthesis
            run_pnr
            generate_bitstream

            echo ""
            log_success "Build complete!"
            echo "  Bitstream: $OUTPUT_BIT"
            echo ""
            echo "Deploy to FPGA:"
            echo "  ./build.sh deploy"
            ;;
        *)
            log_error "Unknown target: $target"
            echo "Usage: $0 [clean|synth|pnr|bitstream|deploy|full]"
            exit 1
            ;;
    esac
}

main "$@"

# φ² + 1/φ² = 3 = TRINITY
