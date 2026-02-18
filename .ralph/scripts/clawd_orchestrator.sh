#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
# CLAWD ORCHESTRATOR — Autonomous development pipeline manager
# ═══════════════════════════════════════════════════════════════════
# Wakes every 15 minutes to:
#   1. Check if workers finished their tasks
#   2. Merge completed branches into main
#   3. Restart idle/crashed workers
#   4. Escalate: Phase 1 → Phase 2 → Phase 3 (TRI SOTA)
#   5. Report to Telegram
# ═══════════════════════════════════════════════════════════════════

set -o pipefail

ORCHESTRATOR_INTERVAL=900  # 15 minutes
RALPH_LOOP="/Users/playra/.ralph/ralph_loop.sh"
OPENCLAW_BIN="node /Users/playra/openclaw/openclaw.mjs"
CHAT_ID="144022504"
MAIN_DIR="/Users/playra/trinity"
MAIN_BRANCH="ralph/math-framework"
LOG_FILE="$MAIN_DIR/.ralph/logs/orchestrator.log"
PHASE_FILE="$MAIN_DIR/.ralph/logs/.current_phase"

# Workers (bash 3 compatible)
WORKER_NAMES=(W1 W2 W3)
WORKER_DIRS=("/Users/playra/trinity-w1" "/Users/playra/trinity-w2" "/Users/playra/trinity-w3")
WORKER_BRANCHES=("ralph/nexus-src" "ralph/nexus-specs" "ralph/nexus-docs")
WORKER_TASKS=("NEXUS-011,012,013,014" "NEXUS-015,016,017,018" "NEXUS-019,020,021")

# Phase 2 tasks
PHASE2_TASK_IDS=("NEXUS-022" "NEXUS-023" "NEXUS-024")
PHASE2_TASK_DESCS=("Update import paths" "Update README" "Verify all tests")

# Phase 3: TRI SOTA — improvement + monetization
# Drawn from TECH_TREE available nodes + TRI_SOTA_ROADMAP priorities
PHASE3_TASK_IDS=(
    "SOTA-001"
    "SOTA-002"
    "SOTA-003"
    "SOTA-004"
    "SOTA-005"
    "SOTA-006"
    "SOTA-007"
    "SOTA-008"
    "SOTA-009"
)
PHASE3_TASK_DESCS=(
    "Ternary weight quantization OPT-T01: convert model weights to tryte format, benchmark 20x compression"
    "Ternary matmul OPT-T02: implement multiply-free matrix ops using ternary weights, benchmark 10x speedup"
    "LLM inference pipeline: GGUF loader + transformer forward pass in Zig (INF-001 + INF-002)"
    "VSA reasoning layer for LLM: wire symb/ VSA as post-processing for math/logic tasks (LLM-004)"
    "Arena evaluation harness: benchmark suite against Arena-like prompts (LLM-005)"
    "One-line install script DX-001: curl install for trinity-nexus with auto Zig setup"
    "VS Code extension DX-002: .vibee syntax highlighting + inline codegen"
    "Ternary KV cache OPT-T03: 16x KV cache compression using tryte encoding"
    "Speculative decoding OPT-S01: 2-3x generation speed via draft model"
)
PHASE3_TASK_PROMPTS=(
    "Implement ternary weight quantization. Convert float32 weights to tryte format (-1, 0, +1). Target: 20x compression with <2% accuracy loss. Files: trinity-nexus/core/src/ternary_quant.zig. Benchmark vs float32."
    "Implement ternary matrix multiplication without multiply operations. Use additions and subtractions only based on tryte values. Target: 10x speedup vs float matmul. Files: trinity-nexus/core/src/ternary_matmul.zig. SIMD acceleration."
    "Build LLM inference pipeline: 1) GGUF model file parser 2) Transformer forward pass (attention + FFN) 3) Token sampling. All in Zig. Files: trinity-nexus/llm/src/. Load and run Llama-style models."
    "Wire VSA symbolic reasoning as a post-processing layer for LLM output. When LLM generates math/logic, route through symb/ VSA for verification. Files: trinity-nexus/llm/src/vsa_layer.zig. Benchmark accuracy improvement."
    "Create Arena evaluation harness. Load MT-Bench and Arena-hard prompts. Score responses. Track Elo estimate. Files: trinity-nexus/llm/src/arena.zig, trinity-nexus/llm/tests/."
    "Create one-line install script. curl | bash that detects OS, installs Zig 0.15.x, clones trinity-nexus, runs build, verifies. Files: scripts/install.sh. Test on macOS + Linux."
    "Create VS Code extension for .vibee files. Syntax highlighting via TextMate grammar. IntelliSense for VIBEE keywords. Inline codegen preview. Files: tools/vscode-vibee/. Publish to marketplace."
    "Implement ternary KV cache compression. Quantize attention KV pairs to tryte format. 16x memory reduction. Files: trinity-nexus/core/src/ternary_kv_cache.zig. Benchmark vs float KV."
    "Implement speculative decoding. Small draft model generates candidates, large model verifies. 2-3x speedup. Files: trinity-nexus/llm/src/speculative.zig."
)

