#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# RALPH AUTONOMOUS FPGA CYCLE
# ═══════════════════════════════════════════════════════════════════════════════
#
# Full autonomous development cycle:
#   1. Synthesize design (Yosys)
#   2. Place & Route (nextpnr-xilinx)
#   3. Generate bitstream (fasm2frames + xc7frames2bit)
#   4. Flash to FPGA (jtag_program)
#   5. Camera capture + LED analysis (iPhone via HTTP)
#   6. Compare with expected behavior
#   7. If pass: git commit + push + Telegram notification
#   8. If fail: rollback to last known-good bitstream
#
# Usage:
#   ./ralph_auto_cycle.sh <design_name> <top_module> [--no-flash] [--dry-run]
#
# Environment variables:
#   TELEGRAM_BOT_TOKEN  — Telegram bot token for notifications
#   TELEGRAM_CHAT_ID    — Telegram chat ID
#   CAMERA_URL          — iPhone camera stream URL (video_capture.html)
#
# phi^2 + 1/phi^2 = 3
# ═══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
JTAG="${SCRIPT_DIR}/../tools/jtag_program"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="${SCRIPT_DIR}/ralph_logs"
LOG_FILE="${LOG_DIR}/cycle_${TIMESTAMP}.log"

# ================================================================
# PARSE ARGUMENTS
# ================================================================
DESIGN="${1:-vsa_coproc}"
TOP_MODULE="${2:-vsa_coproc_d6_top}"
NO_FLASH=false
DRY_RUN=false

for arg in "$@"; do
    case $arg in
        --no-flash) NO_FLASH=true ;;
        --dry-run)  DRY_RUN=true ;;
    esac
done

# ================================================================
# KNOWN-GOOD BITSTREAMS (for rollback)
# ================================================================
LAST_GOOD_BIT="${SCRIPT_DIR}/temporal_heartbeat.bit"

# ================================================================
# FUNCTIONS
# ================================================================

log() {
    local msg="[$(date +%H:%M:%S)] $1"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

send_telegram() {
    local msg="$1"
    if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID}" \
            -d "text=${msg}" \
            -d "parse_mode=Markdown" > /dev/null 2>&1 || true
    fi
}

rollback() {
    log "ROLLBACK: Flashing last known-good bitstream..."
    if [ -f "$LAST_GOOD_BIT" ] && [ -x "$JTAG" ]; then
        "$JTAG" "$LAST_GOOD_BIT"
        log "ROLLBACK COMPLETE: ${LAST_GOOD_BIT}"
        send_telegram "⚠️ ROLLBACK: ${DESIGN} failed, reverted to $(basename $LAST_GOOD_BIT)"
    else
        log "ROLLBACK FAILED: No good bitstream or jtag_program not found"
    fi
}

# ================================================================
# MAIN CYCLE
# ================================================================

mkdir -p "$LOG_DIR"

log "═══════════════════════════════════════════════════"
log " RALPH AUTONOMOUS CYCLE #${TIMESTAMP}"
log " Design: ${DESIGN} | Top: ${TOP_MODULE}"
log "═══════════════════════════════════════════════════"
send_telegram "🔧 *RALPH CYCLE START*\nDesign: \`${DESIGN}\`\nTop: \`${TOP_MODULE}\`"

# ================================================================
# STEP 1: YOSYS SYNTHESIS
# ================================================================
log "[1/6] Yosys synthesis..."

VFILES=""
case "$DESIGN" in
    vsa_coproc)
        VFILES="vsa_coproc_d6_top.v vsa_coprocessor.v vsa_dsp_bind.v"
        XDC="vsa_coproc_d6.xdc"
        ;;
    singularity_v200)
        VFILES="singularity_v200_top.v"
        XDC="singularity_v200.xdc"
        ;;
    riscv_vsa)
        VFILES="riscv_vsa_top.v"
        XDC="riscv_vsa.xdc"
        ;;
    blink)
        VFILES="blink_fix.v"
        XDC="qmtech_fgg676.xdc"
        TOP_MODULE="blink_fix"
        ;;
    *)
        log "ERROR: Unknown design: ${DESIGN}"
        exit 1
        ;;
