# $TRI Token - Tokenomics Specification

## Overview

**$TRI** is the native utility token of **Trinity Network**, used to pay for inference, reward compute providers, and govern the protocol.

> *TRI = Trinity = 3 = Ternary {-1, 0, +1}*

---

## Token Details

```
┌─────────────────────────────────────────────────────────────────┐
│                    TOKEN SPECIFICATIONS                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Name:           Trinity Token                                  │
│  Symbol:         $TRI                                           │
│  Total Supply:   10,000,000,000 (10 billion)                    │
│  Decimals:       18                                             │
│  Type:           ERC-20 (Ethereum) + Native (Trinity L2)        │
│  Initial Price:  $0.03 (target)                                 │
│  FDV at Launch:  $300,000,000                                   │
│                                                                 │
│  FUNDRAISING:                                                   │
│  ─────────────────────────────────────────────────────────────  │
│  Seed Round:     $3,000,000 for 1% equity                       │
│  Valuation:      $300,000,000                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Token Distribution

```
┌─────────────────────────────────────────────────────────────────┐
│                    TOKEN ALLOCATION                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                                                        │    │
│  │   Node Rewards     ████████████████████  40%  4.0B    │    │
│  │   Team & Advisors  ████████            20%  2.0B    │    │
│  │   Treasury (DAO)   ██████              15%  1.5B    │    │
│  │   Public Sale      ██████              15%  1.5B    │    │
│  │   Ecosystem        ████                10%  1.0B    │    │
│  │                                                        │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  DETAILED BREAKDOWN:                                            │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  1. NODE REWARDS (40% = 4,000,000,000 $TRI)                    │
│     • Purpose: Incentivize compute providers                    │
│     • Vesting: Linear over 10 years                             │
│     • Year 1: 800M (20%)                                        │
│     • Year 2: 600M (15%)                                        │
│     • Year 3-10: 325M/year (halving schedule)                   │
│                                                                 │
│  2. TEAM & ADVISORS (20% = 2,000,000,000 $TRI)                 │
│     • Team: 1.5B (15%)                                          │
│     • Advisors: 500M (5%)                                       │
│     • Vesting: 4 years, 1-year cliff                            │
│     • Monthly unlock after cliff                                │
│                                                                 │
│  3. TREASURY (15% = 1,500,000,000 $TRI)                        │
│     • Controlled by DAO governance                              │
│     • Uses: Grants, partnerships, emergencies                   │
│     • Unlock: 10% at launch, rest via governance                │
│                                                                 │
│  4. PUBLIC SALE (15% = 1,500,000,000 $TRI)                     │
│     • Seed: 500M (5%) @ $0.015                                  │
│     • Private: 500M (5%) - pricing TBD                          │
│     • Public: 500M (5%) - pricing TBD                           │
│     • Vesting: 10% TGE, 6-month linear                          │
│                                                                 │
│  5. ECOSYSTEM (10% = 1,000,000,000 $TRI)                       │
│     • Developer grants: 400M                                    │
│     • Liquidity mining: 300M                                    │
│     • Marketing: 200M                                           │
│     • Bug bounties: 100M                                        │
│     • Vesting: 2 years linear                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Fundraising Rounds

