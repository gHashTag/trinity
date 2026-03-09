# Deployment Tutorial

**20 минут для деплоя Trinity на Fly.io**

---

## Цель этого туториала

Развернуть Trinity на облачном сервере Fly.io.

**Что вы узнаете:**
- Как создать Fly.io приложение
- Как настроить environment variables
- Как деплоить через CI/CD
- Как мониторить deployed app

---

## Почему Fly.io?

| Преимущество | Описание |
|--------------|----------|
| **Free tier** | 3 VMs с 256MB RAM бесплатно |
| **Simple deploy** | `fly deploy` |
| **Auto HTTPS** | SSL сертификаты автоматически |
| **Global CDN** | Весь мир |

---

## Step 1: Install Fly CLI

```bash
# Install flyctl
curl -L https://fly.io/install.sh | sh

# Login
flyctl auth login
```

---

## Step 2: Create App

```bash
# Create new app
flyctl apps create trinity-api

# Or with specific region
flyctl apps create trinity-api --region lon
```

**Результат:**
```
New app created: trinity-api
  URL: https://trinity-api.fly.dev
```

---

## Step 3: Create fly.toml

```bash
# Create fly.toml in project root
cat > fly.toml << 'EOF'
app = "trinity-api"
primary_region = "lon"

[build]
  build-target = "tri"

[env]
  PORT = "8080"
  TRI_ENV = "production"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 0
  max_machines_running = 5

[[vm]]
  size = "shared-cpu-2x"
  memory = "2048mb"

[checks]
  [checks.alive]
    type = "tcp"
    interval = "15s"
    timeout = "2s"
    grace_period = "5s"
EOF
```

---

## Step 4: Set Environment Variables

```bash
# Set secrets
flyctl secrets set TRI_API_KEY --app trinity-api
flyctl secrets set DATABASE_URL --app trinity-api
```

---

## Step 5: Deploy

```bash
# First deployment
flyctl deploy

# Check status
flyctl status

# View logs
flyctl logs
```

**Ожидаемый вывод:**
```
Deploying trinity-api...
  Waiting for deployment...
  Deployment succeeded!
  https://trinity-api.fly.dev
```

---

## Step 6: Test Deployment

```bash
# Health check
curl https://trinity-api.fly.dev/api/health

# Run command
curl -X POST https://trinity-api.fly.dev/api/execute \
  -H "Content-Type: application/json" \
  -d '{"command":"constants"}'
```

---

## CI/CD with GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy to Fly.io

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: superfly/flyctl-actions@master
        with:
          args: "deploy --app trinity-api"
```

---

## Monitoring

```bash
# Dashboard
flyctl dashboard

# Metrics
flyctl metrics

# Status
flyctl status --all
```

---

## Scaling

```bash
# Scale up
flyctl scale count 5

# Scale memory
flyctl scale memory 4096

# Set to shared-cpu-4x
flyctl scale vm shared-cpu-4x
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Build fails | Check Zig version in build args |
| Out of memory | Increase VM memory |
| High latency | Use region closer to users |

---

## What's Next?

| Tutorial | Description |
|----------|-------------|
| [DePIN Node](depin-node.md) | Run DePIN node |
| [BitNet Inference](bitnet-inference.md) | LLM inference |

---

**φ² + 1/φ² = 3 = TRINITY**