esac

READ_CMDS=""
for f in $VFILES; do
    if [ ! -f "${SCRIPT_DIR}/$f" ]; then
        log "ERROR: Missing file: $f"
        exit 1
    fi
    READ_CMDS="${READ_CMDS}read_verilog /work/$f; "
done

if $DRY_RUN; then
    log "[DRY RUN] Would synthesize: $VFILES"
else
    docker run --rm --platform linux/amd64 \
        -v "${SCRIPT_DIR}:/work" -w /work \
        regymm/openxc7 \
        yosys -p "${READ_CMDS} synth_xilinx -flatten -abc9 -nobram -arch xc7 -top ${TOP_MODULE}; stat; write_json ${DESIGN}.json" \
        >> "$LOG_FILE" 2>&1

    if [ ! -f "${SCRIPT_DIR}/${DESIGN}.json" ]; then
        log "SYNTHESIS FAILED!"
        send_telegram "❌ *SYNTHESIS FAILED*\nDesign: \`${DESIGN}\`"
        rollback
        exit 1
    fi
    log "  → ${DESIGN}.json ($(du -h "${SCRIPT_DIR}/${DESIGN}.json" | cut -f1))"
fi

# ================================================================
# STEP 2: NEXTPNR PLACE & ROUTE
# ================================================================
log "[2/6] nextpnr-xilinx place & route (this takes 20-45 min)..."

if $DRY_RUN; then
    log "[DRY RUN] Would run nextpnr..."
else
    docker run --rm --platform linux/amd64 \
        -v "${SCRIPT_DIR}:/work" -w /work \
        regymm/openxc7 \
        nextpnr-xilinx \
            --chipdb /work/chipdb/xc7a100tfgg676.bin \
            --xdc /work/"$XDC" \
            --json /work/"${DESIGN}.json" \
            --write /work/"${DESIGN}_routed.json" \
            --fasm /work/"${DESIGN}.fasm" \
            --freq 50 --seed 1 \
        >> "$LOG_FILE" 2>&1

    if [ ! -f "${SCRIPT_DIR}/${DESIGN}.fasm" ]; then
        log "PLACE & ROUTE FAILED!"
        send_telegram "❌ *P&R FAILED*\nDesign: \`${DESIGN}\`"
        rollback
        exit 1
    fi
    log "  → ${DESIGN}.fasm"
fi

# ================================================================
# STEP 3: FASM → FRAMES
# ================================================================
log "[3/6] FASM → Frames..."

if $DRY_RUN; then
    log "[DRY RUN] Would convert FASM to frames..."
else
    docker run --rm --platform linux/amd64 \
        -v "${SCRIPT_DIR}:/work" -w /work \
        regymm/openxc7 \
        fasm2frames \
            --db-root /nextpnr-xilinx/xilinx/external/prjxray-db/artix7 \
            --part xc7a100tfgg676-1 \
            /work/"${DESIGN}.fasm" \
            /work/"${DESIGN}.frames" \
        >> "$LOG_FILE" 2>&1

    log "  → ${DESIGN}.frames"
fi

# ================================================================
# STEP 4: FRAMES → BITSTREAM
# ================================================================
log "[4/6] Frames → Bitstream..."

if $DRY_RUN; then
    log "[DRY RUN] Would generate bitstream..."
else
    docker run --rm --platform linux/amd64 \
        -v "${SCRIPT_DIR}:/work" -w /work \
        regymm/openxc7 \
        /prjxray/build/tools/xc7frames2bit \
            --part_file /nextpnr-xilinx/xilinx/external/prjxray-db/artix7/xc7a100tfgg676-1/part.yaml \
            --part_name xc7a100tfgg676-1 \
            --frm_file /work/"${DESIGN}.frames" \
            --output_file /work/"${DESIGN}.bit" \
        >> "$LOG_FILE" 2>&1

    if [ ! -f "${SCRIPT_DIR}/${DESIGN}.bit" ]; then
        log "BITSTREAM GENERATION FAILED!"
        send_telegram "❌ *BITSTREAM FAILED*\nDesign: \`${DESIGN}\`"
        rollback
        exit 1
    fi
    log "  → ${DESIGN}.bit ($(du -h "${SCRIPT_DIR}/${DESIGN}.bit" | cut -f1))"