```
┌─────────────────────────────────────────────────────────────────┐
│                    FUNDRAISING STRUCTURE                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  SEED ROUND (Current)                                           │
│  ─────────────────────                                          │
│  • Raise: $3,000,000                                            │
│  • Equity: 1%                                                   │
│  • Valuation: $300,000,000                                      │
│  • Token Price: $0.015 (50% discount to FDV)                    │
│  • Tokens: 500,000,000 $TRI (5%)                               │
│  • Vesting: 12-month cliff, 24-month linear                     │
│                                                                 │
│  PRIVATE ROUND (Future)                                         │
│  ─────────────────────                                          │
│  • Allocation: 500,000,000 $TRI (5%)                           │
│  • Pricing: TBD based on network metrics                        │
│  • Trigger: After mainnet launch OR 1,000+ active nodes         │
│  • Vesting: 6-month cliff, 18-month linear                      │
│                                                                 │
│  PUBLIC SALE (TGE)                                              │
│  ─────────────────────                                          │
│  • Allocation: 500,000,000 $TRI (5%)                           │
│  • Pricing: TBD based on market conditions                      │
│  • Trigger: After Private round completion                      │
│  • Vesting: 10% TGE, 6-month linear                             │
│                                                                 │
│  FOUNDER: 100% ownership pre-seed                               │
│  POST-SEED: 99% founder / 1% seed investors                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Valuation Growth Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                    MILESTONE-BASED PRICING                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Future round valuations determined by network growth:          │
│                                                                 │
│  METRIC                          VALUATION MULTIPLIER           │
│  ─────────────────────────────────────────────────────────────  │
│  1,000 active nodes              → 2-3x seed valuation          │
│  10,000 active nodes             → 5-10x seed valuation         │
│  100,000 active nodes            → 10-20x seed valuation        │
│  1B tokens processed/month       → Premium pricing              │
│  Enterprise partnerships         → Strategic round premium      │
│                                                                 │
│  This approach:                                                 │
│  • Rewards early seed investors with maximum upside             │
│  • Allows founder to capture value from network growth          │
│  • Avoids locking in low valuations for future rounds           │
│  • Maintains flexibility for strategic investors                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Token Utility

```
┌─────────────────────────────────────────────────────────────────┐
│                    TOKEN UTILITY                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. PAYMENT FOR INFERENCE                                       │
│     ─────────────────────────                                   │
│     • API users pay $TRI per token processed                   │
│     • Pricing: ~0.00001 $TRI per token (~$0.0000003)           │
│     • 1M tokens ≈ 10 $TRI ≈ $0.30                              │
│     • Bulk discounts for high-volume users                      │
│                                                                 │
│  2. NODE OPERATOR REWARDS                                       │
│     ─────────────────────────                                   │
│     • Earn $TRI for processing inference                       │
│     • Base rate: 9 $TRI per 1M tokens (90% to node)            │
│     • Bonus multipliers:                                        │
│       - Uptime >99%: +10%                                       │
│       - Low latency: +5%                                        │
│       - High throughput: +5%                                    │
│                                                                 │
│  3. STAKING                                                     │
│     ─────────────────────────                                   │
│     • Stake $TRI for priority job allocation                   │
│     • Minimum stake: 10,000 $TRI                               │
│     • Tiers:                                                    │
│       - Bronze (10K): Standard priority                         │
│       - Silver (100K): +20% job allocation                      │
│       - Gold (1M): +50% job allocation                          │
│       - Platinum (10M): +100% job allocation                    │
│     • Staking APY: 8-20% (from protocol fees)                   │
│                                                                 │
│  4. GOVERNANCE                                                  │
│     ─────────────────────────                                   │
│     • 1 $TRI = 1 vote                                          │
│     • Proposals require 1M $TRI to submit                      │
│     • Quorum: 5% of circulating supply                          │
│     • Voting period: 7 days                                     │
│     • Governance scope:                                         │
│       - Protocol parameters (fees, rewards)                     │
│       - Treasury spending                                       │
│       - Model whitelist                                         │
│       - Upgrade proposals                                       │
│                                                                 │
│  5. MODEL MARKETPLACE                                           │
│     ─────────────────────────                                   │
│     • Pay $TRI to download premium models                      │
│     • Model creators earn 80% of sales                          │
│     • Platform fee: 20%                                         │
│                                                                 │
│  6. PREMIUM FEATURES                                            │
│     ─────────────────────────                                   │
│     • Pro subscription: 1,000 $TRI/month                       │
│       - Advanced analytics                                      │
│       - Priority support                                        │
│       - Custom model hosting                                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Economic Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    FEE STRUCTURE                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  INFERENCE FEE FLOW:                                            │
│  ─────────────────────                                          │
│                                                                 │
│  User pays 10 $TRI for inference (1M tokens)                   │
│           │                                                     │
│           ▼                                                     │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                                                        │    │
│  │   Node Operator    ████████████████████  90%  9.00    │    │
│  │   Protocol Fee     ████                  8%   0.80    │    │
│  │   Burn             ██                    2%   0.20    │    │
│  │                                                        │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  PROTOCOL FEE DISTRIBUTION (8%):                                │
│  ─────────────────────────────────                              │
│  • Staking rewards: 50% (4% of total)                           │
│  • Treasury: 30% (2.4% of total)                                │
│  • Development: 20% (1.6% of total)                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Burn Mechanism

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEFLATIONARY MECHANICS                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  AUTOMATIC BURN:                                                │
│  • 2% of all inference fees burned                              │
│  • Reduces circulating supply over time                         │
│                                                                 │
│  PROJECTED BURN (at scale):                                     │
│  ─────────────────────────────                                  │
│  Year 1: 100B tokens processed → 2M $TRI burned                │
│  Year 2: 1T tokens → 20M $TRI burned                           │
│  Year 3: 10T tokens → 200M $TRI burned                         │
│  Year 5: 100T tokens → 2B $TRI burned                          │
│                                                                 │
│  BURN ADDRESS:                                                  │
│  0x000000000000000000000000000000000000dEaD                      │
│                                                                 │
│  ADDITIONAL BURNS:                                              │
│  • Slashed stakes (malicious nodes)                             │
│  • Expired governance proposals                                 │
│  • Unclaimed rewards (after 1 year)                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Emission Schedule

