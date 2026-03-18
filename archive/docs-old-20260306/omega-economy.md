# Omega Economy (Ω) — Reputation-Based Multi-Cluster Rewards

## Overview

The **Omega Economy** is Trinity DePIN's reputation-based reward system that activates when the global mesh reaches critical mass. Named after the final letter of the Greek alphabet (Ω), it represents the ultimate state of network maturity where reputation becomes the primary reward multiplier.

## Activation Condition

```
TOTAL_REPUTATION >= 1000
```

When the sum of all node reputations in the global mesh reaches 1000, the Omega Economy activates automatically. This typically requires:

| Nodes | Avg Reputation | Total Reputation |
|-------|----------------|------------------|
| 10    | 1.0            | 1000             |
| 15    | 0.67           | 1000             |
| 20    | 0.5            | 1000             |

## Reputation System

### Earning Reputation

Reputation (0.0 to 1.0) increases through:

| Action | Reputation Gain |
|--------|-----------------|
| Hour of uptime | +0.001 |
| Successful job completion | +0.01 |
| Helping relay packets | +0.005 per packet |
| Detecting malicious node | +0.1 |
| 99.9% uptime for 30 days | +0.5 |

### Losing Reputation

| Action | Reputation Loss |
|--------|-----------------|
| Downtime > 1 hour | -0.01 |
| Failed job | -0.02 |
| Missing heartbeat | -0.005 |
| Malicious behavior | -1.0 (ban) |

## Omega Multipliers

When activated, reputation directly affects $TRI rewards:

```
OMEGA_MULTIPLIER = 1.0 + (node_reputation × 2.0)

$TRI/second = base_rate × role_multiplier × region_multiplier × omega_multiplier
```

### Examples

| Reputation | Omega Multiplier | Base $TRI/hr | With Omega |
|------------|------------------|--------------|------------|
| 0.0        | 1.0×             | 3.6          | 3.6        |
| 0.25       | 1.5×             | 3.6          | 5.4        |
| 0.5        | 2.0×             | 3.6          | 7.2        |
| 0.75       | 2.5×             | 3.6          | 9.0        |
| 1.0        | 3.0×             | 3.6          | 10.8       |

*For worker role, base region*

## Global Mesh Routing

### Pre-Omega (Standard)

- Local region discovery only
- Direct peer-to-peer connections
- No cross-region relay

### Post-Omega (Global)

- Cross-region mesh relay enabled
- Intelligent routing based on reputation
- Premium nodes prioritize high-reputation paths

### Relay Protocol

```
RelayPacket:
  source_id: String
  target_id: String
  original_sender: String
  hop_count: Int
  ttl: Int (max 10 hops)
  payload: String
```

High-reputation nodes earn extra $TRI for relaying:
- Base relay reward: 0.0001 $TRI per packet
- Reputation multiplier applies
- Anti-spam: max 1000 packets/minute per node

## Region Rewards

### Multipliers by Region

| Region | Multiplier | Rationale |
|--------|------------|-----------|
| us-east | 1.0× | Base region |
| us-west | 1.0× | Abundant nodes |
| eu-central | 1.2× | Premium for latency |
| asia-pacific | 1.3× | Highest demand |
| south-america | 1.4× | Emerging market |
| africa | 1.5× | Underserved region |

### Cross-Region Latency Targets

| Source | Destination | Target Latency |
|--------|-------------|----------------|
| us-east | us-west | < 100ms |
| us-east | eu-central | < 150ms |
| us-east | asia-pacific | < 200ms |
| eu-central | asia-pacific | < 180ms |

## Premium Rewards Structure

### Omega Tiers

| Tier | Reputation Required | Benefits |
|------|---------------------|----------|
| Bronze | 0.0 - 0.3 | Standard rewards |
| Silver | 0.3 - 0.6 | 1.5× rewards, priority jobs |
| Gold | 0.6 - 0.8 | 2.0× rewards, global routing |
| Platinum | 0.8 - 0.95 | 2.5× rewards, governance |
| Diamond | 0.95 - 1.0 | 3.0× rewards, exclusive pools |

### Governance Rights (Platinum+)

- Vote on protocol parameters
- Propose feature requests
- Access to developer pre-releases
- Premium support channel

## Anti-Gaming Measures

### Sybil Resistance

- One node per hardware signature
- Proof of Hardware required
- Minimum 24 hours bonding period
- Reputation non-transferable

### Reputation Decay

- Inactive nodes: -0.001 reputation/hour
- Rejoin penalty: -0.2 reputation
- Minimum 0.1 reputation to earn rewards

### Rate Limiting

- Max reputation gain: 0.1 per day
- Max relay rewards: 10 $TRI/day per node
- Job completion: max 100 per day counts toward reputation

## Monitoring Dashboard

### Omega Metrics

```bash
curl http://localhost:9001/omega/status
```

Response:
```json
{
  "omega_active": true,
  "total_reputation": 1234.5,
  "active_nodes": 15,
  "avg_reputation": 0.82,
  "top_earners": [
    {"node_id": "trinity-001", "reputation": 0.98, "tri_earned": 1234.5},
    {"node_id": "trinity-007", "reputation": 0.95, "tri_earned": 1180.2}
  ],
  "regions": {
    "us-east": {"count": 5, "avg_reputation": 0.75},
    "eu-central": {"count": 4, "avg_reputation": 0.85},
    "asia-pacific": {"count": 6, "avg_reputation": 0.88}
  }
}
```

## Technical Implementation

### Activate Omega Economy

Generated from `specs/depin/global-mesh-v1.tri`:

```zig
pub fn activateOmegaEconomy() !void {
    // Enable reputation multipliers
    // Enable global routing
    // Enable premium rewards
}
```

### Calculate Region-Aware Rewards

```zig
pub fn calculateRegionAwareRewards(node: MeshNode, region: Region) f64 {
    const base_rate = 0.001;  // $TRI per second
    const role_mult = getRoleMultiplier(node.role);
    const region_mult = getRegionMultiplier(region);
    const reput_mult = node.reputation + 0.5;  // Reputation bonus

    return @as(f64, @floatFromInt(node.uptime_seconds))
        * base_rate * role_mult * region_mult * reput_mult;
}
```

## Timeline

### Phase 1: Bootstrapping (Now)
- Standard rewards only
- Local region discovery
- Building reputation

### Phase 2: Critical Mass (30-60 days)
- 10-15 nodes active
- Total reputation approaching 1000
- Cross-region testing

### Phase 3: Omega Activation (60-90 days)
- Omega economy enabled
- Global mesh routing live
- Premium rewards active

### Phase 4: Maturity (90+ days)
- 50+ nodes worldwide
- Self-sustaining economy
- Governance enabled

## φ² + 1/φ² = 3 = TRINITY

The Omega Economy embodies the Trinity principle through three pillars:

1. **Reputation** — Proof of honest participation
2. **Routing** — Global mesh connectivity
3. **Rewards** — Fair value distribution

When reputation reaches critical mass, the network undergoes phase transition from simple reward distribution to sophisticated economic system.