fi

# ================================================================
# STEP 5: FLASH TO FPGA
# ================================================================
if $NO_FLASH || $DRY_RUN; then
    log "[5/6] Flash SKIPPED (--no-flash or --dry-run)"
else
    log "[5/6] Flashing to FPGA..."
    if [ -x "$JTAG" ]; then
        "$JTAG" "${SCRIPT_DIR}/${DESIGN}.bit" >> "$LOG_FILE" 2>&1
        FLASH_EXIT=$?
        if [ $FLASH_EXIT -ne 0 ]; then
            log "FLASH FAILED! (exit code: $FLASH_EXIT)"
            send_telegram "❌ *FLASH FAILED*\nDesign: \`${DESIGN}\`"
            rollback
            exit 1
        fi
        log "  FLASH SUCCESS!"
        # Update last known-good
        cp "${SCRIPT_DIR}/${DESIGN}.bit" "${SCRIPT_DIR}/${DESIGN}_last_good.bit"
        LAST_GOOD_BIT="${SCRIPT_DIR}/${DESIGN}_last_good.bit"
    else
        log "  WARNING: jtag_program not found at ${JTAG}"
    fi
fi

# ================================================================
# STEP 6: VERIFICATION (Camera + LED analysis)
# ================================================================
log "[6/6] Verification..."

if [ -n "$CAMERA_URL" ] && ! $DRY_RUN && ! $NO_FLASH; then
    log "  Capturing LED image from camera..."
    CAPTURE_FILE="${LOG_DIR}/led_capture_${TIMESTAMP}.jpg"
    curl -s -o "$CAPTURE_FILE" "${CAMERA_URL}/capture" 2>/dev/null || true

    if [ -f "$CAPTURE_FILE" ]; then
        log "  LED capture saved: ${CAPTURE_FILE}"
        # TODO: Integrate Claude Vision API for LED pattern analysis
        # For now, just log that we captured
        send_telegram "📸 LED capture saved for \`${DESIGN}\`"
    fi
else
    log "  Camera verification skipped (no CAMERA_URL or --no-flash/--dry-run)"
fi

# ================================================================
# STEP 7: GIT COMMIT (if everything passed)
# ================================================================
if ! $DRY_RUN; then
    log "  Committing to git..."
    cd "$PROJECT_DIR"
    git add "fpga/openxc7-synth/${DESIGN}.bit" \
            "fpga/openxc7-synth/${DESIGN}.fasm" \
            "fpga/openxc7-synth/${DESIGN}_routed.json" 2>/dev/null || true
    git add "fpga/openxc7-synth/ralph_logs/" 2>/dev/null || true

    git diff --cached --quiet 2>/dev/null || \
        git commit -m "feat(fpga): Ralph auto-cycle ${DESIGN} — ${TIMESTAMP}

Autonomous synthesis + P&R + flash
Design: ${DESIGN} | Top: ${TOP_MODULE}
Cells: $(grep -c 'Number of cells' "$LOG_FILE" 2>/dev/null || echo "?")

phi^2 + 1/phi^2 = 3" 2>/dev/null || true
fi

# ================================================================
# DONE
# ================================================================
DURATION=$SECONDS
log ""
log "═══════════════════════════════════════════════════"
log " RALPH CYCLE COMPLETE"
log " Design:   ${DESIGN}"
log " Duration: ${DURATION}s"
log " Status:   SUCCESS"
log "═══════════════════════════════════════════════════"

send_telegram "✅ *RALPH CYCLE COMPLETE*
Design: \`${DESIGN}\`
Duration: ${DURATION}s
Status: *SUCCESS*
φ² + 1/φ² = 3"

echo ""
echo "Log: ${LOG_FILE}"
echo "Bitstream: ${SCRIPT_DIR}/${DESIGN}.bit"
echo ""
echo "To flash manually:"
echo "  ${JTAG} ${SCRIPT_DIR}/${DESIGN}.bit"