```
┌─────────────────────────────────────────────────────────────────┐
│                    EMISSION SCHEDULE                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  YEAR    NODE REWARDS    CUMULATIVE      % OF TOTAL             │
│  ────────────────────────────────────────────────               │
│  1       800,000,000     800,000,000     8%                     │
│  2       600,000,000     1,400,000,000   14%                    │
│  3       400,000,000     1,800,000,000   18%                    │
│  4       400,000,000     2,200,000,000   22%                    │
│  5       300,000,000     2,500,000,000   25%                    │
│  6       300,000,000     2,800,000,000   28%                    │
│  7       250,000,000     3,050,000,000   30.5%                  │
│  8       250,000,000     3,300,000,000   33%                    │
│  9       200,000,000     3,500,000,000   35%                    │
│  10      200,000,000     3,700,000,000   37%                    │
│  11+     300,000,000     4,000,000,000   40% (cap)              │
│                                                                 │
│  EMISSION CURVE:                                                │
│  ─────────────────                                              │
│  1B   ┤                                                         │
│       │ ████                                                    │
│  750M ┤ ████ ████                                               │
│       │ ████ ████ ████ ████                                     │
│  500M ┤ ████ ████ ████ ████ ████ ████                           │
│       │ ████ ████ ████ ████ ████ ████ ████ ████ ████ ████       │
│  250M ┤ ████ ████ ████ ████ ████ ████ ████ ████ ████ ████       │
│       └──────────────────────────────────────────────────       │
│         Y1   Y2   Y3   Y4   Y5   Y6   Y7   Y8   Y9   Y10        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Price Scenarios

```
┌─────────────────────────────────────────────────────────────────┐
│                    PRICE PROJECTIONS                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ASSUMPTIONS:                                                   │
│  • Launch price: $0.03                                          │
│  • Circulating at launch: 1.5B (15%)                            │
│  • Market cap at launch: $45M                                   │
│  • FDV: $300M                                                   │
│                                                                 │
│  SCENARIO ANALYSIS:                                             │
│  ─────────────────────                                          │
│                                                                 │
│  BEAR CASE:                                                     │
│  • Price: $0.01                                                 │
│  • Market Cap: $15M                                             │
│  • FDV: $100M                                                   │
│  • Node earnings: ~$0.09 per 1M tokens                          │
│                                                                 │
│  BASE CASE:                                                     │
│  • Price: $0.03                                                 │
│  • Market Cap: $45M                                             │
│  • FDV: $300M                                                   │
│  • Node earnings: ~$0.27 per 1M tokens                          │
│                                                                 │
│  BULL CASE:                                                     │
│  • Price: $0.10                                                 │
│  • Market Cap: $150M                                            │
│  • FDV: $1B                                                     │
│  • Node earnings: ~$0.90 per 1M tokens                          │
│                                                                 │
│  MOON CASE:                                                     │
│  • Price: $0.30                                                 │
│  • Market Cap: $450M                                            │
│  • FDV: $3B                                                     │
│  • Node earnings: ~$2.70 per 1M tokens                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Circulating Supply Schedule

