# Trinity MCP Server - Helm Chart

Enterprise-grade deployment of Trinity MCP Server on Kubernetes.

## Quick Start

```bash
# Add repository (optional)
helm repo add trinity https://charts.trinity.ai
helm repo update

# Install
helm install trinity-mcp ./helm/trinity-mcp

# Upgrade
helm upgrade trinity-mcp ./helm/trinity-mcp

# Uninstall
helm uninstall trinity-mcp
```

## Configuration

Key parameters in `values.yaml`:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `image.repository` | `trinity/mcp` | Container image |
| `image.tag` | `2.1.0` | Image tag |
| `replicaCount` | `2` | Number of pods |
| `service.type` | `ClusterIP` | Service type |
| `resources.requests.cpu` | `100m` | CPU request |
| `resources.limits.cpu` | `500m` | CPU limit |
| `autoscaling.enabled` | `true` | Enable HPA |
| `config.port` | `8899` | MCP server port |
| `config.cacheSize` | `100` | Cache entries |
| `monitoring.enabled` | `true` | Prometheus metrics |

## Production Tips

```bash
# Use specific image digest
helm install trinity-mcp ./helm/trinity-mcp \
  --set image.digest=sha256:abc123...

# Enable LoadBalancer
helm install trinity-mcp ./helm/trinity-mcp \
  --set service.type=LoadBalancer

# Custom resources
helm install trinity-mcp ./helm/trinity-mcp \
  --set resources.limits.cpu=1000m \
  --set resources.limits.memory=1Gi
```

## φ² + 1/φ² = 3 = TRINITY
