<p align="center">
  <img src="https://img.shields.io/badge/Trinity-Network-6366F1?style=for-the-badge" alt="Trinity Network">
</p>

<h1 align="center">Trinity Network</h1>

<p align="center">
  <strong>Decentralized AI Inference</strong><br>
  Run LLMs on your CPU. Earn $TRI tokens. No GPU required.
</p>

<p align="center">
  <a href="#-why-trinity">Why Trinity</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-libraries">Libraries</a> •
  <a href="#-tokenomics">Tokenomics</a> •
  <a href="#-roadmap">Roadmap</a> •
  <a href="docs/business/BUSINESS_MODEL.md">Business Model</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Languages-29-blue" alt="29 Languages">
  <img src="https://img.shields.io/badge/Token-$TRI-green" alt="$TRI Token">
  <img src="https://img.shields.io/badge/License-MIT-yellow" alt="MIT License">
  <img src="https://img.shields.io/badge/CPU-Inference-orange" alt="CPU Inference">
</p>

---

## 🚀 Why Trinity?

**The Problem:** AI inference requires expensive GPUs. NVIDIA controls 90%+ of the market. Cloud GPU costs $2-4/hour.

**Our Solution:** Ternary weights {-1, 0, +1} eliminate multiplications, enabling **CPU-only inference**.

```
┌─────────────────────────────────────────────────────────────────┐
│                    TRINITY ADVANTAGE                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Traditional LLM          Trinity Network                      │
│   ───────────────          ───────────────                      │
│   32 bits/weight    →      1.58 bits/weight                     │
│   70B = 280 GB RAM  →      70B = 14 GB RAM                      │
│   Requires GPU      →      ANY CPU works                        │
│   Float multiply    →      Just add/subtract                    │
│                                                                 │
│   Weights W ∈ {-1, 0, +1}:                                      │
│   • Multiply by -1 → negate (free)                              │
│   • Multiply by  0 → skip (free)                                │
│   • Multiply by +1 → nothing (free)                             │
│                                                                 │
│   Result: 20x memory savings, 10x faster on CPU                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## ⚡ Quick Start

### For Node Operators (Earn $TRI)

Run LLM inference on your CPU and earn $TRI tokens for every request processed.

#### 1. Check Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **CPU** | 4 cores, 2.0 GHz | 8+ cores, AVX2 support |
| **RAM** | 8 GB | 16+ GB |
| **Storage** | 10 GB SSD | 50+ GB SSD |
| **Network** | 10 Mbps | 100+ Mbps |
| **OS** | Windows 10, macOS 12, Ubuntu 20.04 | Latest versions |

#### 2. Download Trinity Node

<table>
<tr>
<td align="center"><b>Windows</b></td>
<td align="center"><b>macOS</b></td>
<td align="center"><b>Linux</b></td>
</tr>
<tr>
<td align="center">
<a href="https://github.com/gHashTag/trinity/releases/latest">
<img src="https://img.shields.io/badge/Download-Windows-0078D6?style=for-the-badge&logo=windows" alt="Windows">
</a>
</td>
<td align="center">
<a href="https://github.com/gHashTag/trinity/releases/latest">
<img src="https://img.shields.io/badge/Download-macOS-000000?style=for-the-badge&logo=apple" alt="macOS">
</a>
</td>
<td align="center">
<a href="https://github.com/gHashTag/trinity/releases/latest">
<img src="https://img.shields.io/badge/Download-Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Linux">
</a>
</td>
</tr>
<tr>
<td align="center"><code>TrinityNode-x.x.x.exe</code></td>
<td align="center"><code>TrinityNode-x.x.x.dmg</code></td>
<td align="center"><code>TrinityNode-x.x.x.AppImage</code></td>
</tr>
</table>

**CLI Installation (Linux/macOS):**
```bash
curl -sSL https://trinity.network/install.sh | bash
```

#### 3. Install & Configure

**Desktop App:**
1. Run the installer for your OS
2. Launch Trinity Node from Applications/Start Menu
3. Create or import a wallet (your $TRI receiving address)
4. Set resource limits (CPU %, RAM, active hours)

**CLI:**
```bash
# Initialize with your wallet address
trinity-node init --wallet <YOUR_WALLET_ADDRESS>