# Track which Phase 3 batch we're on (3 tasks per batch)
PHASE3_BATCH_FILE="$MAIN_DIR/.ralph/logs/.phase3_batch"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

send_telegram() {
    local msg="$1"
    $OPENCLAW_BIN message send \
        --channel telegram \
        --target "$CHAT_ID" \
        --message "$msg" \
        --silent 2>/dev/null || log "⚠️ Telegram send failed"
}

get_current_phase() {
    if [ -f "$PHASE_FILE" ]; then
        cat "$PHASE_FILE"
    else
        echo "1"
    fi
}

set_current_phase() {
    echo "$1" > "$PHASE_FILE"
}

# Check if worker's fix_plan has all tasks marked done
worker_tasks_complete() {
    local dir="$1"
    local plan="$dir/.ralph/internal/fix_plan.md"
    if [ ! -f "$plan" ]; then
        return 1
    fi
    local unchecked=$(grep -c "^\- \[ \]" "$plan" 2>/dev/null || echo "0")
    local checked=$(grep -c "^\- \[x\]" "$plan" 2>/dev/null || echo "0")
    if [ "$unchecked" -eq 0 ] && [ "$checked" -gt 0 ]; then
        return 0
    fi
    return 1
}

# Check if worker is idle (no log activity for 35+ min)
worker_is_idle() {
    local dir="$1"
    local ralph_log="$dir/.ralph/logs/ralph.log"
    if [ ! -f "$ralph_log" ]; then
        return 0
    fi
    local last_mod=$(stat -f %m "$ralph_log" 2>/dev/null || echo 0)
    local now=$(date +%s)
    local age=$(( now - last_mod ))
    [ "$age" -gt 2100 ]
}

# Check if worker branch has commits ahead of main
worker_has_commits() {
    local dir="$1"
    local branch="$2"
    local count=$(git -C "$dir" rev-list "$MAIN_BRANCH..$branch" --count 2>/dev/null || echo "0")
    [ "$count" -gt 0 ]
}

# Merge worker branch into main
merge_worker() {
    local idx="$1"
    local name="${WORKER_NAMES[$idx]}"
    local branch="${WORKER_BRANCHES[$idx]}"
    local tasks="${WORKER_TASKS[$idx]}"

    log "🔀 Merging $name ($branch) into $MAIN_BRANCH..."

    cd "$MAIN_DIR"
    git merge "$branch" --no-edit -m "merge($name): Merge $branch — $tasks complete" 2>&1 | tee -a "$LOG_FILE"

    if [ $? -eq 0 ]; then
        log "✅ $name merged successfully"
        send_telegram "🔀 **Merge complete:** \`$branch\` → \`$MAIN_BRANCH\`
Tasks: $tasks
$(git -C "$MAIN_DIR" log --oneline -3)"
        return 0
    else
        log "❌ $name merge CONFLICT — needs manual resolution"
        send_telegram "❌ **Merge conflict:** \`$branch\` → \`$MAIN_BRANCH\`
Worker: $name | Tasks: $tasks
⚠️ Needs manual resolution"
        git merge --abort 2>/dev/null
        return 1
    fi
}

