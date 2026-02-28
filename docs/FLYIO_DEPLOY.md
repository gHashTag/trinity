# [CYR:[TRANSLATED]] Trinity on Fly.io

## φ² + 1/φ² = 3 = TRINITY

Инwith[TRANSLATED]]toцandя по [CYR:[TRANSLATED]] Trinity LLM inference on Fly.io with маtowithand[CYR:[TRANSLATED]]and реwithурwithамand (16 CPU cores).

---

## [CYR:[TRANSLATED]]inарand[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]inанandя

1. Аtofor[TRANSLATED]] on [Fly.io](https://fly.io)
2. Уwith[TRANSLATED]]in[CYR:[TRANSLATED]] `flyctl` CLI

---

## [CYR:[TRANSLATED]] 1: Уwith[TRANSLATED]]intoа flyctl

```bash
# Linux/macOS
curl -L https://fly.io/install.sh | sh

# [CYR:[TRANSLATED]]inandть in PATH
export FLYCTL_INSTALL="$HOME/.fly"
export PATH="$FLYCTL_INSTALL/bin:$PATH"

# [CYR:[TRANSLATED]]inерandть уwith[TRANSLATED]]intoу
flyctl version
```

---

## [CYR:[TRANSLATED]] 2: Аin[CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andя

```bash
flyctl auth login
```

Отfor[TRANSLATED]]withя browser for in[CYR:[TRANSLATED]] in аtofor[TRANSLATED]] Fly.io.

---

## [CYR:[TRANSLATED]] 3: [CYR:[TRANSLATED]]andроinанandе [CYR:[TRANSLATED]]and[CYR:[TRANSLATED]]andя

```bash
git clone https://github.com/gHashTag/trinity.git
cd trinity
```

---

## [CYR:[TRANSLATED]] 4: Creation прand[CYR:[TRANSLATED]]andя

```bash
flyctl apps create trinity-inference
```

---

## [CYR:[TRANSLATED]] 5: [CYR:[TRANSLATED]] [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andны

Доwith[TRANSLATED]] [CYR:[TRANSLATED]] in `fly.toml`:

| Size | CPU | RAM | Цеon/чаwith |
|------|-----|-----|----------|
| shared-cpu-1x | 1 shared | 256MB-2GB | ~$0.0035 |
| shared-cpu-2x | 2 shared | 512MB-4GB | ~$0.007 |
| shared-cpu-4x | 4 shared | 1GB-8GB | ~$0.014 |
| shared-cpu-8x | 8 shared | 2GB-16GB | ~$0.028 |
| performance-1x | 1 dedicated | 2GB-8GB | ~$0.057 |
| performance-2x | 2 dedicated | 4GB-16GB | ~$0.114 |
| performance-4x | 4 dedicated | 8GB-32GB | ~$0.228 |
| performance-8x | 8 dedicated | 16GB-64GB | ~$0.456 |
| **performance-16x** | **16 dedicated** | **32GB-128GB** | ~$0.912 |

Теfor[TRANSLATED]] for[TRANSLATED]]and[CYR:[TRANSLATED]]andя in `fly.toml`:

```toml
[[vm]]
  size = "performance-16x"
  memory = "32gb"
  cpus = 16
```

[CYR:[TRANSLATED]] and[CYR:[TRANSLATED]]notнandя [CYR:[TRANSLATED]] from[CYR:[TRANSLATED]]toтand[CYR:[TRANSLATED]] `fly.toml`.

---

## [CYR:[TRANSLATED]] 6: [CYR:[TRANSLATED]]

```bash
flyctl deploy
```

[CYR:[TRANSLATED]]:
1. [CYR:[TRANSLATED]] Docker [CYR:[TRANSLATED]]
2. [CYR:[TRANSLATED]]andт on Fly.io
3. [CYR:[TRANSLATED]]withтandт [CYR:[TRANSLATED]]andну with 16 CPU cores

---

## [CYR:[TRANSLATED]] 7: Check with[TRANSLATED]]withа

```bash
# [CYR:[TRANSLATED]]with прand[CYR:[TRANSLATED]]andя
flyctl status

# [CYR:[TRANSLATED]]and
flyctl logs

# SSH in [CYR:[TRANSLATED]]andну
flyctl ssh console
```

---

## [CYR:[TRANSLATED]] 8: [CYR:[TRANSLATED]]withto benchmark

Поwithле [CYR:[TRANSLATED]], [CYR:[TRANSLATED]]for[TRANSLATED]]andтеwithь to [CYR:[TRANSLATED]]andnot and [CYR:[TRANSLATED]]withтandте:

```bash
flyctl ssh console

# [CYR:[TRANSLATED]]and [CYR:[TRANSLATED]]andны
cd /app
./tri_inference /app/models/smollm2-360m.tri
```

---

## Ожand[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]andзinодand[CYR:[TRANSLATED]]withть

| [CYR:[TRANSLATED]]andon | Cores | Сfor[TRANSLATED]]withть | Speedup |
|--------|-------|----------|---------|
| Gitpod (теfor[TRANSLATED]]) | 2 | ~8 tok/s | 1x |
| performance-4x | 4 | ~15 tok/s | 2x |
| performance-8x | 8 | ~28 tok/s | 3.5x |
| **performance-16x** | **16** | **~50 tok/s** | **6x** |

---

## Оwith[TRANSLATED]]intoа [CYR:[TRANSLATED]]andны (эfor[TRANSLATED]]andя деnotг)

```bash
# Оwith[TRANSLATED]]inandть [CYR:[TRANSLATED]]andну
flyctl machine stop

# [CYR:[TRANSLATED]]andть прand[CYR:[TRANSLATED]]andе
flyctl apps destroy trinity-inference
```

---

## [CYR:[TRANSLATED]]onтandin[CYR:[TRANSLATED]] [CYR:[TRANSLATED]]withto ([CYR:[TRANSLATED]]inая [CYR:[TRANSLATED]]andon)

[CYR:[TRANSLATED]] быwith[TRANSLATED]] теwithта [CYR:[TRANSLATED]] поwith[TRANSLATED]] [CYR:[TRANSLATED]]:

```bash
flyctl machine run \
  --app trinity-inference \
  --vm-size performance-16x \
  --vm-memory 32768 \
  --entrypoint "/app/tri_inference /app/models/smollm2-360m.tri" \
  registry.fly.io/trinity-inference:latest
```

---

## Troubleshooting

### Error "No access token"
```bash
flyctl auth login
```

### Error "App not found"
```bash
flyctl apps create trinity-inference
```

### Error "Out of memory"
[CYR:[TRANSLATED]]andте [CYR:[TRANSLATED]] [CYR:[TRANSLATED]]and or уinелand[CYR:[TRANSLATED]] RAM in `fly.toml`.

### [CYR:[TRANSLATED]]onя with[TRANSLATED]]toа
Иwith[TRANSLATED]] remote builder:
```bash
flyctl deploy --remote-only
```

---

## [CYR:[TRANSLATED]] for[TRANSLATED]]and[CYR:[TRANSLATED]]and

- `fly.toml` - for[TRANSLATED]]and[CYR:[TRANSLATED]]andя Fly.io
- `Dockerfile.flyio` - Docker [CYR:[TRANSLATED]] for [CYR:[TRANSLATED]]
- `benchmark_flyio.sh` - withtoрandпт [CYR:[TRANSLATED]]toand [CYR:[TRANSLATED]]andзinодand[CYR:[TRANSLATED]]withтand

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN IS CLOSED | φ² + 1/φ² = 3**
