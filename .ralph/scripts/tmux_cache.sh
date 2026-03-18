#!/bin/bash
# tmux_cache.sh - Caching layer for Ralph Dashboard tmux panels
# Reduces redundant file I/O by caching parsed data with TTL

# Cache configuration
CACHE_DIR="/tmp/ralph-tmux-cache"
CACHE_TTL=5  # 5 second TTL matches tmux refresh interval

# Ensure cache directory exists
mkdir -p "$CACHE_DIR" 2>/dev/null

# Get current timestamp
cache_now() {
    date +%s
}

# Get value from cache
# Usage: cached=$(cache_get "key" "default_value")
# Returns: cached value if valid, otherwise default_value
cache_get() {
    local key="$1"
    local default="${2:-}"
    local cache_file="$CACHE_DIR/$key"
    local now=$(cache_now)

    if [ -f "$cache_file" ]; then
        local cached=$(cache_now)  # Get modification time
        if [ $((now - cached)) -lt $CACHE_TTL ]; then
            # Cache is still valid
            cat "$cache_file" 2>/dev/null
            return 0
        fi
    fi

    # Cache miss or expired
    echo "$default"
    return 1
}

# Set value in cache
# Usage: cache_set "key" "value"
cache_set() {
    local key="$1"
    local value="$2"
    local cache_file="$CACHE_DIR/$key"

    echo "$value" > "$cache_file"
}

# Check if cache exists for key
# Usage: if cache_exists "key"; then ...
cache_exists() {
    local key="$1"
    local cache_file="$CACHE_DIR/$key"

    [ -f "$cache_file" ]
}

# Invalidate specific cache entry
# Usage: cache_invalidate "key"
cache_invalidate() {
    local key="$1"
    local cache_file="$CACHE_DIR/$key"

    rm -f "$cache_file" 2>/dev/null
}

# Clear all cache
# Usage: cache_clear
cache_clear() {
    rm -rf "$CACHE_DIR" 2>/dev/null
    mkdir -p "$CACHE_DIR" 2>/dev/null
}

# Get cache statistics
# Usage: cache_stats
cache_stats() {
    local count=$(ls "$CACHE_DIR" 2>/dev/null | wc -l | xargs || echo "0")
    local size=$(du -sh "$CACHE_DIR" 2>/dev/null | cut -f1 || echo "0B")

    echo "entries: $count"
    echo "size: $size"
}

# Cached fix_plan parsing
# Returns: P1, P2, P3 counts in format "p1:p2:p3"
cache_get_fix_plan_counts() {
    local cached
    if cached=$(cache_get "fix_plan_counts" "0:0:0"); then
        echo "$cached"
        return 0
    fi

    # Parse and cache
    local fix_plan=""
    if [ -f ".ralph/internal/fix_plan.md" ]; then
        fix_plan=".ralph/internal/fix_plan.md"
    elif [ -f ".ralph/fix_plan.md" ]; then
        fix_plan=".ralph/fix_plan.md"
    fi

    if [ -n "$fix_plan" ] && [ -f "$fix_plan" ]; then
        local p1=$(grep -c "^\- \[ \] \[P1\]" "$fix_plan" 2>/dev/null || echo "0")
        local p2=$(grep -c "^\- \[ \] \[P2\]" "$fix_plan" 2>/dev/null || echo "0")
        local p3=$(grep -c "^\- \[ \] \[P3\]" "$fix_plan" 2>/dev/null || echo "0")
        local result="${p1}:${p2}:${p3}"
        cache_set "fix_plan_counts" "$result"
        echo "$result"
    else
        echo "0:0:0"
    fi
}

# Cached git status
# Returns: "branch_name:changed_files_count"
cache_get_git_status() {
    local cached
    if cached=$(cache_get "git_status" "no-git:0"); then
        echo "$cached"
        return 0
    fi

    # Get and cache
    local branch=$(git branch --show-current 2>/dev/null || echo "no-git")
    local changes=$(git status --short 2>/dev/null | wc -l | xargs || echo "0")
    local result="${branch}:${changes}"
    cache_set "git_status" "$result"
    echo "$result"
}

# Cached fix_plan path resolution
# Returns: path to fix_plan.md or empty string
cache_get_fix_plan_path() {
    local cached
    if cached=$(cache_get "fix_plan_path" ""); then
        echo "$cached"
        return 0
    fi

    # Find and cache
    local fix_plan=""
    if [ -f ".ralph/internal/fix_plan.md" ]; then
        fix_plan=".ralph/internal/fix_plan.md"
    elif [ -f ".ralph/fix_plan.md" ]; then
        fix_plan=".ralph/fix_plan.md"
    fi
    cache_set "fix_plan_path" "$fix_plan"
    echo "$fix_plan"
}

# Cached task completion counts
# Returns: "done:total"
cache_get_task_completion() {
    local cached
    if cached=$(cache_get "task_completion" "0:0"); then
        echo "$cached"
        return 0
    fi

    local fix_plan=""
    fix_plan=$(cache_get_fix_plan_path)

    if [ -n "$fix_plan" ] && [ -f "$fix_plan" ]; then
        local total=$(grep -c "^- \[ \]" "$fix_plan" 2>/dev/null || echo "0")
        local done=$(grep -c "^- \[x\]" "$fix_plan" 2>/dev/null || echo "0")
        local result="${done}:${total}"
        cache_set "task_completion" "$result"
        echo "$result"
    else
        echo "0:0"
    fi
}

# Cached tmux-golden-chain binary path
# Returns: path to binary or empty string
cache_get_tmux_golden_chain_binary() {
    local cached
    if cached=$(cache_get "tmux_golden_chain_bin" ""); then
        echo "$cached"
        return 0
    fi

    # Check primary location first
    local tmux_bin="./zig-out/bin/tmux-golden-chain"
    if [ -f "$tmux_bin" ]; then
        cache_set "tmux_golden_chain_bin" "$tmux_bin"
        echo "$tmux_bin"
        return 0
    fi

    # Check cached location (no find scan - too slow!)
    # Only use pre-known cache paths
    local cache_paths=(
        ".zig-cache/h/*/p/zig-out-bin/zig-out/bin/tmux-golden-chain"
        ".zig-cache/b/*/p/zig-out-bin/zig-out/bin/tmux-golden-chain"
    )

    for path in "${cache_paths[@]}"; do
        # Expand wildcards manually (fast)
        for expanded in $path 2>/dev/null; do
            if [ -f "$expanded" ]; then
                cache_set "tmux_golden_chain_bin" "$expanded"
                echo "$expanded"
                return 0
            fi
        done
    done

    echo ""
}
