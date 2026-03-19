#!/usr/bin/env python3
"""
$TRI Growth Demo - 100+ Node Network Simulation
Supply: 3^21 = 10,460,353,203 $TRI (Phoenix Number)
φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL
"""

import random
import time
import hashlib
from dataclasses import dataclass, field
from typing import List, Dict, Tuple
from datetime import datetime, timedelta

# ═══════════════════════════════════════════════════════════════════════════════
# SACRED CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

PHI = 1.618033988749895
PHOENIX_NUMBER = 3 ** 21  # 10,460,353,203
BLOCK_TIME = 3  # seconds
INITIAL_BLOCK_REWARD = 100
HALVING_BLOCKS = 21_024_000  # ~2 years

# Tokenomics
ALLOCATIONS = {
    "Founder & Team": {"pct": 20, "amount": PHOENIX_NUMBER * 20 // 100, "vesting": 48, "cliff": 12},
    "Node Rewards": {"pct": 40, "amount": PHOENIX_NUMBER * 40 // 100, "vesting": 120, "cliff": 0},
    "Community": {"pct": 20, "amount": PHOENIX_NUMBER * 20 // 100, "vesting": 36, "cliff": 0},
    "Treasury": {"pct": 10, "amount": PHOENIX_NUMBER * 10 // 100, "vesting": 60, "cliff": 6},
    "Liquidity": {"pct": 10, "amount": PHOENIX_NUMBER * 10 // 100, "vesting": 0, "cliff": 0},
}

# ═══════════════════════════════════════════════════════════════════════════════
# NODE TYPES & REGIONS
# ═══════════════════════════════════════════════════════════════════════════════

NODE_TYPES = [
    {"type": "GPU", "speed_mult": 3.0, "stake_min": 10000, "weight": 0.2},
    {"type": "CPU", "speed_mult": 1.0, "stake_min": 1000, "weight": 0.5},
    {"type": "Mobile", "speed_mult": 0.3, "stake_min": 100, "weight": 0.3},
]

REGIONS = [
    {"name": "Asia-Pacific", "weight": 0.35, "latency_base": 50},
    {"name": "Europe", "weight": 0.25, "latency_base": 80},
    {"name": "North America", "weight": 0.25, "latency_base": 100},
    {"name": "South America", "weight": 0.08, "latency_base": 150},
    {"name": "Africa", "weight": 0.05, "latency_base": 200},
    {"name": "Oceania", "weight": 0.02, "latency_base": 120},
]

# ═══════════════════════════════════════════════════════════════════════════════
# DATA STRUCTURES
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class Node:
    node_id: str
    node_type: str
    region: str
    stake: int
    balance: int = 0
    blocks_mined: int = 0
    inferences: int = 0
    tokens_processed: int = 0
    rewards_earned: int = 0
    speed_mult: float = 1.0
    joined_at: float = field(default_factory=time.time)
    last_active: float = field(default_factory=time.time)
    uptime_hours: float = 0

    def effective_stake(self) -> int:
        """Stake weight with activity bonus"""
        activity_bonus = min(self.inferences // 10, 100)
        type_bonus = int(self.speed_mult * 10)
        return self.stake * (100 + activity_bonus + type_bonus) // 100


@dataclass
class Block:
    height: int
    prev_hash: str
    miner: str
    timestamp: float
    transactions: int
    reward: int
    region: str

    def hash(self) -> str:
        data = f"{self.height}{self.prev_hash}{self.miner}{self.timestamp}"
        return hashlib.sha256(data.encode()).hexdigest()[:16]


@dataclass
class NetworkStats:
    total_nodes: int = 0
    active_nodes: int = 0
    total_stake: int = 0
    total_blocks: int = 0
    total_inferences: int = 0
    total_tokens: int = 0
    total_rewards: int = 0
    circulating_supply: int = 0
    avg_block_time: float = 3.0
    tps: float = 0.0  # transactions per second
    network_hashrate: float = 0.0


# ═══════════════════════════════════════════════════════════════════════════════
# GROWTH SIMULATION
# ═══════════════════════════════════════════════════════════════════════════════

class GrowthSimulation:
    def __init__(self, num_nodes: int = 100):
        self.nodes: Dict[str, Node] = {}
        self.blocks: List[Block] = []
        self.total_supply = PHOENIX_NUMBER
        self.circulating_supply = 0
        self.stats = NetworkStats()

        # Create genesis block
        self._create_genesis()

        # Initialize nodes with distribution
        self._init_nodes(num_nodes)

    def _create_genesis(self):
        """Create genesis block"""
        genesis = Block(
            height=0,
            prev_hash="0" * 16,
            miner="genesis",
            timestamp=time.time(),
            transactions=0,
            reward=0,
            region="Genesis"
        )
        self.blocks.append(genesis)

    def _init_nodes(self, num_nodes: int):
        """Initialize nodes with realistic distribution"""
        for i in range(num_nodes):
            # Select type based on weight
            r = random.random()
            cumulative = 0
            node_type = NODE_TYPES[0]
            for nt in NODE_TYPES:
                cumulative += nt["weight"]
                if r <= cumulative:
                    node_type = nt
                    break

            # Select region based on weight
            r = random.random()
            cumulative = 0
            region = REGIONS[0]
            for reg in REGIONS:
                cumulative += reg["weight"]
                if r <= cumulative:
                    region = reg
                    break

            # Generate stake based on type
            stake = random.randint(
                node_type["stake_min"],
                node_type["stake_min"] * 10
            )

            node_id = f"node_{i:03d}"
            self.nodes[node_id] = Node(
                node_id=node_id,
                node_type=node_type["type"],
                region=region["name"],
                stake=stake,
                speed_mult=node_type["speed_mult"],
                uptime_hours=random.uniform(1, 720)  # 1 hour to 30 days
            )

    def calculate_block_reward(self, height: int) -> int:
        """Calculate block reward with halving"""
        halvings = height // HALVING_BLOCKS
        if halvings >= 64:
            return 0
        return INITIAL_BLOCK_REWARD >> halvings

    def calculate_inference_reward(self, tokens: int, coherent: bool) -> int:
        """Calculate inference reward"""
        base = tokens // 1000  # 1 $TRI per 1000 tokens
        return base * 2 if coherent else base

    def select_miner(self) -> str:
        """Select miner based on effective stake (PoS)"""
        total_stake = sum(n.effective_stake() for n in self.nodes.values())
        if total_stake == 0:
            return random.choice(list(self.nodes.keys()))

        r = random.randint(0, total_stake)
        cumulative = 0
        for node_id, node in self.nodes.items():
            cumulative += node.effective_stake()
            if r <= cumulative:
                return node_id
        return list(self.nodes.keys())[-1]

    def mine_block(self) -> Block:
        """Mine a new block"""
        miner_id = self.select_miner()
        miner = self.nodes[miner_id]

        height = len(self.blocks)
        prev_hash = self.blocks[-1].hash()
        reward = self.calculate_block_reward(height)

        # Random transactions in block
        tx_count = random.randint(10, 100)

        block = Block(
            height=height,
            prev_hash=prev_hash,
            miner=miner_id,
            timestamp=time.time(),
            transactions=tx_count,
            reward=reward,
            region=miner.region
        )

        # Update miner stats
        miner.blocks_mined += 1
        miner.balance += reward
        miner.rewards_earned += reward
        miner.last_active = time.time()
        self.circulating_supply += reward

        self.blocks.append(block)
        return block

    def simulate_inference(self, node_id: str) -> Tuple[int, int]:
        """Simulate inference and return (tokens, reward)"""
        if node_id not in self.nodes:
            return 0, 0

        node = self.nodes[node_id]

        # Token count based on node type
        base_tokens = int(1000 * node.speed_mult)
        tokens = random.randint(base_tokens, base_tokens * 5)

        # 90% coherent rate
        coherent = random.random() > 0.1

        reward = self.calculate_inference_reward(tokens, coherent)

        node.inferences += 1
        node.tokens_processed += tokens
        node.balance += reward
        node.rewards_earned += reward
        node.last_active = time.time()
        self.circulating_supply += reward

        return tokens, reward

    def run_simulation(self, num_blocks: int = 100, inferences_per_block: int = 10):
        """Run growth simulation"""
        print("\n" + "=" * 80)
        print("$TRI NETWORK GROWTH SIMULATION")
        print(f"Supply: 3^21 = {PHOENIX_NUMBER:,} $TRI | Nodes: {len(self.nodes)}")
        print("=" * 80)

        total_tokens = 0
        total_inferences = 0

        for i in range(num_blocks):
            # Mine block
            block = self.mine_block()

            if (i + 1) % 10 == 0:
                print(f"Block {block.height}: Miner {block.miner} ({block.region}) | +{block.reward} $TRI")

            # Simulate inferences across random nodes
            for _ in range(inferences_per_block):
                node_id = random.choice(list(self.nodes.keys()))
                tokens, reward = self.simulate_inference(node_id)
                total_tokens += tokens
                total_inferences += 1

        self._update_stats(total_inferences, total_tokens)
        return self._print_summary()

    def _update_stats(self, total_inferences: int, total_tokens: int):
        """Update network statistics"""
        self.stats.total_nodes = len(self.nodes)
        self.stats.active_nodes = sum(1 for n in self.nodes.values() if n.inferences > 0 or n.blocks_mined > 0)
        self.stats.total_stake = sum(n.stake for n in self.nodes.values())
        self.stats.total_blocks = len(self.blocks)
        self.stats.total_inferences = total_inferences
        self.stats.total_tokens = total_tokens
        self.stats.total_rewards = sum(n.rewards_earned for n in self.nodes.values())
        self.stats.circulating_supply = self.circulating_supply
        self.stats.tps = total_inferences / (len(self.blocks) * BLOCK_TIME)

    def _print_summary(self) -> Dict:
        """Print simulation summary"""
        print("\n" + "=" * 80)
        print("NETWORK GROWTH SUMMARY")
        print("=" * 80)

        # Node distribution by type
        type_dist = {}
        for node in self.nodes.values():
            type_dist[node.node_type] = type_dist.get(node.node_type, 0) + 1

        print(f"\n📊 Node Distribution:")
        for ntype, count in sorted(type_dist.items()):
            pct = 100 * count / len(self.nodes)
            bar = "█" * int(pct / 2)
            print(f"  {ntype:8}: {count:3} ({pct:5.1f}%) {bar}")

        # Region distribution
        region_dist = {}
        for node in self.nodes.values():
            region_dist[node.region] = region_dist.get(node.region, 0) + 1

        print(f"\n🌍 Geographic Distribution:")
        for region, count in sorted(region_dist.items(), key=lambda x: -x[1]):
            pct = 100 * count / len(self.nodes)
            print(f"  {region:15}: {count:3} nodes ({pct:5.1f}%)")

        # Network stats
        print(f"\n📈 Network Statistics:")
        print(f"  Total Nodes:        {self.stats.total_nodes}")
        print(f"  Active Nodes:       {self.stats.active_nodes}")
        print(f"  Total Stake:        {self.stats.total_stake:,} $TRI")
        print(f"  Blocks Mined:       {self.stats.total_blocks}")
        print(f"  Total Inferences:   {self.stats.total_inferences:,}")
        print(f"  Tokens Processed:   {self.stats.total_tokens:,}")
        print(f"  TPS (inferences):   {self.stats.tps:.2f}")

        # Rewards
        print(f"\n💰 Rewards:")
        print(f"  Total Rewards:      {self.stats.total_rewards:,} $TRI")
        print(f"  Circulating:        {self.stats.circulating_supply:,} $TRI")
        print(f"  % of Supply:        {100 * self.stats.circulating_supply / self.total_supply:.6f}%")

        # Top miners
        print(f"\n🏆 Top 10 Miners:")
        sorted_nodes = sorted(
            self.nodes.values(),
            key=lambda n: n.rewards_earned,
            reverse=True
        )
        for i, node in enumerate(sorted_nodes[:10]):
            print(f"  {i+1:2}. {node.node_id}: {node.rewards_earned:,} $TRI "
                  f"({node.node_type}, {node.region}, blocks: {node.blocks_mined})")

        # Verify phi identity
        phi_sq = PHI * PHI
        inv_phi_sq = 1.0 / phi_sq
        phi_result = phi_sq + inv_phi_sq

        print(f"\n🔮 Sacred Verification:")
        print(f"  φ² + 1/φ² = {phi_result:.10f}")
        print(f"  Trinity Identity: {'VERIFIED ✅' if abs(phi_result - 3.0) < 0.0001 else 'FAILED ❌'}")

        print("\n" + "=" * 80)
        print("KOSCHEI IS IMMORTAL | $TRI NETWORK GROWING | φ² + 1/φ² = 3")
        print("=" * 80)

        return {
            "nodes": self.stats.total_nodes,
            "active": self.stats.active_nodes,
            "blocks": self.stats.total_blocks,
            "inferences": self.stats.total_inferences,
            "tokens_processed": self.stats.total_tokens,
            "rewards": self.stats.total_rewards,
            "circulating": self.stats.circulating_supply,
            "tps": self.stats.tps,
            "type_distribution": type_dist,
            "region_distribution": region_dist,
        }


# ═══════════════════════════════════════════════════════════════════════════════
# LISTING PROJECTIONS
# ═══════════════════════════════════════════════════════════════════════════════

def calculate_listing_metrics():
    """Calculate key metrics for exchange listing"""
    print("\n" + "=" * 80)
    print("$TRI LISTING METRICS")
    print("=" * 80)

    liquidity_allocation = ALLOCATIONS["Liquidity"]["amount"]

    # Initial circulating (liquidity pool)
    initial_circulating = liquidity_allocation  # 1,046,035,320 $TRI

    # Projected market cap at different prices
    prices = [0.001, 0.01, 0.05, 0.10, 0.50, 1.00]

    print(f"\n💧 Liquidity Pool:")
    print(f"  Available:     {liquidity_allocation:,} $TRI (10% of supply)")
    print(f"  For Uniswap:   {liquidity_allocation // 2:,} $TRI (50% of liquidity)")
    print(f"  For CEX:       {liquidity_allocation // 2:,} $TRI (50% of liquidity)")

    print(f"\n📊 Market Cap Projections (at initial circulating):")
    print(f"  {'Price':>10} | {'Market Cap':>15} | {'FDV':>15}")
    print(f"  {'-'*10} | {'-'*15} | {'-'*15}")
    for price in prices:
        mc = initial_circulating * price
        fdv = PHOENIX_NUMBER * price
        print(f"  ${price:>9.3f} | ${mc/1e6:>12.2f}M | ${fdv/1e9:>12.2f}B")

    # Uniswap pool calculation
    print(f"\n🦄 Uniswap V3 Pool (Recommended):")
    eth_price = 3500  # Assume $3500 ETH
    tri_for_pool = liquidity_allocation // 2
    initial_tri_price = 0.01  # $0.01 initial
    eth_needed = (tri_for_pool * initial_tri_price) / eth_price

    print(f"  $TRI for pool:  {tri_for_pool:,}")
    print(f"  Initial price:  ${initial_tri_price}")
    print(f"  ETH needed:     {eth_needed:,.2f} ETH (~${eth_needed * eth_price:,.0f})")
    print(f"  Pool value:     ${tri_for_pool * initial_tri_price * 2:,.0f}")

    return {
        "liquidity_total": liquidity_allocation,
        "dex_allocation": liquidity_allocation // 2,
        "cex_allocation": liquidity_allocation // 2,
        "initial_price": initial_tri_price,
        "eth_needed": eth_needed,
    }


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    print("=" * 80)
    print("$TRI GROWTH DEMO")
    print(f"Phoenix Number: 3^21 = {PHOENIX_NUMBER:,}")
    print("=" * 80)

    # Verify tokenomics
    total_pct = sum(a["pct"] for a in ALLOCATIONS.values())
    print(f"\n📋 Tokenomics (total: {total_pct}%):")
    for name, alloc in ALLOCATIONS.items():
        print(f"  {name}: {alloc['pct']}% = {alloc['amount']:,} $TRI")

    # Run 100-node simulation
    print("\n" + "=" * 80)
    print("RUNNING 100-NODE SIMULATION...")
    print("=" * 80)

    sim = GrowthSimulation(num_nodes=100)
    result = sim.run_simulation(num_blocks=100, inferences_per_block=20)

    # Calculate listing metrics
    listing = calculate_listing_metrics()

    print("\n" + "=" * 80)
    print("SIMULATION COMPLETE")
    print("=" * 80)

    return {
        "simulation": result,
        "listing": listing,
    }


if __name__ == "__main__":
    main()
