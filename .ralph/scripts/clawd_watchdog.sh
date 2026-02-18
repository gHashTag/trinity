#!/bin/bash
# Clawd Watchdog — monitors ALL Ralph loops (main + 3 worktree workers) every 10 minutes
# Restarts if crashed, sends Telegram status with all workers
# Run: nohup bash .ralph/scripts/clawd_watchdog.sh &

CHECK_INTERVAL=3600  # 1 hour
RALPH_LOOP="/Users/playra/.ralph/ralph_loop.sh"
OPENCLAW_BIN="node /Users/playra/openclaw/openclaw.mjs"
CHAT_ID="144022504"

# Worker definitions: name|dir|branch
WORKERS=(
    "Main|/Users/playra/trinity|ralph/math-framework"
    "W1-src|/Users/playra/trinity-w1|ralph/nexus-src"
    "W2-docs|/Users/playra/trinity-w2|ralph/nexus-specs"
    "W3-infra|/Users/playra/trinity-w3|ralph/nexus-docs"
)

WATCHDOG_LOG="/Users/playra/trinity/.ralph/logs/watchdog.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$WATCHDOG_LOG"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check if a ralph loop is running for a specific project dir
is_worker_running() {
    local dir="$1"
    # Check if any ralph_loop.sh has cwd in this dir, or check ralph.log freshness
    if [ -f "$dir/.ralph/logs/ralph.log" ]; then
        local last_mod=$(stat -f %m "$dir/.ralph/logs/ralph.log" 2>/dev/null || echo 0)
        local now=$(date +%s)
        local age=$(( now - last_mod ))
        # If log was written in last 35 minutes, it's running
        if [ "$age" -lt 2100 ]; then
            return 0
        fi
    fi
    return 1
}

# Get worker status: loop count, last action
get_worker_status() {
    local dir="$1"
    local status_file="$dir/.ralph/logs/status.json"
    if [ -f "$status_file" ]; then
        local loop=$(python3 -c "import json; d=json.load(open('$status_file')); print(d.get('loop_count',0))" 2>/dev/null || echo "?")
        local status=$(python3 -c "import json; d=json.load(open('$status_file')); print(d.get('status','?'))" 2>/dev/null || echo "?")
        local calls=$(python3 -c "import json; d=json.load(open('$status_file')); print(d.get('calls_made_this_hour',0))" 2>/dev/null || echo "?")
        echo "Loop $loop | $status | Calls $calls"
    else
        echo "no status"
    fi
}

# Get last commit on a branch in a dir
get_last_commit() {
    local dir="$1"
    git -C "$dir" log --oneline -1 2>/dev/null || echo "no commits"
}

# Get last live.log activity
get_live_activity() {
    local dir="$1"
    tail -5 "$dir/.ralph/logs/live.log" 2>/dev/null | grep -v "^$" | grep -v "^===" | tail -1 | head -c 100
}

# Restart a specific worker
restart_worker() {
    local name="$1"
    local dir="$2"
    log "🔄 Restarting $name in $dir"

    # Reset circuit breaker
    local cb_file="$dir/.ralph/internal/.circuit_breaker_state"
    if [ -f "$cb_file" ]; then
        python3 -c "
import json
try:
    with open('$cb_file') as f: d=json.load(f)
    d['state']='CLOSED'; d['consecutive_no_progress']=0
    with open('$cb_file','w') as f: json.dump(d,f,indent=4)
except: pass
" 2>/dev/null
    fi

    cd "$dir"
    CLAUDECODE= nohup "$RALPH_LOOP" --live --calls 100 --timeout 30 >> "$dir/.ralph/logs/ralph_restart.log" 2>&1 &
    log "   $name started PID $!"
    cd /Users/playra/clawd
}

# Build and send multi-worker Telegram status
send_telegram_status() {
    local msg="🤖 **Clawd Parallel Status**
$(TZ=Asia/Bangkok date '+%A %b %d, %I:%M %p %Z')
"
    local all_healthy=true

    for worker_def in "${WORKERS[@]}"; do
        IFS='|' read -r name dir branch <<< "$worker_def"

        if is_worker_running "$dir"; then
            local status=$(get_worker_status "$dir")
            local commit=$(get_last_commit "$dir")
            local live=$(get_live_activity "$dir")
            msg+="
🟢 **$name** (\`$branch\`)
   $status
   Last: \`$commit\`"
            if [ -n "$live" ]; then
                msg+="
   ⚡ $live"
            fi
        else
            all_healthy=false
            msg+="
🔴 **$name** (\`$branch\`) — STOPPED"
        fi
    done

    # Tech tree from main
    local tech=$(grep "Total" /Users/playra/trinity/.ralph/TECH_TREE.md 2>/dev/null | grep -v "Branch" | head -1 | sed 's/[*]//g' | awk -F'|' '{printf "%s/%s (%s)", $3, $4, $5}' | tr -s ' ')
    if [ -n "$tech" ]; then
        msg+="

📊 **Tech Tree:** $tech"
    fi

    msg+="
---
_Clawd Watchdog — hourly report_"

    # Send
    $OPENCLAW_BIN message send \
        --channel telegram \
        --target "$CHAT_ID" \
        --message "$msg" \
        --silent 2>/dev/null && {
        log "📨 Telegram status sent (${#WORKERS[@]} workers)"
    } || {
        log "⚠️ Telegram send failed"
    }
}

# Main watchdog loop
log "🐕 Clawd Watchdog v3 started — ${#WORKERS[@]} workers, hourly reports"
for worker_def in "${WORKERS[@]}"; do
    IFS='|' read -r name dir branch <<< "$worker_def"
    log "   $name: $dir ($branch)"
done

# Initial status
send_telegram_status

while true; do
    for worker_def in "${WORKERS[@]}"; do
        IFS='|' read -r name dir branch <<< "$worker_def"

        if is_worker_running "$dir"; then
            log "✅ $name healthy"
        else
            log "💀 $name NOT running — restarting"
            restart_worker "$name" "$dir"
            sleep 3
        fi
    done

    send_telegram_status
    sleep "$CHECK_INTERVAL"
done
