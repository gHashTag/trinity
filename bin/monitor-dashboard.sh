#!/bin/bash
# Trinity Dashboard Monitoring Script
# Checks health of deployed dashboard and logs results

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/.ralph/logs"
LOG_FILE="$LOG_DIR/dashboard-monitor.log"
ALERT_FILE="$LOG_DIR/dashboard-alerts.log"

# URLs to monitor
MAIN_URL="https://gHashTag.github.io/trinity/"
STATUS_URL="https://gHashTag.github.io/trinity/status.html"
DOCS_URL="https://gHashTag.github.io/trinity/docs/"

# Thresholds
TIMEOUT=10
EXPECTED_HTTP="200"
MAX_RESPONSE_TIME=5  # seconds

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging functions
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" | tee -a "$ALERT_FILE"
}

# Check function
check_url() {
    local url=$1
    local name=$2

    # Measure response time
    START=$(date +%s.%N)
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$url" 2>&1)
    END=$(date +%s.%N)
    RESPONSE_TIME=$(echo "$END - $START" | bc)

    if [ "$HTTP_CODE" = "$EXPECTED_HTTP" ]; then
        # Check response time
        if (( $(echo "$RESPONSE_TIME > $MAX_RESPONSE_TIME" | bc -l) )); then
            log_warning "$name: Slow response (${RESPONSE_TIME}s > ${MAX_RESPONSE_TIME}s)"
            return 1
        else
            log_info "$name: OK (HTTP $HTTP_CODE, ${RESPONSE_TIME}s)"
            return 0
        fi
    else
        log_error "$name: FAILED (HTTP $HTTP_CODE, expected $EXPECTED_HTTP)"
        return 2
    fi
}

# Check consecutive failures
CONSECUTIVE_FAILURES=0
MAX_FAILURES=3

# Load previous failure count if exists
FAILURE_COUNT_FILE="$LOG_DIR/.consecutive_failures"
if [ -f "$FAILURE_COUNT_FILE" ]; then
    CONSECUTIVE_FAILURES=$(cat "$FAILURE_COUNT_FILE")
fi

# Run checks
log_info "=== Starting monitoring cycle ==="

FAILED=0
check_url "$MAIN_URL" "Main Site" || FAILED=$((FAILED + 1))
check_url "$STATUS_URL" "Status Page" || FAILED=$((FAILED + 1))
check_url "$DOCS_URL" "Documentation" || FAILED=$((FAILED + 1))

# Update consecutive failures
if [ $FAILED -gt 0 ]; then
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    echo "$CONSECUTIVE_FAILURES" > "$FAILURE_COUNT_FILE"

    if [ $CONSECUTIVE_FAILURES -ge $MAX_FAILURES ]; then
        log_error "ALERT: $CONSECUTIVE_FAILURES consecutive monitoring failures detected!"
        # TODO: Send webhook notification here if configured
    fi
else
    CONSECUTIVE_FAILURES=0
    echo "0" > "$FAILURE_COUNT_FILE"
fi

log_info "=== Monitoring cycle complete (failures: $FAILED/$CONSECUTIVE_FAILURES) ==="
echo ""

exit $FAILED