```
┌─────────────────────────────────────────────────────────────────┐
│                    CIRCULATING SUPPLY                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  MONTH    CIRCULATING     % OF TOTAL    UNLOCK EVENT            │
│  ────────────────────────────────────────────────────────────   │
│  TGE      1,500,000,000   15%           Public sale (10%)       │
│  M6       2,200,000,000   22%           Public vesting          │
│  M12      3,000,000,000   30%           Team cliff, Seed cliff  │
│  M18      3,800,000,000   38%           Private vesting         │
│  M24      4,500,000,000   45%           Ecosystem unlock        │
│  M36      5,500,000,000   55%           Team vesting            │
│  M48      6,500,000,000   65%           Full team unlock        │
│  Y5       7,500,000,000   75%           Node rewards            │
│  Y10      10,000,000,000  100%          Full circulation        │
│                                                                 │
│  SUPPLY CURVE:                                                  │
│  ─────────────────                                              │
│  10B ┤                                              ████████    │
│      │                                    ██████████            │
│  7.5B┤                          ██████████                      │
│      │                ██████████                                │
│   5B ┤        ████████                                          │
│      │  ██████                                                  │
│  2.5B┤██                                                        │
│      └──────────────────────────────────────────────────        │
│       TGE  Y1   Y2   Y3   Y4   Y5   Y6   Y7   Y8   Y9   Y10     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Comparison with Competitors

```
┌─────────────────────────────────────────────────────────────────┐
│                    MARKET COMPARISON                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  PROJECT         SUPPLY        FDV          NODE REWARDS        │
│  ─────────────────────────────────────────────────────────────  │
│  Render (RNDR)   536M          $4.5B        30%                 │
│  Akash (AKT)     388M          $1.2B        35%                 │
│  Golem (GLM)     1B            $500M        25%                 │
│  io.net (IO)     800M          $2B          40%                 │
│  ─────────────────────────────────────────────────────────────  │
│  Trinity ($TRI)  10B           $300M        40%                 │
│                                                                 │
│  TRINITY ADVANTAGES:                                            │
│  • Higher node reward allocation (40%)                          │
│  • Lower entry valuation = more upside                          │
│  • CPU-only = larger potential node base                        │
│  • Ternary inference = unique technology moat                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Use of Funds (Seed Round)

```
┌─────────────────────────────────────────────────────────────────┐
│                    USE OF FUNDS ($3M)                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                                                        │    │
│  │   Engineering       ████████████████  50%  $1,500,000 │    │
│  │   Infrastructure    ██████            20%  $600,000   │    │
│  │   Marketing         ████              15%  $450,000   │    │
│  │   Legal/Compliance  ███               10%  $300,000   │    │
│  │   Operations        ██                 5%  $150,000   │    │
│  │                                                        │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  ENGINEERING ($1.5M):                                           │
│  • Core team salaries (12 months)                               │
│  • Trinity Node development                                     │
│  • BitNet model optimization                                    │
│  • Security audits                                              │
│                                                                 │
│  INFRASTRUCTURE ($600K):                                        │
│  • Bootstrap nodes                                              │
│  • Model CDN                                                    │
│  • API infrastructure                                           │
│  • Monitoring systems                                           │
│                                                                 │
│  MARKETING ($450K):                                             │
│  • Community building                                           │
│  • Developer relations                                          │
│  • Conference presence                                          │
│  • Content creation                                             │
│                                                                 │
│  LEGAL/COMPLIANCE ($300K):                                      │
│  • Token legal structure                                        │
│  • Regulatory compliance                                        │
│  • IP protection                                                │
│                                                                 │
│  OPERATIONS ($150K):                                            │
│  • Office/remote setup                                          │
│  • Tools and services                                           │
│  • Contingency                                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Metrics

| Metric | Value |
|--------|-------|
| Total Supply | 10,000,000,000 $TRI |
| Seed Round | $3,000,000 for 1% |
| Seed Valuation | $300,000,000 |
| Seed Token Price | $0.015 |
| Founder Ownership | 99% post-seed |
| Node Reward Pool | 4,000,000,000 (40%) |
| Burn Rate | 2% of fees |
| Staking APY | 8-20% |
| Private/Public Pricing | TBD (milestone-based) |

---

## Token Contract

```
Network:        Ethereum Mainnet + Trinity L2
Standard:       ERC-20
Contract:       TBD (after audit)
Decimals:       18
Upgradeable:    No (immutable)
```

---

## Vesting Contracts

All vesting enforced on-chain via smart contracts:
- Linear vesting with cliff support
- Revocable for team (pre-cliff only)
- Non-revocable for investors
- Audited by [TBD]

---

*$TRI - Powering Trinity Network*

**Seed Round: $3M for 1% | Valuation: $300M | Founder: 99%**
