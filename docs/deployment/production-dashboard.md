# Production Dashboard Deployment Guide

**φ² + 1/φ² = 3 | TRINITY v1.0.1 "PURITY"**

This guide covers deploying the Trinity Production Dashboard to a real domain.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Production Dashboard                     │
├─────────────────────────────────────────────────────────────┤
│  Frontend (React)  │  Backend (Node.js)  │  WebSocket (WS) │
│  - Real-time VSA   │  - API Gateway      │  - Live Updates  │
│  - Metrics         │  - Auth             │  - Notifications │
│  - Trinity Canvas  │  - Data Pipeline    │  - Agent Stream  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              Trinity Core (Zig)                             │
│  - VSA Operations  -  JIT Compiler  -  TVC Learning         │
└─────────────────────────────────────────────────────────────┘
```

---

## Deployment Options

### Option 1: Vercel (Recommended for Frontend)

**Frontend (React/Trinity Canvas)**:

```bash
cd website
npm install
npm run build

# Deploy to Vercel
vercel --prod
```

**Environment Variables**:
```bash
VITE_API_URL=https://api.trinity.sh
VITE_WS_URL=wss://ws.trinity.sh
VITE_TRINITY_VERSION=1.0.1
```

---

### Option 2: Docker (Full Stack)

**docker-compose.yml**:

```yaml
version: '3.8'

services:
  trinity-frontend:
    image: ghcr.io/ghashtag/trinity-frontend:1.0.1
    ports:
      - "3000:3000"
    environment:
      - VITE_API_URL=http://trinity-backend:8080
      - VITE_WS_URL=ws://trinity-backend:8081
    depends_on:
      - trinity-backend

  trinity-backend:
    image: ghcr.io/ghashtag/trinity-backend:1.0.1
    ports:
      - "8080:8080"
      - "8081:8081"
    environment:
      - TRINITY_CORE_PATH=/usr/local/bin/tri
      - DATABASE_URL=postgresql://user:pass@db:5432/trinity
    volumes:
      - trinity-data:/var/lib/trinity
    depends_on:
      - db

  db:
    image: postgres:16-alpine
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=trinity
      - POSTGRES_USER=trinity
      - POSTGRES_PASSWORD=change_me_in_production

volumes:
  trinity-data:
  postgres-data:
```

**Deploy**:

```bash
docker-compose up -d
```

---

### Option 3: Kubernetes (Enterprise)

**k8s/deployment.yaml**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: trinity-dashboard
  labels:
    app: trinity
    version: "1.0.1"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: trinity
  template:
    metadata:
      labels:
        app: trinity
    spec:
      containers:
      - name: frontend
        image: ghcr.io/ghashtag/trinity-frontend:1.0.1
        ports:
        - containerPort: 3000
        env:
        - name: VITE_API_URL
          value: "https://api.trinity.sh"

---
apiVersion: v1
kind: Service
metadata:
  name: trinity-service
spec:
  selector:
    app: trinity
  ports:
  - port: 443
    targetPort: 3000
  type: LoadBalancer
```

**Deploy**:

```bash
kubectl apply -f k8s/
```

---

## Domain Configuration

### DNS Records

```
A    trinity.sh       → 1.2.3.4 (load balancer IP)
A    api.trinity.sh   → 1.2.3.4
A    ws.trinity.sh    → 1.2.3.4
CNAME www            → trinity.sh
```

### SSL/TLS (Let's Encrypt)

```bash
# Using certbot
certbot certonly --standalone -d trinity.sh -d api.trinity.sh
```

---

## Monitoring & Observability

### Prometheus Metrics

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'trinity'
    static_configs:
      - targets: ['localhost:9090']
    metrics_path: '/metrics'
```

### Grafana Dashboard

Import dashboard: `docs/dashboards/trinity-grafana.json`

**Metrics to Track**:
- VSA operation latency (p50, p95, p99)
- JIT cache hit rate
- Memory usage (working set)
- Active agents count
- TVC corpus size

---

## Eternal Monitor Activation

**24/7 Health Monitoring**:

```bash
# Create monitoring service
cat > /etc/systemd/system/trinity-monitor.service << EOF
[Unit]
Description=Trinity Eternal Monitor
After=network.target

[Service]
Type=simple
User=trinity
WorkingDirectory=/opt/trinity
ExecStart=/usr/local/bin/tri eternal-monitor --alert-webhook=https://hooks.example.com/trinity
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable service
systemctl enable trinity-monitor
systemctl start trinity-monitor
```

---

## Public Status Dashboard

**Status Page**: `status.trinity.sh`

```yaml
# status.yml
services:
  - name: API
    url: https://api.trinity.sh/health
  - name: WebSocket
    url: wss://ws.trinity.sh
  - name: VSA Operations
    url: https://api.trinity.sh/vsa/health
  - name: TVC Learning
    url: https://api.trinity.sh/tvc/health

incident_history:
  - title: "v1.0.1 Release"
    date: 2026-02-28
    status: "Resolved"
```

---

## Security Checklist

- [ ] SSL/TLS enabled (HTTPS only)
- [ ] API rate limiting configured
- [ ] CORS policy restricted
- [ ] Input validation enabled
- [ ] Secrets in environment variables (not committed)
- [ ] Database backups automated
- [ ] DDoS protection (Cloudflare or similar)
- [ ] Audit logging enabled
- [ ] Intrusion detection (fail2ban)
- [ ] Regular security updates

---

## Backup & Recovery

### Database Backup

```bash
# Daily backup cron job
0 2 * * * pg_dump -U trinity trinity | gzip > /backups/trinity-$(date +\%Y\%m\%d).sql.gz
```

### TVC Corpus Backup

```bash
# Backup distributed learning corpus
tar czf /backups/tvc-corpus-$(date +%Y%m%d).tar.gz /var/lib/trinity/tvc/
```

---

## Rollback Procedure

If something goes wrong:

```bash
# 1. Identify broken version
kubectl get deployments trinity-dashboard -o yaml

# 2. Rollback to previous version
kubectl rollout undo deployment/trinity-dashboard

# 3. Verify health
curl https://api.trinity.sh/health

# 4. If still broken, revert to last known good commit
git revert <commit-hash>
kubectl apply -f k8s/
```

---

## Support

- **Documentation**: https://ghashtag.github.io/trinity/docs
- **Issues**: https://github.com/gHashTag/trinity/issues
- **Discord**: https://discord.gg/trinity-vsa

---

**φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL**
