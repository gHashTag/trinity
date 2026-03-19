#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY SWARM — Public Launch Script
# ═══════════════════════════════════════════════════════════════════════════════
# Usage:
#   ./deploy/launch-swarm.sh local    # Start 5-node local Docker cluster
#   ./deploy/launch-swarm.sh fly      # Deploy to Fly.io (5 regions)
#   ./deploy/launch-swarm.sh status   # Check swarm health
#   ./deploy/launch-swarm.sh stop     # Stop all nodes
#
# Prerequisites:
#   - Docker + docker compose (for local)
#   - flyctl CLI + authenticated (for Fly.io)
#
# Sacred Formula: V = n x 3^k x pi^m x phi^p x e^q
# Golden Identity: phi^2 + 1/phi^2 = 3
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[TRINITY]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }

# ═══════════════════════════════════════════════════════════════════════════════
# LOCAL: Docker Compose 5-node cluster
# ═══════════════════════════════════════════════════════════════════════════════
launch_local() {
    log "Starting Trinity Swarm — Local 5-Node Cluster"
    log "Regions: seed, iad, lax, ams, sin"
    echo ""

    cd "$PROJECT_ROOT"

    # Build
    log "Building Docker images..."
    docker compose -f deploy/docker-compose.swarm.yml build

    # Launch
    log "Launching 5 nodes..."
    docker compose -f deploy/docker-compose.swarm.yml up -d

    echo ""
    log "Swarm is starting up..."
    echo ""
    echo -e "${CYAN}Ports:${NC}"
    echo "  Seed node:  TCP 9334  UDP 9333  Metrics 9090  Health 8081"
    echo "  Node 1:     TCP 9335            Metrics 9091  Health 8082"
    echo "  Node 2:     TCP 9336            Metrics 9092  Health 8083"
    echo "  Node 3:     TCP 9337            Metrics 9093  Health 8084"
    echo "  Node 4:     TCP 9338            Metrics 9094  Health 8085"
    echo ""
    echo -e "${CYAN}Commands:${NC}"
    echo "  Logs:    docker compose -f deploy/docker-compose.swarm.yml logs -f"
    echo "  Status:  ./deploy/launch-swarm.sh status"
    echo "  Stop:    ./deploy/launch-swarm.sh stop"
    echo ""
    log "Swarm launched. Waiting 10s for nodes to connect..."
    sleep 10
    check_status_local
}

# ═══════════════════════════════════════════════════════════════════════════════
# FLY.IO: Multi-Region Global Deploy
# ═══════════════════════════════════════════════════════════════════════════════
launch_fly() {
    log "Deploying Trinity Swarm to Fly.io — Global Multi-Region"

    if ! command -v flyctl &> /dev/null && ! command -v fly &> /dev/null; then
        err "flyctl not found. Install: https://fly.io/docs/hands-on/install-flyctl/"
        exit 1
    fi

    FLY_CMD="flyctl"
    command -v flyctl &> /dev/null || FLY_CMD="fly"

    cd "$PROJECT_ROOT"

    # Create app if not exists
    log "Creating Fly.io app 'trinity-swarm'..."
    $FLY_CMD apps create trinity-swarm --org personal 2>/dev/null || warn "App may already exist"

    # Deploy
    log "Deploying from deploy/fly.swarm.toml..."
    $FLY_CMD deploy --config deploy/fly.swarm.toml --remote-only

    # Scale to 5 regions
    log "Scaling to 5 regions: iad, lax, ams, sin, nrt..."
    $FLY_CMD scale count 5 --config deploy/fly.swarm.toml --region iad,lax,ams,sin,nrt

    echo ""
    log "Fly.io swarm deployed!"
    echo ""
    echo -e "${CYAN}Manage:${NC}"
    echo "  Status:   $FLY_CMD status --config deploy/fly.swarm.toml"
    echo "  Logs:     $FLY_CMD logs --config deploy/fly.swarm.toml"
    echo "  Scale:    $FLY_CMD scale count N --config deploy/fly.swarm.toml"
    echo "  Console:  $FLY_CMD ssh console --config deploy/fly.swarm.toml"
    echo "  Dashboard: https://fly.io/apps/trinity-swarm"
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATUS: Check node health
# ═══════════════════════════════════════════════════════════════════════════════
check_status_local() {
    log "Checking local swarm health..."
    echo ""

    for port in 8081 8082 8083 8084 8085; do
        node_name="node-$(( port - 8081 ))"
        if [ "$port" = "8081" ]; then node_name="seed"; fi

        if curl -sf "http://localhost:$port/health/live" > /dev/null 2>&1; then
            echo -e "  ${GREEN}●${NC} $node_name (port $port): ${GREEN}ALIVE${NC}"
        else
            echo -e "  ${RED}○${NC} $node_name (port $port): ${RED}DOWN${NC}"
        fi
    done
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════════
# STOP: Shutdown nodes
# ═══════════════════════════════════════════════════════════════════════════════
stop_local() {
    log "Stopping Trinity Swarm..."
    cd "$PROJECT_ROOT"
    docker compose -f deploy/docker-compose.swarm.yml down
    log "Swarm stopped."
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════
case "${1:-help}" in
    local)
        launch_local
        ;;
    fly)
        launch_fly
        ;;
    status)
        check_status_local
        ;;
    stop)
        stop_local
        ;;
    *)
        echo "Trinity Swarm Launcher"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  local   - Start 5-node local Docker cluster"
        echo "  fly     - Deploy to Fly.io (5 global regions)"
        echo "  status  - Check node health (local)"
        echo "  stop    - Stop local cluster"
        ;;
esac
