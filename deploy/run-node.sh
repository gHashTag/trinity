#!/bin/bash
# Trinity Node — Quick Launch Script
# Usage: ./run-node.sh [start|stop|status|logs|build]
#
# Starts Trinity Node with Prometheus + Grafana monitoring stack.
# phi^2 + 1/phi^2 = 3 | Trinity Identity

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.node.yml"

case "${1:-start}" in
  start)
    echo "Starting Trinity Node..."
    docker compose -f "$COMPOSE_FILE" up -d
    echo ""
    echo "Trinity Node started successfully!"
    echo "  API:        http://localhost:8080/health"
    echo "  Prometheus: http://localhost:9091"
    echo "  Grafana:    http://localhost:3000 (admin/trinity)"
    echo ""
    echo "  Discovery:  udp://localhost:9333"
    echo "  Jobs:       tcp://localhost:9334"
    ;;
  stop)
    echo "Stopping Trinity Node..."
    docker compose -f "$COMPOSE_FILE" down
    echo "Trinity Node stopped."
    ;;
  status)
    docker compose -f "$COMPOSE_FILE" ps
    ;;
  logs)
    docker compose -f "$COMPOSE_FILE" logs -f trinity-node
    ;;
  build)
    echo "Building Trinity Node image..."
    docker compose -f "$COMPOSE_FILE" build
    echo "Build complete."
    ;;
  *)
    echo "Trinity Node — Quick Launch Script"
    echo ""
    echo "Usage: $0 {start|stop|status|logs|build}"
    echo ""
    echo "Commands:"
    echo "  start   Start the node and monitoring stack (default)"
    echo "  stop    Stop all services"
    echo "  status  Show service status"
    echo "  logs    Follow trinity-node logs"
    echo "  build   Build/rebuild the Docker image"
    exit 1
    ;;
esac
