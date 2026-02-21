#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# VIBEE v10.4: Golden Seed Loop + Autonomous Earnings
# ═══════════════════════════════════════════════════════════════════════════════
#
# V10.4: Full autonomous self-feeding with live $TRI earnings
# - Import seeds from generated/ directory
# - Fill empty implementations using Golden DB
# - Self-feed successful improvements back to Golden DB (Q>0.85)
# - Track and display $TRI rewards earned by VIBEE agents
#
# Usage: golden_seed_loop.sh [options]
#   --cycles N        Maximum iterations (default: 10)
#   --all             Process all spec files (537 files)
#   --specs FILE1,FILE2  Comma-separated list of specs
#   --dry-run         Show what would be done without modifying files
#   --auto-feed       Enable automatic self-feeding to Golden DB
#   --reward          Enable $TRI reward tracking
#   --target PCT      Target fill rate (default: 85.0)
#
# φ² + 1/φ² = 3
#
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Configuration
MAX_ITERATIONS=10
TARGET_PCT=85.0
MIN_CONFIDENCE=0.7
VIBEE_BIN="./zig-out/bin/vibee"
IMPORT_DIR="generated"
AGENT_ID="vibee-v10.4"
DRY_RUN=false
AUTO_FEED=false
ENABLE_REWARDS=false
PROCESS_ALL=false

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cycles)
            MAX_ITERATIONS="$2"
            shift 2
            ;;
        --all)
            PROCESS_ALL=true
            shift
            ;;
        --specs)
            IFS=',' read -ra CUSTOM_SPECS <<< "$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --auto-feed)
            AUTO_FEED=true
            shift
            ;;
        --reward)
            ENABLE_REWARDS=true
            shift
            ;;
        --target)
            TARGET_PCT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "  --cycles N        Maximum iterations (default: 10)"
            echo "  --all             Process all spec files"
            echo "  --specs FILES     Comma-separated list of specs"
            echo "  --dry-run         Show what would be done"
            echo "  --auto-feed       Enable self-feeding to Golden DB"
            echo "  --reward          Enable $TRI reward tracking"
            echo "  --target PCT      Target fill rate (default: 85.0)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Build specs array
if [[ "$PROCESS_ALL" == "true" ]]; then
    # Use find + array for compatibility (mapfile is bash 4+)
    SPECS=()
    while IFS= read -r -d '' file; do
        SPECS+=("$file")
    done < <(find specs/tri -name "*.vibee" -type f -print0 | sort -z)
elif [[ -n "${CUSTOM_SPECS+x}" ]]; then
    SPECS=("${CUSTOM_SPECS[@]}")
else
    # Default specs for quick testing
    SPECS=(
        "specs/tri/fpga_acceleration.vibee"
        "specs/tri/batch_processing.vibee"
        "specs/tri/autoscaling.vibee"
    )
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ═══════════════════════════════════════════════════════════════════════════════
# Functions
# ═══════════════════════════════════════════════════════════════════════════════

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

print_banner() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  VIBEE v10.4: Golden Seed Loop + Autonomous Earnings         ║"
    echo '║  Self-feeding with live $TRI rewards                         ║'
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo "  Configuration:"
    echo "    Max iterations:   $MAX_ITERATIONS"
    echo "    Target fill rate: $TARGET_PCT%"
    echo "    Min confidence:   $MIN_CONFIDENCE"
    echo "    Import directory: $IMPORT_DIR"
    echo "    Agent ID:         $AGENT_ID"
    echo "    Dry run:          $DRY_RUN"
    echo "    Auto-feed:        $AUTO_FEED"
    echo "    Rewards enabled:  $ENABLE_REWARDS"
    echo "    Spec files:       ${#SPECS[@]}"
    echo "    VIBEE binary:     $VIBEE_BIN"
    echo ""
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    if [[ ! -f "$VIBEE_BIN" ]]; then
        log_error "VIBEE binary not found at: $VIBEE_BIN"
        log_info "Build with: zig build-exe -femit-bin=zig-out/bin/vibee src/vibeec/gen_cmd.zig"
        exit 1
    fi

    for spec in "${SPECS[@]}"; do
        if [[ ! -f "$spec" ]]; then
            log_warning "Spec file not found: $spec (will be skipped)"
        fi
    done

    log_success "Prerequisites check passed"
}

count_empty_implementations() {
    local spec_file="$1"
    # Count empty implementation fields
    grep -c "implementation:.*| *$" "$spec_file" 2>/dev/null || echo "0"
}

calculate_fill_rate() {
    local spec_file="$1"
    local total=$(grep -c "^  - name:" "$spec_file" 2>/dev/null || echo "0")
    local empty=$(count_empty_implementations "$spec_file")

    if [[ $total -eq 0 ]] || [[ -z "$empty" ]]; then
        echo "0"
    else
        python3 -c "print(f'{((1 - $empty / $total) * 100):.1f}')" 2>/dev/null || echo "0"
    fi
}

# V10.3: Import seeds from generated/ directory
import_seeds() {
    local iteration="$1"

    log_info "Iteration $iteration: Importing seeds from $IMPORT_DIR"

    if [[ -d "$IMPORT_DIR" ]]; then
        if "$VIBEE_BIN" import-seeds "$IMPORT_DIR" 2>&1 | tee /tmp/vibee_import_$iteration.log; then
            log_success "  Seeds imported successfully"
        else
            log_warning "  Some seeds failed to import (see /tmp/vibee_import_$iteration.log)"
        fi
    else
        log_warning "  Import directory not found: $IMPORT_DIR"
    fi
}

