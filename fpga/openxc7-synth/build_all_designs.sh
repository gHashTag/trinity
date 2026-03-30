#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY FPGA — Build All Designs Pipeline
# ═══════════════════════════════════════════════════════════════════════════════
#
# Builds all 4 FPGA designs in sequence:
#   1. VSA Coprocessor (bind/bundle/similarity on hardware)
#   2. Singularity V200 (consciousness + DSP + UART)
#   3. DSP Ternary Multiply (DSP48E1 acceleration)
#   4. RISC-V + VSA (processor with ternary memory)
#
# Usage:
#   ./build_all_designs.sh [design_name]   # Build specific design
#   ./build_all_designs.sh all             # Build all designs
#   ./build_all_designs.sh flash <name>    # Flash specific design
#
# phi^2 + 1/phi^2 = 3
# ═══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JTAG="${SCRIPT_DIR}/../tools/jtag_program"

# ================================================================
# DESIGN REGISTRY
# ================================================================
declare -A DESIGNS
declare -A TOPS
declare -A XDCS
declare -A VFILES

# Design 1: VSA Coprocessor
DESIGNS[vsa_coproc]="VSA Coprocessor — bind/bundle/similarity"
TOPS[vsa_coproc]="vsa_coproc_d6_top"
XDCS[vsa_coproc]="vsa_coproc_d6.xdc"
VFILES[vsa_coproc]="vsa_coproc_d6_top.v vsa_coprocessor.v vsa_dsp_bind.v"

# Design 2: Singularity V200
DESIGNS[singularity]="Singularity V200 — consciousness + DSP"
TOPS[singularity]="singularity_d6_top"
XDCS[singularity]="qmtech_fgg676.xdc"
VFILES[singularity]="singularity_d6_top.v singularity_core.v100.v"

# Design 3: DSP Ternary
DESIGNS[dsp_ternary]="DSP48E1 Ternary Multiply"
TOPS[dsp_ternary]="dsp_mul32_top"
XDCS[dsp_ternary]="qmtech_fgg676.xdc"
VFILES[dsp_ternary]="dsp_mul32.v"

# Design 4: Blink Fix (known-good simple design for testing)
DESIGNS[blink]="Blink Fix — chaotic LED test"
TOPS[blink]="blink_fix"
XDCS[blink]="qmtech_fgg676.xdc"
VFILES[blink]="blink_fix.v"

# ================================================================
# FUNCTIONS
# ================================================================

build_design() {
    local name=$1
    local top=${TOPS[$name]}
    local xdc=${XDCS[$name]}
    local vfiles=${VFILES[$name]}
    local desc=${DESIGNS[$name]}

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  BUILDING: $desc"
    echo "  Top:      $top"
    echo "  XDC:      $xdc"
    echo "  Verilog:  $vfiles"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Check all files exist
    for f in $vfiles; do
        if [ ! -f "${SCRIPT_DIR}/$f" ]; then
            echo "ERROR: Missing Verilog file: $f"
            return 1
        fi
    done

    if [ ! -f "${SCRIPT_DIR}/$xdc" ]; then
        echo "ERROR: Missing XDC file: $xdc"
        return 1
    fi

    local base="${name}"

    # Step 1: Yosys synthesis
    echo "[1/4] Yosys synthesis..."
    local read_cmds=""
    for f in $vfiles; do
        read_cmds="${read_cmds}read_verilog /work/$f; "
    done

    docker run --rm --platform linux/amd64 \
        -v "${SCRIPT_DIR}:/work" -w /work \
        regymm/openxc7 \
        yosys -p "${read_cmds} synth_xilinx -flatten -abc9 -nobram -arch xc7 -top ${top}; write_json ${base}.json"

    echo "  -> ${base}.json ($(du -h "${SCRIPT_DIR}/${base}.json" | cut -f1))"

    # Step 2: nextpnr-xilinx (try local first, fallback to Docker)
    echo "[2/4] nextpnr-xilinx place & route..."

    local NEXTPNR_LOCAL="${SCRIPT_DIR}/../nextpnr-xilinx/build/nextpnr-xilinx"
    local CHIPDB_LOCAL="${SCRIPT_DIR}/chipdb/xc7a100tfgg676.bin"

    if [ -x "$NEXTPNR_LOCAL" ] && [ -f "$CHIPDB_LOCAL" ]; then
        echo "  Using local nextpnr-xilinx..."
        "$NEXTPNR_LOCAL" \
            --chipdb "$CHIPDB_LOCAL" \
            --json "${SCRIPT_DIR}/${base}.json" \
            --xdc "${SCRIPT_DIR}/${xdc}" \
            --write "${SCRIPT_DIR}/${base}_routed.json" \
            --fasm "${SCRIPT_DIR}/${base}.fasm" \
            --top "${top}" \
            --freq 50 --seed 1
    else
        echo "  Using Docker nextpnr-xilinx..."
        docker run --rm --platform linux/amd64 \
            -v "${SCRIPT_DIR}:/work" -w /work \
            regymm/openxc7 \
            nextpnr-xilinx \
                --chipdb /work/chipdb/xc7a100tfgg676.bin \
                --xdc /work/"$xdc" \
                --json /work/"${base}.json" \
                --write /work/"${base}_routed.json" \
                --fasm /work/"${base}.fasm" \
                --freq 50 --seed 1
    fi

    echo "  -> ${base}.fasm"

    # Step 3: FASM -> Frames
    echo "[3/4] FASM to frames..."

    local FASM2FRAMES_LOCAL="${SCRIPT_DIR}/../prjxray/utils/fasm2frames.py"
    local PRJXRAY_DB="${SCRIPT_DIR}/../prjxray/database/artix7"

    if [ -f "$FASM2FRAMES_LOCAL" ] && [ -d "$PRJXRAY_DB" ]; then
        echo "  Using local fasm2frames..."
        PYTHONPATH="${SCRIPT_DIR}/../prjxray:$PYTHONPATH" \
        python3 "$FASM2FRAMES_LOCAL" \
            --db-root "$PRJXRAY_DB" \
            --part xc7a100tfgg676-1 \
            "${SCRIPT_DIR}/${base}.fasm" \
            "${SCRIPT_DIR}/${base}.frames"
    else
        echo "  Using Docker fasm2frames..."
        docker run --rm --platform linux/amd64 \
            -v "${SCRIPT_DIR}:/work" -w /work \
            regymm/openxc7 \
            fasm2frames \
                --db-root /nextpnr-xilinx/xilinx/external/prjxray-db/artix7 \
                --part xc7a100tfgg676-1 \
                /work/"${base}.fasm" \
                /work/"${base}.frames"
    fi

    echo "  -> ${base}.frames"

    # Step 4: Frames -> Bitstream
    echo "[4/4] Frames to bitstream..."

    local XC7FRAMES="${SCRIPT_DIR}/../prjxray/build/tools/xc7frames2bit"
    local PART_YAML="${PRJXRAY_DB}/xc7a100tfgg676-1/part.yaml"

    if [ -x "$XC7FRAMES" ] && [ -f "$PART_YAML" ]; then
        echo "  Using local xc7frames2bit..."
        "$XC7FRAMES" \
            --part_name xc7a100tfgg676-1 \
            --part_file "$PART_YAML" \
            --frm_file "${SCRIPT_DIR}/${base}.frames" \
            --output_file "${SCRIPT_DIR}/${base}.bit" \
            --architecture Series7
    else
        echo "  Using Docker xc7frames2bit..."
        docker run --rm --platform linux/amd64 \
            -v "${SCRIPT_DIR}:/work" -w /work \
            regymm/openxc7 \
            /prjxray/build/tools/xc7frames2bit \
                --part_file /nextpnr-xilinx/xilinx/external/prjxray-db/artix7/xc7a100tfgg676-1/part.yaml \
                --part_name xc7a100tfgg676-1 \
                --frm_file /work/"${base}.frames" \
                --output_file /work/"${base}.bit"
    fi

    echo "  -> ${base}.bit ($(du -h "${SCRIPT_DIR}/${base}.bit" | cut -f1))"

    echo ""
    echo "  BUILD COMPLETE: $desc"
    echo "  Flash: $JTAG ${base}.bit"
    echo ""
}

