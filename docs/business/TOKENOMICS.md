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
│  Total Supply:   1,000,000,000 (1 billion)                      │
│  Decimals:       18                                             │
│  Type:           ERC-20 (Ethereum) + Native (Trinity L2)        │
│  Initial Price:  $0.01 (target)                                 │
│  FDV at Launch:  $10,000,000                                    │
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
│  │   Node Rewards     ████████████████████  40%  400M    │    │
│  │   Team & Advisors  ████████            20%  200M    │    │
│  │   Treasury (DAO)   ██████              15%  150M    │    │
│  │   Public Sale      ██████              15%  150M    │    │
│  │   Ecosystem        ████                10%  100M    │    │
│  │                                                        │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  DETAILED BREAKDOWN:                                            │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  1. NODE REWARDS (40% = 400M $TRI)                             │
│     • Purpose: Incentivize compute providers                    │
│     • Vesting: Linear over 10 years                             │
│     • Year 1: 80M (20%)                                         │
│     • Year 2: 60M (15%)                                         │
│     • Year 3-10: 32.5M/year (halving schedule)                  │
│                                                                 │
│  2. TEAM & ADVISORS (20% = 200M $TRI)                          │
│     • Team: 150M (15%)                                          │
│     • Advisors: 50M (5%)                                        │
│     • Vesting: 4 years, 1-year cliff                            │
│     • Monthly unlock after cliff                                │
│                                                                 │
│  3. TREASURY (15% = 150M $TRI)                                 │
│     • Controlled by DAO governance                              │
│     • Uses: Grants, partnerships, emergencies                   │
│     • Unlock: 10% at launch, rest via governance                │
│                                                                 │
│  4. PUBLIC SALE (15% = 150M $TRI)                              │
│     • Seed: 50M (5%) @ $0.005                                   │
│     • Private: 50M (5%) @ $0.008                                │
│     • Public: 50M (5%) @ $0.01                                  │
│     • Vesting: 10% TGE, 6-month linear                          │
│                                                                 │
│  5. ECOSYSTEM (10% = 100M $TRI)                                │
│     • Developer grants: 40M                                     │
│     • Liquidity mining: 30M                                     │
│     • Marketing: 20M                                            │
│     • Bug bounties: 10M                                         │
│     • Vesting: 2 years linear                                   │
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
│     • Pricing: ~0.000001 $TRI per token (~$0.00001)            │
│     • 1M tokens ≈ 1 $TRI ≈ $0.01                               │
│     • Bulk discounts for high-volume users                      │
│                                                                 │
│  2. NODE OPERATOR REWARDS                                       │
│     ─────────────────────────                                   │
│     • Earn $TRI for processing inference                       │
│     • Base rate: 0.9 $TRI per 1M tokens (90% to node)          │
│     • Bonus multipliers:                                        │
│       - Uptime >99%: +10%                                       │
│       - Low latency: +5%                                        │
│       - High throughput: +5%                                    │
│                                                                 │
│  3. STAKING                                                     │
│     ─────────────────────────                                   │
│     • Stake $TRI for priority job allocation                   │
│     • Minimum stake: 1,000 $TRI                                │
│     • Tiers:                                                    │
│       - Bronze (1K): Standard priority                          │
│       - Silver (10K): +20% job allocation                       │
│       - Gold (100K): +50% job allocation                        │
│       - Platinum (1M): +100% job allocation                     │
│     • Staking APY: 5-15% (from protocol fees)                   │
│                                                                 │
│  4. GOVERNANCE                                                  │
│     ─────────────────────────                                   │
│     • 1 $TRI = 1 vote                                          │
│     • Proposals require 100K $TRI to submit                    │
│     • Quorum: 10% of circulating supply                         │
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
│     • Pro subscription: 100 $TRI/month                         │
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
│  User pays 1 $TRI for inference                                │
│           │                                                     │
│           ▼                                                     │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                                                        │    │
│  │   Node Operator    ████████████████████  90%  0.90    │    │
│  │   Protocol Fee     ████                  8%   0.08    │    │
│  │   Burn             ██                    2%   0.02    │    │
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
│  Year 1: 10B tokens processed → 200K $TRI burned               │
│  Year 2: 100B tokens → 2M $TRI burned                          │
│  Year 3: 1T tokens → 20M $TRI burned                           │
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
│  YEAR    NODE REWARDS    CUMULATIVE    % OF TOTAL               │
│  ────────────────────────────────────────────────               │
│  1       80,000,000      80,000,000    8%                       │
│  2       60,000,000      140,000,000   14%                      │
│  3       40,000,000      180,000,000   18%                      │
│  4       40,000,000      220,000,000   22%                      │
│  5       30,000,000      250,000,000   25%                      │
│  6       30,000,000      280,000,000   28%                      │
│  7       25,000,000      305,000,000   30.5%                    │
│  8       25,000,000      330,000,000   33%                      │
│  9       20,000,000      350,000,000   35%                      │
│  10      20,000,000      370,000,000   37%                      │
│  11+     30,000,000      400,000,000   40% (cap)                │
│                                                                 │
│  EMISSION CURVE:                                                │
│  ─────────────────                                              │
│  100M ┤                                                         │
│       │ ████                                                    │
│   75M ┤ ████ ████                                               │
│       │ ████ ████ ████ ████                                     │
│   50M ┤ ████ ████ ████ ████ ████ ████                           │
│       │ ████ ████ ████ ████ ████ ████ ████ ████ ████ ████       │
│   25M ┤ ████ ████ ████ ████ ████ ████ ████ ████ ████ ████       │
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
│  • Launch price: $0.01                                          │
│  • Circulating at launch: 150M (15%)                            │
│  • Market cap at launch: $1.5M                                  │
│                                                                 │
│  SCENARIO: CONSERVATIVE                                         │
│  ─────────────────────────                                      │
│  Year 1: $0.02 (2x) - 10K nodes, 1B tokens/month                │
│  Year 2: $0.05 (5x) - 50K nodes, 10B tokens/month               │
│  Year 3: $0.10 (10x) - 100K nodes, 100B tokens/month            │
│                                                                 │
│  SCENARIO: BASE CASE                                            │
│  ─────────────────────                                          │
│  Year 1: $0.05 (5x) - 25K nodes                                 │
│  Year 2: $0.20 (20x) - 100K nodes                               │
│  Year 3: $0.50 (50x) - 500K nodes                               │
│                                                                 │
│  SCENARIO: BULLISH                                              │
│  ─────────────────────                                          │
│  Year 1: $0.10 (10x) - 50K nodes                                │
│  Year 2: $0.50 (50x) - 250K nodes                               │
│  Year 3: $2.00 (200x) - 1M nodes                                │
│                                                                 │
│  KEY DRIVERS:                                                   │
│  • Network growth (nodes)                                       │
│  • API usage (tokens processed)                                 │
│  • Token burns (deflationary)                                   │
│  • Staking lockup (reduced supply)                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Governance

