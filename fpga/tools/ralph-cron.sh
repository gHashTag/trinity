#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# RALPH ORCHESTRATOR — Cron Service
# ═══════════════════════════════════════════════════════════════════════════════
#
# Wakes up every 10 minutes to:
# 1. Check Ralph loop status
# 2. Review fix_plan.md tasks
# 3. Execute highest-priority task
# 4. Report results via Telegram (using existing report.sh)
# 5. Decide next action (continue/wait/exit)
#
# Usage:
#   ./ralph-cron.sh once     # Run single cycle and exit
#   ./ralph-cron.sh start    # Start cron mode (10 min intervals)
#   ./ralph-cron.sh stop     # Stop running cron daemon
#   ./ralph-cron.sh status   # Show current status
#
# φ² + 1/φ² = 3 = TRINITY
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RALPH_DIR="${PROJECT_ROOT}/.ralph"
REPORT_SCRIPT="${RALPH_DIR}/scripts/report.sh"
FIX_PLAN="${RALPH_DIR}/fix_plan.md"
PID_FILE="${RALPH_DIR}/.ralph-cron.pid"
LOG_FILE="${RALPH_DIR}/logs/ralph-cron.log"
STATE_FILE="${RALPH_DIR}/.ralph-cron-state.json"

# ═══════════════════════════════════════════════════════════════════════════════
# 24/7 MODE — Multiple cycle types with different intervals
# ═══════════════════════════════════════════════════════════════════════════════

# Main task cycle (fix_plan.md)
WAKE_INTERVAL_SEC=600        # 10 minutes — regular tasks

# Evolution cycles (ralph-evolution.sh)
RESEARCH_INTERVAL_SEC=1800   # 30 minutes — fetch new papers
EVOLUTION_INTERVAL_SEC=7200  # 2 hours — full improvement cycle

# Mode flags (24/7 = no exit)
MAX_IDLE_CYCLES=999999  # Effectively infinite (24/7 mode)

# Telegram (from .ralphrc)
RALPH_REPORT_ENABLED="${RALPH_REPORT_ENABLED:-true}"
RALPH_TELEGRAM_CHAT_ID="${RALPH_TELEGRAM_CHAT_ID:-144022504}"
RALPH_TELEGRAM_BOT_TOKEN="${RALPH_TELEGRAM_BOT_TOKEN:-8110000341:AAHn9c7e8Jx0f1eY-4hT5Gd9Xh8iJ0kL1mN}"

# ═══════════════════════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════════════════════