# Or create a new wallet
trinity-node init --create-wallet
```

#### 4. Start the Node

**Desktop App:** Click the **Start** button on the dashboard.

**CLI:**
```bash
trinity-node start
```

The node will:
- Connect to Trinity Network
- Download the BitNet-7B model (~2.1 GB, first run only)
- Begin accepting inference jobs

#### 5. Verify Connectivity

**Desktop App:** Check the status indicator shows 🟢 **ONLINE**

**CLI:**
```bash
trinity-node status
```

Expected output:
```
Trinity Node v1.0.0
Status:     ONLINE
Node ID:    trinity_abc123...
Uptime:     2h 15m
Model:      BitNet-7B (loaded)
Jobs:       142 completed
Earnings:   12.45 $TRI (today)
```

#### 6. Start Earning $TRI

Once online, your node automatically:
- Receives inference jobs from the network
- Processes requests using your CPU
- Earns $TRI proportional to tokens processed

**Reward Rate:** ~0.9 $TRI per 1M tokens processed (90% to node operators)

**Bonus Multipliers:**
- Uptime >99%: +10%
- Low latency: +5%
- High throughput: +5%

**Check Earnings:**
```bash
trinity-node earnings

# Output:
# Today:     12.45 $TRI
# This Week: 87.32 $TRI
# Total:     1,234.56 $TRI
# Pending:   45.00 $TRI (settles in ~24h)
```

**Withdraw:**
```bash
trinity-node withdraw --to <EXTERNAL_WALLET> --amount 100
```

---

#### How Earning Works

```
┌─────────────────────────────────────────────────────────────────┐
│                    $TRI EARNING FLOW                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. API User pays $TRI for inference                           │
│           │                                                     │
│           ▼                                                     │
│  2. Scheduler assigns job to your node                          │
│           │                                                     │
│           ▼                                                     │
│  3. Your CPU processes the request                              │
│           │                                                     │
│           ▼                                                     │
│  4. Result verified, contribution recorded                      │
│           │                                                     │
│           ▼                                                     │
│  5. $TRI credited to your wallet                               │
│                                                                 │
│  Fee Split:                                                     │
│  ├── 90% → Node Operator (you)                                 │
│  ├── 8%  → Protocol Treasury                                   │
│  └── 2%  → Burned (deflationary)                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

#### Staking for Priority (Optional)

Stake $TRI to receive more jobs and higher rewards:

| Tier | Stake | Job Priority | Staking APY |
|------|-------|--------------|-------------|
| Bronze | 10,000 $TRI | Standard | 8% |
| Silver | 100,000 $TRI | +20% | 12% |
| Gold | 1,000,000 $TRI | +50% | 16% |
| Platinum | 10,000,000 $TRI | +100% | 20% |

---

#### Troubleshooting

| Issue | Solution |
|-------|----------|
| Node won't connect | Check firewall, enable UPnP, or forward port 9000 |
| Low earnings | Increase CPU limit, ensure stable connection |
| Model download fails | Check disk space (need 10+ GB free) |
| High CPU usage | Reduce CPU limit in Settings |