```
┌─────────────────────────────────────────────────────────────────┐
│                    DAO GOVERNANCE                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  PROPOSAL TYPES:                                                │
│  ─────────────────                                              │
│  • TIP (Trinity Improvement Proposal): Protocol changes         │
│  • TGP (Trinity Grant Proposal): Treasury spending              │
│  • TEP (Trinity Emergency Proposal): Urgent fixes               │
│                                                                 │
│  VOTING PROCESS:                                                │
│  ─────────────────                                              │
│  1. Discussion (Forum): 3 days minimum                          │
│  2. Proposal submission: 100K $TRI deposit                     │
│  3. Voting period: 7 days                                       │
│  4. Execution: 2-day timelock                                   │
│                                                                 │
│  QUORUM REQUIREMENTS:                                           │
│  ─────────────────────                                          │
│  • Standard proposals: 10% of circulating supply                │
│  • Emergency proposals: 20% of circulating supply               │
│  • Constitutional changes: 30% of circulating supply            │
│                                                                 │
│  VOTING POWER:                                                  │
│  ─────────────────                                              │
│  • 1 $TRI = 1 vote                                             │
│  • Staked tokens: 1.5x voting power                             │
│  • Delegation allowed                                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Security

```
┌─────────────────────────────────────────────────────────────────┐
│                    TOKEN SECURITY                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  SMART CONTRACT:                                                │
│  • Audited by: [Top-tier auditor TBD]                           │
│  • Open source: GitHub                                          │
│  • Bug bounty: Up to $100K                                      │
│                                                                 │
│  MULTISIG:                                                      │
│  • Treasury: 4/7 multisig                                       │
│  • Team tokens: 3/5 multisig                                    │
│  • Timelock: 48 hours for large transfers                       │
│                                                                 │
│  VESTING CONTRACTS:                                             │
│  • Immutable vesting schedules                                  │
│  • No admin keys after deployment                               │
│  • Cliff enforcement on-chain                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Summary

| Metric | Value |
|--------|-------|
| Total Supply | 1,000,000,000 $TRI |
| Initial Circulating | ~150,000,000 (15%) |
| Launch Price | $0.01 |
| Initial Market Cap | $1,500,000 |
| FDV | $10,000,000 |
| Node Reward Pool | 400,000,000 (40%) |
| Burn Rate | 2% of fees |
| Staking APY | 5-15% |

---

*$TRI - Powering Trinity Network*
