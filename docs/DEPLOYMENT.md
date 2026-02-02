# Trinity Deployment Guide

**Version**: 1.0.0  
**Status**: Production Ready  
**Formula**: φ² + 1/φ² = 3

---

## Quick Start

### Local Development

```bash
# Build inference server
cd src/vibeec
zig build-exe tri_inference.zig -O ReleaseFast -o trinity-inference

# Run with model
./trinity-inference /path/to/model.gguf
```

### Docker

```bash
# Build image
docker build -f deploy/Dockerfile.inference -t trinity-inference .

# Run container
docker run -p 8080:8080 -p 9090:9090 -v /models:/app/models trinity-inference
```

### Fly.io Deployment

```bash
# Install flyctl
curl -L https://fly.io/install.sh | sh

# Login
fly auth login

# Deploy
cd deploy
fly launch --config fly.toml

# Scale
fly scale count 3 --region iad
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    TRINITY INFERENCE CLUSTER                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │  Instance 1 │    │  Instance 2 │    │  Instance N │         │
│  │  :8080      │    │  :8080      │    │  :8080      │         │
│  │  :9090      │    │  :9090      │    │  :9090      │         │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘         │
│         │                  │                  │                 │
│         └──────────────────┼──────────────────┘                 │
│                            │                                    │
│                    ┌───────┴───────┐                            │
│                    │  Load Balancer │                           │
│                    │  (Fly.io)      │                           │
│                    └───────┬───────┘                            │
│                            │                                    │
│                    ┌───────┴───────┐                            │
│                    │  Prometheus   │                            │
│                    │  :9090        │                            │
│                    └───────────────┘                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NUM_THREADS` | 16 | CPU threads for inference |
| `MAX_BATCH_SIZE` | 32 | Maximum batch size |
| `MAX_SEQUENCE_LENGTH` | 4096 | Maximum sequence length |
| `METRICS_PORT` | 9090 | Prometheus metrics port |
| `HEALTH_PORT` | 8081 | Health check port |
| `MODEL_PATH` | /app/models/model.gguf | Path to model file |

### Scaling Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `TARGET_CPU_PERCENT` | 70 | Target CPU utilization |
| `TARGET_QUEUE_DEPTH` | 50 | Target queue depth |
| `TARGET_TTFT_MS` | 100 | Target TTFT in ms |
| `MIN_INSTANCES` | 1 | Minimum instances |
| `MAX_INSTANCES` | 10 | Maximum instances |
| `COOLDOWN_SECONDS` | 60 | Scaling cooldown |

---

## Endpoints

### Inference

```
POST /v1/completions
Content-Type: application/json

{
  "prompt": "Hello, how are you?",
  "max_tokens": 100,
  "temperature": 0.7
}
```

### Health Checks

| Endpoint | Description | Success |
|----------|-------------|---------|
| `GET /health/live` | Liveness probe | 200 OK |
| `GET /health/ready` | Readiness probe | 200 OK |
| `GET /health/startup` | Startup probe | 200 OK |

### Monitoring

| Endpoint | Description |
|----------|-------------|
| `GET /metrics` | Prometheus metrics |
| `GET /status` | JSON status |
| `GET /dashboard` | Dashboard JSON |

---

## Prometheus Metrics

```prometheus
# Counters
trinity_total_requests
trinity_total_tokens
trinity_total_errors

# Gauges
trinity_cpu_usage_percent
trinity_memory_usage_percent
trinity_queue_depth
trinity_active_requests
trinity_instance_count
trinity_healthy_instances

# Latency
trinity_ttft_seconds{quantile="0.5"}
trinity_ttft_seconds{quantile="0.99"}

# Throughput
trinity_throughput_tokens_per_second
```

---

## Auto-Scaling

Trinity auto-scales based on:

1. **CPU Utilization**: Scale up when CPU > 80%, down when < 30%
2. **Queue Depth**: Scale up when queue > 50 requests
3. **TTFT Latency**: Scale up when TTFT > 100ms

### Scaling Algorithm

```
IF cpu > target * 0.8 OR queue > target_queue OR ttft > target_ttft:
    scale_up(min(current + 1, max_instances))
    
IF cpu < target * 0.3 AND queue < 10 AND instances > min_instances:
    scale_down(max(current - 1, min_instances))
```

---

## Load Testing

```bash
# Run load test
cd src/vibeec
zig build-exe load_test.zig -O ReleaseFast
./load_test

# Expected output:
# Total Requests:     100
# Successful:         100
# Throughput:         22.58 req/s
# Tokens/sec:         2258.24
```

---

## Monitoring Setup

### Prometheus

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'trinity'
    static_configs:
      - targets: ['trinity-inference.fly.dev:9090']
```

### Grafana Dashboard

Import dashboard from `deploy/grafana/trinity-dashboard.json`

Key panels:
- Request rate
- Token throughput
- TTFT latency (p50, p99)
- CPU/Memory utilization
- Instance count
- Error rate

---

## Troubleshooting

### Common Issues

**Model not loading**
```bash
# Check model path
ls -la /app/models/

# Check memory
free -h
```

**High latency**
```bash
# Check CPU
top -p $(pgrep trinity)

# Check queue depth
curl http://localhost:9090/metrics | grep queue
```

**Scaling not working**
```bash
# Check Fly.io API token
fly secrets list

# Check scaling config
fly config show
```

---

## Production Checklist

- [ ] Model file accessible at MODEL_PATH
- [ ] Health checks passing
- [ ] Prometheus scraping metrics
- [ ] Grafana dashboard configured
- [ ] Fly.io secrets set (FLY_API_TOKEN)
- [ ] Auto-scaling tested
- [ ] Load test passed (100+ requests)
- [ ] Alerts configured

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3**