# Restart a worker
restart_worker() {
    local idx="$1"
    local name="${WORKER_NAMES[$idx]}"
    local dir="${WORKER_DIRS[$idx]}"

    log "🔄 Restarting $name in $dir"
    cd "$dir"
    CLAUDECODE= nohup "$RALPH_LOOP" --live --calls 100 --timeout 30 >> "$dir/.ralph/logs/ralph_restart.log" 2>&1 &
    log "   $name started PID $!"
    cd "$MAIN_DIR"
}

# Generic task assignment (works for Phase 2 and 3)
assign_task() {
    local idx="$1"
    local task_id="$2"
    local task_desc="$3"
    local task_prompt="$4"
    local phase="$5"
    local name="${WORKER_NAMES[$idx]}"
    local dir="${WORKER_DIRS[$idx]}"
    local branch="${WORKER_BRANCHES[$idx]}"

    log "📋 Assigning $task_id ($task_desc) to $name [Phase $phase]"

    # Update worker tasks tracker
    WORKER_TASKS[$idx]="$task_id"

    cat > "$dir/.ralph/internal/fix_plan.md" <<EOF
# $name — Phase $phase: $task_id

## Tasks
- [ ] [P1] $task_id: $task_desc

## Branch
$branch

## Golden Rule
Test everything. Build must pass. Focus on TRI SOTA quality.
EOF

    cat > "$dir/.ralph/PROMPT.md" <<EOF
# Ralph $name — Phase $phase: $task_id

## Context
You are Ralph $name working on Trinity — a ternary computing framework in Zig.
Project root: trinity-nexus/ with modules: core/, lang/, symb/, network/, canvas/, tools/
You are on branch \`$branch\`.

## Your Task: $task_id — $task_desc

$task_prompt

## Commit Convention
Commit with: \`feat(tri-sota): $task_id $task_desc\`

## Quality
- All tests must pass
- No regressions in existing code
- Benchmark results in commit message

## Status Reporting
Include RALPH_STATUS block at end of every response.
EOF

    restart_worker "$idx"

    send_telegram "📋 **Phase $phase task assigned**
Worker: $name
Task: **$task_id** — $task_desc
Branch: \`$branch\`"
}

# Assign Phase 2 task
assign_phase2_task() {
    local idx="$1"
    local task_idx="$2"
    assign_task "$idx" "${PHASE2_TASK_IDS[$task_idx]}" "${PHASE2_TASK_DESCS[$task_idx]}" \
        "Follow the acceptance criteria in the main fix_plan.md." "2"
}

# Assign Phase 3 task batch
assign_phase3_batch() {
    local batch=$(cat "$PHASE3_BATCH_FILE" 2>/dev/null || echo "0")
    local start=$((batch * 3))
    local total=${#PHASE3_TASK_IDS[@]}

    if [ "$start" -ge "$total" ]; then
        log "🏆 ALL PHASE 3 TASKS EXHAUSTED — TRI SOTA complete!"
        send_telegram "🏆 **ALL PHASES COMPLETE!**
Phase 1: NEXUS migration ✅
Phase 2: Cleanup + verification ✅
Phase 3: TRI SOTA improvements ✅

Trinity is ready for Arena submission.
_Time to dominate._"
        set_current_phase "done"
        return
    fi

    log "🚀 Assigning Phase 3 batch $batch (tasks $start-$((start+2)))"
    send_telegram "🚀 **PHASE 3 BATCH $batch — TRI SOTA**
Assigning next 3 tasks for project improvement + monetization"

    for i in 0 1 2; do
        local task_idx=$((start + i))
        if [ "$task_idx" -lt "$total" ]; then
            assign_task "$i" "${PHASE3_TASK_IDS[$task_idx]}" \
                "${PHASE3_TASK_DESCS[$task_idx]}" \
                "${PHASE3_TASK_PROMPTS[$task_idx]}" "3"
        fi
    done

    echo "$((batch + 1))" > "$PHASE3_BATCH_FILE"
    set_current_phase "3"
}

# ═══ Main orchestration cycle ═══
orchestrate() {
    log "═══ Orchestration cycle started ═══"

    local phase=$(get_current_phase)
    log "   Current phase: $phase"

    if [ "$phase" = "done" ]; then
        log "   All phases complete. Monitoring only."
        return
    fi

    local completed=0
    local active=0
    local idle=0
    local completed_idxs=""
    local idle_idxs=""

    for i in 0 1 2; do
        local name="${WORKER_NAMES[$i]}"
        local dir="${WORKER_DIRS[$i]}"

        if worker_tasks_complete "$dir"; then
            completed=$((completed + 1))
            completed_idxs="$completed_idxs $i"
            log "🏁 $name: ALL TASKS COMPLETE"
        elif worker_is_idle "$dir"; then
            idle=$((idle + 1))
            idle_idxs="$idle_idxs $i"
            log "💤 $name: IDLE (crashed?)"
        else
            active=$((active + 1))
            log "⚙️  $name: ACTIVE"
        fi
    done

    # Merge completed workers
    for idx in $completed_idxs; do
        if worker_has_commits "${WORKER_DIRS[$idx]}" "${WORKER_BRANCHES[$idx]}"; then
            merge_worker "$idx"
        else
            log "ℹ️  ${WORKER_NAMES[$idx]} complete but no new commits"
        fi
    done

    # Restart idle workers
    for idx in $idle_idxs; do
        restart_worker "$idx"
    done

    # Phase transitions: all 3 workers done → next phase
    if [ "$completed" -eq 3 ] && [ "$active" -eq 0 ]; then
        if [ "$phase" = "1" ]; then
            log "🎉 ALL PHASE 1 COMPLETE — Starting Phase 2!"
            send_telegram "🎉 **PHASE 1 COMPLETE!**
All NEXUS-011 → NEXUS-021 migrated and archived.
Starting Phase 2: imports, docs, tests."
            for i in 0 1 2; do
                assign_phase2_task "$i" "$i"
            done
            set_current_phase "2"

        elif [ "$phase" = "2" ]; then
            log "🎉 ALL PHASE 2 COMPLETE — Starting Phase 3: TRI SOTA!"
            send_telegram "🎉 **PHASE 2 COMPLETE!**
NEXUS migration fully verified.
Starting **Phase 3: TRI SOTA** — performance, LLM inference, monetization.
_Focus: ternary quantization, Arena pipeline, developer tools._"
            assign_phase3_batch

        elif [ "$phase" = "3" ]; then
            log "🎉 Phase 3 batch complete — assigning next batch"
            assign_phase3_batch
        fi
    fi

    log "═══ Orchestration [Phase $phase]: $active active, $completed complete, $idle idle ═══"
}

# ═══ MAIN ═══
log "🎯 Clawd Orchestrator started"
log "   Workers: ${WORKER_NAMES[*]}"
log "   Interval: ${ORCHESTRATOR_INTERVAL}s (15 min)"
log "   Phases: 1 (migration) → 2 (cleanup) → 3 (TRI SOTA)"

send_telegram "🎯 **Clawd Orchestrator launched**
Managing ${#WORKER_NAMES[@]} parallel workers
Phase 1: NEXUS-011 → NEXUS-021 (migration)
Phase 2: NEXUS-022 → NEXUS-024 (cleanup)
Phase 3: SOTA-001 → SOTA-009 (TRI SOTA)
Cycle: every 15 min
_Autonomous pipeline — no tasks wasted_"

# Initial orchestration
orchestrate

while true; do
    sleep "$ORCHESTRATOR_INTERVAL"
    orchestrate
done