**Need help?** Join [Discord](https://discord.gg/trinity) or open an [issue](https://github.com/gHashTag/trinity/issues).

---

#### Advanced: Run as Service

**Linux (systemd):**
```bash
sudo trinity-node service install
sudo systemctl enable trinity-node
sudo systemctl start trinity-node
```

**macOS (launchd):**
```bash
trinity-node service install
# Auto-starts on login
```

**Windows (Service):**
```powershell
trinity-node service install
# Runs as Windows Service
```

**Docker:**
```bash
docker run -d \
  --name trinity-node \
  --restart unless-stopped \
  -v trinity-data:/data \
  -e WALLET_ADDRESS=<YOUR_ADDRESS> \
  trinitynetwork/node:latest
```

[📄 Full Node Documentation →](docs/business/TRINITY_NODE_SPEC.md)

---

### For Developers (Use API)

```bash
# OpenAI-compatible API
curl https://api.trinity.network/v1/chat/completions \
  -H "Authorization: Bearer $TRI_API_KEY" \
  -d '{"model": "bitnet-70b", "messages": [{"role": "user", "content": "Hello"}]}'
```

### For Library Users

```bash
# Python
pip install trinity-vsa

# Rust
cargo add trinity-vsa

# npm
npm install trinity-vsa
```

---

## 📦 Libraries

**29 programming languages** with unified API:

| Category | Languages |
|----------|-----------|
| **Systems** | C, Rust, Zig, Nim, D, Ada, Fortran |
| **JVM** | Java, Kotlin, Scala, Clojure |
| **Functional** | Haskell, OCaml, F#, Elixir, Erlang |
| **Scientific** | Python, Julia, R, MATLAB, Mathematica |
| **Web/Mobile** | TypeScript, Go, Swift, Dart, PHP, Ruby |
| **Scripting** | Lua, Perl |

### Core API

```python
from trinity_vsa import TritVector, bind, similarity

# Create concept vectors
apple = TritVector.random(10000)
red = TritVector.random(10000)

# Bind: create association
red_apple = bind(apple, red)

# Query: measure similarity
print(similarity(red_apple, apple))  # ~0.0 (orthogonal after bind)
```

[📚 Full Library Documentation →](libs/README.md)

---

## 💰 Tokenomics

### $TRI Token

| Metric | Value |
|--------|-------|
| **Total Supply** | 10,460,353,203 (3²¹ Phoenix Number) |
| **Token** | $TRI |
| **Network** | Ethereum + Trinity L2 |
| **Launch Price** | $0.0287 |
| **FDV** | $300,000,000 |

> **Sacred Mathematics:** 3²¹ = φ² + 1/φ² = 3 = TRINITY

### Seed Round

```
┌─────────────────────────────────────────────────────────────────┐
│  SEED ROUND: $3,000,000 for 1% equity                           │
│  VALUATION:  $300,000,000                                       │
│  FOUNDER:    99% ownership post-seed                            │
│  FUTURE:     Pricing TBD based on network growth                │
└─────────────────────────────────────────────────────────────────┘
```

### Distribution

```
Node Rewards     ████████████████████  40%  4.18B $TRI
Founder          ████████              20%  2.09B $TRI
Treasury (DAO)   ██████                15%  1.57B $TRI
Public Sale      ██████                15%  1.57B $TRI
Ecosystem        ████                  10%  1.05B $TRI
─────────────────────────────────────────────────────
TOTAL: 3²¹ = 10,460,353,203 $TRI (Phoenix Number)
```

### Utility

- 💳 **Pay** for inference API calls
- 💰 **Earn** for compute contribution (90% of fees to nodes)
- 🗳️ **Vote** on governance proposals
- 📈 **Stake** for priority access (8-20% APY)

[📄 Full Tokenomics →](docs/business/TOKENOMICS.md)

---

## 🗺️ Roadmap

```
Q1 2025  ✅ Trinity VSA libraries (29 languages)
         ✅ C library with AVX2 SIMD
         □  Trinity Node alpha

Q2 2025  □  $TRI token launch
         □  Mainnet beta
         □  BitNet 7B model

Q3 2025  □  BitNet 70B model
         □  Mobile apps
         □  10,000 nodes

Q4 2025  □  DAO governance
         □  Enterprise partnerships
         □  100,000 nodes
```

---

## 📁 Project Structure

```
trinity/
├── libs/           # 29-language VSA libraries
├── src/            # Core source code
│   ├── vibeec/     # VIBEE compiler
│   └── phi-engine/ # Quantum-inspired engine
├── specs/          # .vibee specifications
├── docs/           # Documentation
│   └── business/   # Business model, tokenomics
├── fpga-network/   # FPGA acceleration
└── examples/       # Usage examples
```

---

## 🔗 Links

| Resource | Link |
|----------|------|
| **GitHub** | [github.com/gHashTag/trinity](https://github.com/gHashTag/trinity) |
| **Documentation** | [docs/](docs/) |
| **Business Model** | [docs/business/BUSINESS_MODEL.md](docs/business/BUSINESS_MODEL.md) |
| **Tokenomics** | [docs/business/TOKENOMICS.md](docs/business/TOKENOMICS.md) |
| **Brand Guidelines** | [docs/business/BRANDING.md](docs/business/BRANDING.md) |

---

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

```bash
# Clone
git clone https://github.com/gHashTag/trinity.git

# Build
cd trinity && zig build

# Test
zig test src/vsa.zig
```

---

## 📜 License

MIT License - see [LICENSE](LICENSE)

---

<p align="center">
  <strong>Trinity Network</strong><br>
  <em>Decentralized AI Inference</em><br><br>
  <code>Trinity = 3 = Ternary = {-1, 0, +1}</code><br>
  <code>φ² + 1/φ² = 3</code>
</p>
