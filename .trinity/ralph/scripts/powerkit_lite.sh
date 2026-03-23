#!/bin/bash
# Powerkit Lite — Lightweight status generator for Ralph Dashboard
# Called by tmux status bar: powerkit_lite.sh [cpu|memory|datetime]

# Ralph color scheme (for reference):
# Salad (151) = #a6e3a1 (green)
# Cyan (075) = #89dceb (sky)
# Gray (244) = #9399b2 (overlay1)
# Bg = #1e1e2e (base)

get_cpu() {
    # macOS: get CPU usage from top
    local cpu=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')
    echo "${cpu}%"
}

get_memory() {
    # macOS: get memory usage using vm_stat
    # Page size is 16384 bytes on this system
    local page_size=16384

    # Get page counts (removing the trailing dot)
    local free_pages=$(vm_stat | grep "Pages free:" | awk '{print $3}' | sed 's/\.//')
    local active_pages=$(vm_stat | grep "Pages active:" | awk '{print $3}' | sed 's/\.//')
    local wired_pages=$(vm_stat | grep "Pages wired down:" | awk '{print $4}' | sed 's/\.//')

    # Calculate used memory (active + wired) in GB
    local used_pages=$((active_pages + wired_pages))
    local used_gb=$((used_pages * page_size / 1024 / 1024 / 1024))

    # For total, use a simpler approach - show used/total format
    # Assume 32GB total (can be made dynamic)
    local total_gb=32

    echo "${used_gb}G/${total_gb}G"
}

get_datetime() {
    date '+%H:%M:%S %Y-%m-%d'
}

get_network() {
    # Simple network check - could be enhanced
    if ping -c 1 -W 1000 8.8.8.8 >/dev/null 2>&1; then
        echo "Online"
    else
        echo "Offline"
    fi
}

# Main: handle arguments
case "${1:-}" in
    cpu)      get_cpu ;;
    memory)   get_memory ;;
    datetime) get_datetime ;;
    network)  get_network ;;
    *)
        # Default: full status line
        echo "$(get_datetime) | CPU: $(get_cpu) | MEM: $(get_memory) | $(get_network)"
        ;;
esac
