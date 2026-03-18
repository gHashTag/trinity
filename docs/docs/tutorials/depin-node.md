# DePIN Node Tutorial

**15 minutes to launch a Trinity DePIN node**

---

## Goal of This Tutorial

Launch a DePIN (Decentralized Physical Infrastructure Network) node.

**What you'll learn:**
- How to set up a DePIN node
- How to connect to the network
- How to earn rewards
- How to monitor the node

---

## What is DePIN?

**DePIN** is a decentralized network of Trinity inference nodes.

| Component | Description |
|-----------|-------------|
| **Node** | Your server running Trinity |
| **Network** | P2P network of nodes |
| **Rewards** | $TRI tokens for inference |
| **Mining** | Proof of work |

---

## Step 1: Requirements

| Requirement | Minimum |
|-------------|---------|
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

**Result:**
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

**Expected output:**
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

| Action | Reward |
|--------|--------|
| Inference job | 10 $TRI per 1K tokens |
| Block validation | 1 $TRI per block |
| Referral | 5% of referral earnings |

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