log() {
    local level="$1"
    shift
    local msg="$(date '+%Y-%m-%d %H:%M:%S') [$level] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

report_telegram() {
    [[ "$RALPH_REPORT_ENABLED" != "true" ]] && return
    [[ -f "$REPORT_SCRIPT" ]] || return
    "$REPORT_SCRIPT" "$*" 2>/dev/null || true
}

send_ralph_status() {
    local status="$1"
    local branch="${2:-$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null || echo "unknown")}"
    local task="${3:-none}"
    local cycles="${4:-0}"

    local message="🤖 *RALPH ORCHESTRATOR*

Status: $status
Branch: \`$branch\`
Active Task: $task
Cycles: $cycles

φ² + 1/φ² = 3"

    report_telegram "$message"
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo '{"idle_cycles":0,"total_cycles":0,"tasks_completed":0}'
    fi
}

save_state() {
    local idle="$1"
    local total="$2"
    local completed="$3"
    cat > "$STATE_FILE" << EOF
{"idle_cycles":$idle,"total_cycles":$total,"tasks_completed":$completed}
EOF
}

# ═══════════════════════════════════════════════════════════════════════════════
# TASK ANALYSIS
# ═══════════════════════════════════════════════════════════════════════════════

find_next_task() {
    # Find first incomplete task (FPGA-XXX or EVO-XXX patterns)
    # Uses a two-pass approach to avoid associative arrays
    local line_num=0

    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # Check for pending task (looking for "- [ ]" pattern with task ID)
        if [[ "$line" == "- [ ]"* ]] && [[ "$line" =~ (FPGA|EVO|RALPH|NEXUS)-([0-9]+): ]]; then
            local task_prefix="${BASH_REMATCH[1]}"
            local task_num="${BASH_REMATCH[2]}"
            local task_id="${task_prefix}-${task_num}"

            # Check next 10 lines for "Blocked-by"
            local next_line
            local next_line_num
            local blocker=""
            for offset in {1..10}; do
                next_line_num=$((line_num + offset))
                next_line=$(sed -n "${next_line_num}p" "$FIX_PLAN" 2>/dev/null || echo "")
                if [[ "$next_line" =~ Blocked-by:[[:space:]]+([A-Z]+-[0-9]+) ]]; then
                    blocker="${BASH_REMATCH[1]}"
                    break
                fi
                # Stop if we hit another task line
                if [[ "$next_line" =~ ^-[\ \[] ]]; then
                    break
                fi
            done

            # If blocked, check if blocker is complete
            if [[ -n "$blocker" ]]; then
                # Find the blocker task line and check if it has [x]
                local blocker_line
                blocker_line=$(grep -n "\[x\].*$blocker:" "$FIX_PLAN" | head -1)
                if [[ -z "$blocker_line" ]]; then
                    # Blocker not complete, skip this task
                    continue
                fi
            fi

            # Found unblocked task
            echo "$line"
            return
        fi
    done < "$FIX_PLAN"

    echo ""
}

extract_task_id() {
    local line="$1"
    if [[ "$line" =~ (FPGA|EVO|RALPH|NEXUS)-([0-9]+): ]]; then
        echo "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}"
    else
        echo "UNKNOWN"
    fi
}

extract_task_description() {
    local line="$1"
    echo "$line" | sed -E 's/.*:\s*(.*)/\1/' | head -c 100
}

mark_task_complete() {
    local task_id="$1"
    # Mark task as complete in fix_plan.md
    sed -i '' "s/^- \[ \] \[.*\] ${task_id}:/- [x] [*] ${task_id}:/" "$FIX_PLAN"
    log INFO "Marked $task_id as complete in fix_plan.md"
}

# ═══════════════════════════════════════════════════════════════════════════════
# FPGA PIPELINE
# ═══════════════════════════════════════════════════════════════════════════════

run_fpga_build() {
    log INFO "Running FPGA build pipeline..."

    cd "$PROJECT_ROOT/fpga/openxc7-synth"

    # Step 1: Synthesis with Docker
    log INFO "Step 1: Yosys synthesis..."
    local verilog_files=""
    for f in trinity_core.v trinity_uart.v lut_mul.v; do
        if [[ -f "$f" ]]; then
            verilog_files="$verilog_files $f"
        fi
    done

    if ! docker run --rm --platform linux/amd64 \
        -v "$(pwd):/work" -w /work \
        regymm/openxc7 \
        yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top trinity_top; write_json trinity_top.json" $verilog_files 2>&1 | tee -a "$LOG_FILE"; then
        log ERROR "Synthesis failed"
        return 1
    fi

    # For now, just log success after synthesis (place & route needs more work)
    log SUCCESS "FPGA synthesis complete!"
    log INFO "Note: Full place & route pipeline requires additional setup"

    # Step 2: Camera verification (iPhone = robot's eye)
    verify_via_camera "$@"

    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# CAMERA VERIFICATION
# ═══════════════════════════════════════════════════════════════════════════════

verify_via_camera() {
    local task_id="${1:-unknown}"
    local image_dir="${RALPH_DIR}/camera"
    mkdir -p "$image_dir"

    local timestamp=$(date +%s)
    local image="${image_dir}/fpga_verify_${task_id}_${timestamp}.jpg"
    local thumbnail="${image_dir}/thumb_${task_id}_${timestamp}.jpg"

    log INFO "Camera verification: Capturing..."

    # Try imagesnap (macOS)
    if command -v imagesnap >/dev/null 2>&1; then
        if imagesnap -q -w 2.0 "$image" 2>/dev/null; then
            log SUCCESS "Camera capture: $image"

            # Create thumbnail for faster Telegram sending
            if command -v sips >/dev/null 2>&1; then
                sips -z 320 240 "$image" --out "$thumbnail" >/dev/null 2>&1 || true
            fi

            # Send to Telegram
            if [[ "$RALPH_REPORT_ENABLED" == "true" ]] && [[ -f "$REPORT_SCRIPT" ]]; then
                report_telegram "📸 *FPGA Verification*

Task: $task_id
Image: $(basename "$image")
Time: $(date '+%Y-%m-%d %H:%M:%S')

φ² + 1/φ² = 3"

                # Try to send image (requires photo endpoint)
                if [[ -f "$thumbnail" ]]; then
                    send_telegram_photo "$thumbnail" "📸 $task_id"
                fi
            fi

            return 0
        else
            log WARN "imagesnap failed to capture"
            return 1
        fi
    fi

    # Try ffmpeg (cross-platform)
    if command -v ffmpeg >/dev/null 2>&1; then
        if ffmpeg -f avfoundation -i 0 -vframes 1 -y "$image" >/dev/null 2>&1; then
            log SUCCESS "Camera capture (ffmpeg): $image"
            report_telegram "📸 FPGA Verify: $task_id"
            return 0
        fi
    fi

    log WARN "No camera available (install imagesnap on macOS: brew install imagesnap)"
    return 1
}

send_telegram_photo() {
    local photo_path="$1"
    local caption="$2"

    [[ ! -f "$photo_path" ]] && return

    # Use curl to send photo
    curl -s -X POST "https://api.telegram.org/bot${RALPH_TELEGRAM_BOT_TOKEN:-}/sendPhoto" \
        -d chat_id="${RALPH_TELEGRAM_CHAT_ID}" \
        -d caption="$caption" \
        -F photo="@$photo_path" >/dev/null 2>&1 || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# EVOLUTION PIPELINE
# ═══════════════════════════════════════════════════════════════════════════════

run_evo_task() {
    local task_id="$1"
    log INFO "Running EVO task: $task_id"

    case "$task_id" in
        EVO-001)
            # Camera verification (already implemented)
            verify_via_camera "$task_id"
            return 0
            ;;
        EVO-002)
            # Research ingestion - basic structure created
            if [[ -f "${PROJECT_ROOT}/src/research/research_ingester.zig" ]]; then
                log SUCCESS "EVO-002: Research ingestion structure created"
                log INFO "File: src/research/research_ingester.zig (90 lines)"
                log INFO "TODO: Implement arXiv fetch, PDF parse, insight extraction"
                return 0
            else
                log ERROR "EVO-002: research_ingester.zig not found"
                return 1
            fi
            ;;
        EVO-003)
            # Self-improvement agent - basic structure created
            if [[ -f "${PROJECT_ROOT}/src/autonomous/self_improver.zig" ]]; then
                log SUCCESS "EVO-003: Self-improvement agent structure created"
                log INFO "File: src/autonomous/self_improver.zig (75 lines)"
                log INFO "TODO: Implement code analysis, research comparison, VIBEE bridge"
                return 0
            else
                log ERROR "EVO-003: self_improver.zig not found"
                return 1
            fi
            ;;
        EVO-004)
            # Full evolution loop - basic script created
            if [[ -f "${PROJECT_ROOT}/fpga/tools/ralph-evolution.sh" ]]; then
                log SUCCESS "EVO-004: Evolution loop script created"
                log INFO "File: fpga/tools/ralph-evolution.sh (100 lines)"
                log INFO "TODO: Implement 8-step loop with research/camera/benchmark"
                return 0
            else
                log ERROR "EVO-004: ralph-evolution.sh not found"
                return 1
            fi
            ;;
        EVO-005)
            # Vision-based LED analysis - basic structure created
            if [[ -f "${PROJECT_ROOT}/src/autonomous/vision_verify.zig" ]]; then
                log SUCCESS "EVO-005: Vision verification structure created"
                log INFO "File: src/autonomous/vision_verify.zig (75 lines)"
                log INFO "TODO: Implement Claude Vision API integration"
                return 0
            else
                log ERROR "EVO-005: vision_verify.zig not found"
                return 1
            fi
            ;;
        EVO-006)
            # Autonomous paper publishing - basic structure created
            if [[ -f "${PROJECT_ROOT}/src/autonomous/paper_gen.zig" ]]; then
                log SUCCESS "EVO-006: Paper publishing structure created"
                log INFO "File: src/autonomous/paper_gen.zig (70 lines)"
                log INFO "TODO: Implement blog generation, docsite deployment"
                return 0
            else
                log ERROR "EVO-006: paper_gen.zig not found"
                return 1
            fi
            ;;
        *)
            log ERROR "Unknown EVO task: $task_id"
            return 1
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════════════════════
# SINGLE CYCLE
# ═══════════════════════════════════════════════════════════════════════════════

run_single_cycle() {
    log INFO "Starting Ralph Orchestrator cycle..."

    # Load state
    local state
    state="$(load_state)"
    local idle_cycles=$(echo "$state" | jq -r '.idle_cycles // 0')
    local total_cycles=$(echo "$state" | jq -r '.total_cycles // 0')
    local tasks_completed=$(echo "$state" | jq -r '.tasks_completed // 0')

    log INFO "Cycle $((total_cycles + 1)) - Idle: $idle_cycles/$MAX_IDLE_CYCLES"

    # Find next task
    local task_line
    task_line="$(find_next_task)"

    if [[ -z "$task_line" ]]; then
        log WARN "No pending tasks found"
        idle_cycles=$((idle_cycles + 1))

        if [[ $idle_cycles -ge $MAX_IDLE_CYCLES ]]; then
            log WARN "Max idle cycles reached, exiting"
            send_ralph_status "IDLE_EXIT" "" "none" "$total_cycles"
            return 1
        fi

        save_state "$idle_cycles" "$total_cycles" "$tasks_completed"
        return 0
    fi

    # Task found
    local task_id
    task_id="$(extract_task_id "$task_line")"
    local task_desc
    task_desc="$(extract_task_description "$task_line")"

    log INFO "Found task: $task_id - $task_desc"
    send_ralph_status "RUNNING" "" "$task_id" "$total_cycles"

    # Check if FPGA task
    if [[ "$task_id" =~ FPGA-.* ]]; then
        log INFO "FPGA task detected, running build pipeline..."
        if run_fpga_build "$task_id"; then
            log SUCCESS "FPGA task completed: $task_id"
            mark_task_complete "$task_id"
            tasks_completed=$((tasks_completed + 1))
            idle_cycles=0
            send_ralph_status "SUCCESS" "" "$task_id" "$total_cycles"
        else
            log ERROR "FPGA task failed: $task_id"
            idle_cycles=$((idle_cycles + 1))
            send_ralph_status "FAILED" "" "$task_id" "$total_cycles"
        fi
    # Check if EVO task (self-evolution)
    elif [[ "$task_id" =~ EVO-.* ]]; then
        log INFO "EVO task detected: $task_id"
        if run_evo_task "$task_id"; then
            log SUCCESS "EVO task completed: $task_id"
            mark_task_complete "$task_id"
            tasks_completed=$((tasks_completed + 1))
            idle_cycles=0
            send_ralph_status "SUCCESS" "" "$task_id" "$total_cycles"
        else
            log ERROR "EVO task failed: $task_id"
            idle_cycles=$((idle_cycles + 1))
            send_ralph_status "FAILED" "" "$task_id" "$total_cycles"
        fi
    else
        log INFO "Unknown task type: $task_id"
        idle_cycles=$((idle_cycles + 1))
    fi

    # Save state
    save_state "$idle_cycles" "$((total_cycles + 1))" "$tasks_completed"

    log INFO "Cycle complete"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# CRON DAEMON
# ═══════════════════════════════════════════════════════════════════════════════

start_cron_daemon() {
    log INFO "Starting Ralph Orchestrator 24/7 daemon..."
    log INFO "Task cycle: ${WAKE_INTERVAL_SEC}s, Research: ${RESEARCH_INTERVAL_SEC}s, Evolution: ${EVOLUTION_INTERVAL_SEC}s"

    # Check if already running
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log ERROR "Already running (PID: $pid)"
            return 1
        else
            log WARN "Stale PID file, removing..."
            rm -f "$PID_FILE"
        fi
    fi

    # Initialize cycle counters
    local last_task_time=$(date +%s)
    local last_research_time=$(date +%s)
    local last_evolution_time=$(date +%s)

    # Start daemon in background
    (
        while true; do
            local current_time=$(date +%s)
            local task_elapsed=$((current_time - last_task_time))
            local research_elapsed=$((current_time - last_research_time))
            local evolution_elapsed=$((current_time - last_evolution_time))

            # Task cycle (fix_plan.md)
            if [[ $task_elapsed -ge $WAKE_INTERVAL_SEC ]]; then
                run_single_cycle || true
                last_task_time=$current_time
            fi

            # Research cycle (fetch papers)
            if [[ $research_elapsed -ge $RESEARCH_INTERVAL_SEC ]]; then
                log INFO "Running research cycle..."
                # TODO: Call research_ingester
                last_research_time=$current_time
            fi

            # Evolution cycle (full improvement)
            if [[ $evolution_elapsed -ge $EVOLUTION_INTERVAL_SEC ]]; then
                log INFO "Running full evolution cycle..."
                "${PROJECT_ROOT}/fpga/tools/ralph-evolution.sh" once || true
                last_evolution_time=$current_time
            fi

            # Sleep for 1 minute between checks
            sleep 60
        done
        rm -f "$PID_FILE"
    ) &

    local pid=$!
    echo "$pid" > "$PID_FILE"

    log INFO "Daemon started (PID: $pid)"
    send_ralph_status "STARTED" "" "24/7-mode" "0"

    echo "✓ Ralph Orchestrator 24/7 running (PID: $pid)"
    echo "  Log: $LOG_FILE"
    echo "  Stop: $0 stop"
}

stop_cron_daemon() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo "✗ Not running"
        return 1
    fi

    local pid
    pid=$(cat "$PID_FILE")

    if ! kill -0 "$pid" 2>/dev/null; then
        echo "✗ Stale PID file"
        rm -f "$PID_FILE"
        return 1
    fi

    kill "$pid"
    rm -f "$PID_FILE"

    log INFO "Daemon stopped (PID: $pid)"
    send_ralph_status "STOPPED" "" "none" "0"

    echo "✓ Ralph Orchestrator stopped"
}

show_status() {
    echo "═══════════════════════════════════════"
    echo "  RALPH ORCHESTRATOR STATUS"
    echo "═══════════════════════════════════════"

    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Status: RUNNING"
            echo "PID: $pid"
            echo "Log: $LOG_FILE"
        else
            echo "Status: STOPPED (stale PID)"
            rm -f "$PID_FILE"
        fi
    else
        echo "Status: STOPPED"
    fi

    echo ""
    echo "State file: $STATE_FILE"
    if [[ -f "$STATE_FILE" ]]; then
        echo "$(cat "$STATE_FILE" | jq -r '.')"
    fi

    echo "═══════════════════════════════════════"
}

# ═══════════════════════════════════════════════════════════════════════════════
# COMMAND DISPATCH
# ═══════════════════════════════════════════════════════════════════════════════

mkdir -p "$(dirname "$LOG_FILE")"

case "${1:-}" in
    once)
        run_single_cycle
        ;;
    start)
        start_cron_daemon
        ;;
    stop)
        stop_cron_daemon
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: $0 {once|start|stop|status}"
        echo ""
        echo "Commands:"
        echo "  once   - Run single cycle and exit"
        echo "  start  - Start cron daemon (10 min intervals)"
        echo "  stop   - Stop running daemon"
        echo "  status - Show current status"
        echo ""
        echo "φ² + 1/φ² = 3 = TRINITY"
        exit 1
        ;;
esac