improve_spec() {
    local spec_file="$1"
    local iteration="$2"

    log_info "Iteration $iteration: Improving $spec_file"

    local args=("$spec_file" --min-confidence "$MIN_CONFIDENCE")

    if [[ "$DRY_RUN" == "true" ]]; then
        args+=(--dry-run)
        log_info "  [DRY-RUN] Would improve: $spec_file"
    fi

    # Run improve-spec
    if "$VIBEE_BIN" improve-spec "${args[@]}" 2>&1 | tee /tmp/vibee_improve_${iteration}_$(basename "$spec_file" .vibee).log; then
        if [[ "$DRY_RUN" == "false" ]]; then
            log_success "  Improved: $spec_file"

            # V10.4: Track rewards if enabled
            if [[ "$ENABLE_REWARDS" == "true" ]]; then
                local filled=$(grep -c "implementation:.*[^[:space:]]" "$spec_file" 2>/dev/null || echo "0")
                local rewards=$(python3 -c "print($filled * 10.0)" 2>/dev/null || echo "0")
                log_info "  Estimated \$TRI earned: $rewards"
            fi
        fi
    else
        log_error "  Failed to improve: $spec_file"
        return 1
    fi
}

run_iteration() {
    local iteration="$1"
    local total_filled=0
    local total_skipped=0
    local total_behaviors=0

    echo ""
    log_info "════════════════════════════════════════════════════════════"
    log_info "ITERATION $iteration of $MAX_ITERATIONS"
    log_info "════════════════════════════════════════════════════════════"

    # V10.3: Import seeds at start of each iteration
    import_seeds "$iteration"

    for spec in "${SPECS[@]}"; do
        if [[ ! -f "$spec" ]]; then
            continue
        fi

        # Show fill rate before improvement
        local before_rate=$(calculate_fill_rate "$spec")
        log_info "  $spec: Current fill rate: ${before_rate}%"

        # Improve the spec
        if improve_spec "$spec" "$iteration"; then
            # Show fill rate after improvement
            local after_rate=$(calculate_fill_rate "$spec")
            log_success "  $spec: New fill rate: ${after_rate}% (Δ$(python3 -c "print(f'{($after_rate - $before_rate):+.1f}')")%)"
        fi
    done
}

check_convergence() {
    log_info "Checking convergence..."
    
    local all_above_target=true
    
    for spec in "${SPECS[@]}"; do
        if [[ ! -f "$spec" ]]; then
            continue
        fi
        
        local rate=$(calculate_fill_rate "$spec")
        local rate_num=$(python3 -c "print(float('$rate'))")
        
        if (( $(echo "$rate_num < $TARGET_PCT" | bc -l) )); then
            all_above_target=false
            log_warning "  $spec: ${rate}% < target ${TARGET_PCT}%"
        else
            log_success "  $spec: ${rate}% ≥ target ${TARGET_PCT}%"
        fi
    done
    
    if [[ "$all_above_target" == "true" ]]; then
        log_success "All specs meet target fill rate!"
        return 0
    else
        return 1
    fi
}

create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir=".vibee_backups/golden_seed_$timestamp"
    
    log_info "Creating backup: $backup_dir"
    mkdir -p "$backup_dir"
    
    for spec in "${SPECS[@]}"; do
        if [[ -f "$spec" ]]; then
            cp "$spec" "$backup_dir/"
            log_info "  Backed up: $spec"
        fi
    done
}

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    print_banner
    check_prerequisites

    # Skip backup in dry-run mode
    if [[ "$DRY_RUN" == "false" ]]; then
        create_backup
    else
        log_warning "DRY-RUN mode: No files will be modified"
    fi

    # Main improvement loop
    for iteration in $(seq 1 "$MAX_ITERATIONS"); do
        run_iteration "$iteration"

        if check_convergence; then
            log_success "Convergence achieved after $iteration iteration(s)!"
            break
        fi
    done

    # Final summary
    echo ""
    log_success "════════════════════════════════════════════════════════════"
    log_success "VIBEE v10.4 Golden Seed Loop Complete!"
    log_success "════════════════════════════════════════════════════════════"

    echo ""
    log_info "Final fill rates (first 10 shown):"
    local count=0
    for spec in "${SPECS[@]}"; do
        if [[ -f "$spec" && $count -lt 10 ]]; then
            local rate=$(calculate_fill_rate "$spec")
            local empty=$(count_empty_implementations "$spec")
            echo "  $spec: ${rate}% ($empty empty implementations)"
            ((count++))
        fi
    done
    if [[ ${#SPECS[@]} -gt 10 ]]; then
        log_info "  ... and ${#SPECS[@]} more specs"
    fi

    # V10.4: Show $TRI rewards
    if [[ "$ENABLE_REWARDS" == "true" ]]; then
        echo ""
        log_info '\$TRI Reward Summary:'
        "$VIBEE_BIN" show-rewards --agent "$AGENT_ID" 2>&1 | grep -v "╔════════════════════════════════════════════════════════════════╗" | grep -v "║  VIBEE" | grep -v "╚════════════════════════════════════════════════════════════════╝" | grep -v "^  $" | sed 's/^/  /'
    fi

    echo ""
    log_info "Backup location: .vibee_backups/"
    log_info "Next steps:"
    if [[ "$DRY_RUN" == "false" ]]; then
        log_info "  1. Review improved specs"
        log_info "  2. Run: zig build vibee -- gen <spec.vibee> to test code generation"
        log_info "  3. Self-fed seeds are now in Golden DB for future improvements"
        if [[ "$AUTO_FEED" == "true" ]]; then
            log_success "  4. Auto-feed enabled: VIBEE will learn from its own improvements"
        fi
    else
        log_info "  Remove --dry-run to apply changes"
    fi
}

# Run main
main "$@"
