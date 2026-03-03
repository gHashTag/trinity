# $TRI Economy — Trinity DePIN Reward System

## Overview

$TRI is the native token of the Trinity DePIN network, earned by hardware node operators for providing compute, storage, and network resources to the decentralized cluster.

## Token Specifications

| Property | Value |
|----------|-------|
| Symbol | $TRI |
| Decimals | 18 |
| Initial Supply | 1,000,000,000 $TRI |
| Initial Price Target | $0.10 USD |

## Reward Formula

```
$TRI per second = base_rate × role_multiplier
$TRI per hour = 3600 × base_rate × role_multiplier
$TRI per day = 86400 × base_rate × role_multiplier

Where:
- base_rate = 0.001 $TRI/second
- role_multiplier: 1.5 (primary), 1.2 (secondary), 1.0 (worker)

With contributions:
$TRI = (uptime_seconds × 0.001 × role_multiplier) + (contributions × 0.01)
```

## Role Multipliers

| Role | Multiplier | Rationale |
|------|------------|-----------|
| Primary | 1.5× | Cluster coordinator, highest responsibility |
| Secondary | 1.2× | Backup primary, participates in consensus |
| Worker | 1.0× | Base compute, no consensus participation |

## Earning Projections

### Per Node (24 hours uptime)

| Hardware | Role | Daily $TRI | Monthly $TRI | USD Value* |
|----------|------|------------|--------------|------------|
| Raspberry Pi 4 | Worker | 86.4 | 2,592 | ~$259 |
| Raspberry Pi 5 | Secondary | 103.7 | 3,111 | ~$311 |
| Apple M1/M2 | Primary | 129.6 | 3,888 | ~$389 |
| Intel Server | Primary | 129.6 | 3,888 | ~$389 |

*Assuming $1 TRI = $0.10 USD at launch

### Break-Even Analysis

| Hardware | Cost | Daily Earnings | Break-Even Days |
|----------|------|---------------|----------------|
| Raspberry Pi 4 kit | $75 | $0.26 | ~288 days |
| Used Mac mini | $200 | $0.39 | ~512 days |
| Server (used) | $2000 | $0.39 | ~5128 days |

**Note:** Break-even assumes only rewards. Nodes can also earn from:
- Compute marketplace jobs
- Storage rental
- Bandwidth sharing
- Content delivery

## Claiming Rewards

### Manual Claim
```bash
curl -X POST http://localhost:9001/rewards/claim \
  -H "Content-Type: application/json" \
  -d '{"wallet": "0x1234567890abcdef"}'
```

### Auto-Claim
Configure in `tri-depin.yaml`:
```yaml
rewards:
  auto_claim: true
  threshold: 100.0  # Auto-claim when >= 100 $TRI
  wallet: "0x1234567890abcdef"
```

### Claim Response
```json
{
  "success": true,
  "amount_claimed": 100.0,
  "transaction_hash": "0xabcdef...",
  "new_balance": 250.0
}
```

## Reward Distribution Schedule

| Frequency | When |
|-----------|-------|
| Calculation | Every 60 seconds |
| Update | Live (node local balance) |
| Claim | Manual or auto-threshold |
| Payout | On-chain within 24 hours |

## Inflation Model

| Year | Emission Rate | Annual Emission | Circulating Supply |
|------|---------------|-----------------|-------------------|
| 1 | 100% | 365M $TRI | 365M |
| 2 | 50% | 182.5M $TRI | 547.5M |
| 3 | 25% | 91.25M $TRI | 638.75M |
| 4 | 12.5% | 45.6M $TRI | 684.35M |
| 5+ | 6.25% | ~23M $TRI/year | Approaching 1B cap |

## Node Requirements

### Minimum Viable
- 4 CPU cores
- 4GB RAM
- 32GB storage
- 100 Mbps Ethernet
- 99% uptime target

### Recommended
- 8+ CPU cores
- 8GB+ RAM
- 256GB NVMe
- 1 Gbps Ethernet
- 99.9% uptime target

## Economic Security

### Slashing
Nodes can lose $TRI for:
- Downtime > 1 hour: 10% penalty
- Malicious behavior: 100% slashing
- Double-signing: 100% slashing
- Failure to validate: 5% penalty

### Sybil Resistance
- One node per hardware signature
- Proof of Hardware required
- Minimum 24 hours bonding period

## φ² + 1/φ² = 3 = TRINITY
