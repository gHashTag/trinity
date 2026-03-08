# DePIN Node Tutorial

**15 минут для запуска DePIN ноды Trinity**

---

## Цель этого туториала

Запустить DePIN (Decentralized Physical Infrastructure Network) ноду.

**Что вы узнаете:**
- Как настроить DePIN ноду
- Как подключиться к сети
- Как заработать вознаграждения
- Как мониторить ноду

---

## Что такое DePIN?

**DePIN** — это децентрализованная сеть inference нод Trinity.

| Компонент | Описание |
|-----------|----------|
| **Node** | Ваш сервер с Trinity |
| **Network** | P2P сеть нод |
| **Rewards** | $TRI токены за inference |
| **Mining** | Доказательство работы |

---

## Step 1: Requirements

| Требование | Минимум |
|------------|---------|
| RAM | 8 GB |
| CPU | 4 cores |
| Disk | 50 GB SSD |
| Network | 100 Mbps |
| Zig | 0.15.x |

---

## Step 2: Initialize Node

```bash
# Build DePIN components
zig build tri

# Initialize node
./zig-out/bin/tri depin init

# Generate node key
./zig-out/bin/tri depin generate-key
```

**Результат:**
```
Node ID: trinity-node-0x1234...
Public Key: 0xabc...
Private Key: stored in ~/.trinity/keys/
```

---

## Step 3: Configure Node

```bash
# Edit config
nano ~/.trinity/depin/config.toml
```

```toml
[node]
name = "my-trinity-node"
region = "europe"

[network]
bootstrap_peers = [
    "trinity-bootstrap.example:8765"
]

[mining]
enabled = true
max_concurrent_jobs = 4

[rewards]
address = "0xYourWalletAddress"
```

---

## Step 4: Start Node

```bash
# Start node
./zig-out/bin/tri depin start

# Or with logging
./zig-out/bin/tri depin start --verbose
```

**Ожидаемый вывод:**
```
[INFO] Starting Trinity DePIN Node...
[INFO] Node ID: trinity-node-0x1234...
[INFO] Connecting to network...
[INFO] Connected to 5 peers
[INFO] Mining enabled: 4 workers
[INFO] Ready for inference jobs
```

---

## Step 5: Monitor Node

```bash
# Check status
./zig-out/bin/tri depin status

# View logs
tail -f ~/.trinity/logs/depin.log

# Check earnings
./zig-out/bin/tri depin rewards
```

---

## Code Example

```zig
const std = @import("std");
const depin = @import("depin");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}) {};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    // Create node
    var node = try depin.Node.init(allocator, .{
        .name = "my-node",
        .max_jobs = 4,
    });
    defer node.deinit();

    // Start
    try node.start();

    // Run forever
    std.time.sleep(std.time.us_per_s * 1_000_000_000);
}
```

---

## Rewards

| Действие | Награда |
|----------|---------|
| Inference job | 10 $TRI per 1K tokens |
| Block validation | 1 $TRI per block |
| Referral | 5% от реферала |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Cannot connect to peers | Check firewall port 8765 |
| Low earnings | Increase max_concurrent_jobs |
| Out of memory | Reduce max_jobs |

---

## What's Next?

| Tutorial | Description |
|----------|-------------|
| [Deployment](deployment.md) | Deploy to Fly.io |
| [BitNet Inference](bitnet-inference.md) | LLM inference |

---

**φ² + 1/φ² = 3 = TRINITY**