flash_design() {
    local name=$1
    local bitfile="${SCRIPT_DIR}/${name}.bit"

    if [ ! -f "$bitfile" ]; then
        echo "ERROR: Bitstream not found: $bitfile"
        echo "Run: $0 $name    (to build first)"
        return 1
    fi

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  FLASHING: ${DESIGNS[$name]}"
    echo "  Bitstream: ${name}.bit"
    echo "═══════════════════════════════════════════════"
    echo ""

    if [ -x "$JTAG" ]; then
        "$JTAG" "$bitfile"
    else
        echo "ERROR: jtag_program not found at: $JTAG"
        echo "You can flash manually with xc3sprog or openFPGALoader"
        return 1
    fi
}

# ================================================================
# MAIN
# ================================================================

case "${1:-help}" in
    all)
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  TRINITY FPGA — Building ALL Designs                         ║"
        echo "║  phi^2 + 1/phi^2 = 3                                        ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        for name in blink vsa_coproc singularity dsp_ternary; do
            build_design "$name" || echo "FAILED: $name"
        done
        echo ""
        echo "ALL BUILDS COMPLETE. Available bitstreams:"
        ls -la "${SCRIPT_DIR}"/*.bit 2>/dev/null | awk '{print "  " $NF " (" $5 " bytes)"}'
        ;;

    flash)
        if [ -z "$2" ]; then
            echo "Usage: $0 flash <design_name>"
            echo "Available: ${!DESIGNS[@]}"
            exit 1
        fi
        flash_design "$2"
        ;;

    help|--help|-h)
        echo "TRINITY FPGA Build System"
        echo ""
        echo "Usage:"
        echo "  $0 <design>       Build specific design"
        echo "  $0 all            Build all designs"
        echo "  $0 flash <design> Flash design to FPGA"
        echo ""
        echo "Available designs:"
        for name in "${!DESIGNS[@]}"; do
            echo "  $name — ${DESIGNS[$name]}"
        done
        echo ""
        echo "Examples:"
        echo "  $0 vsa_coproc            # Build VSA coprocessor"
        echo "  $0 flash vsa_coproc      # Flash VSA coprocessor"
        echo "  $0 blink && $0 flash blink  # Build and flash blink test"
        ;;

    *)
        if [ -n "${DESIGNS[$1]}" ]; then
            build_design "$1"
        else
            echo "Unknown design: $1"
            echo "Available: ${!DESIGNS[@]}"
            exit 1
        fi
        ;;
esac
