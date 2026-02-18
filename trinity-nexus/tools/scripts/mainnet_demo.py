#!/usr/bin/env python3
"""
$TRI Mainnet Demo - 10 Node Simulation
Supply: 3^21 = 10,460,353,203 $TRI (Phoenix Number)
φ² + 1/φ² = 3 | KOSCHEI IS IMMORTAL
"""

import random
import time
import hashlib
from dataclasses import dataclass, field
from typing import List, Dict
from datetime import datetime

# ═══════════════════════════════════════════════════════════════════════════════
# SACRED CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

PHI = 1.618033988749895
PHOENIX_NUMBER = 3 ** 21  # 10,460,353,203
BLOCK_TIME = 3  # seconds
INITIAL_BLOCK_REWARD = 100
HALVING_BLOCKS = 21_024_000  # ~2 years

# ═══════════════════════════════════════════════════════════════════════════════
# TOKENOMICS
# ═══════════════════════════════════════════════════════════════════════════════

ALLOCATIONS = {
    "Founder & Team": {"pct": 20, "vesting": 48, "cliff": 12},
    "Node Rewards": {"pct": 40, "vesting": 120, "cliff": 0},
    "Community": {"pct": 20, "vesting": 36, "cliff": 0},
    "Treasury": {"pct": 10, "vesting": 60, "cliff": 6},
    "Liquidity": {"pct": 10, "vesting": 0, "cliff": 0},
}

# ═══════════════════════════════════════════════════════════════════════════════
# DATA STRUCTURES
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class Node:
    node_id: str
    stake: int
    balance: int = 0
    blocks_mined: int = 0
    inferences: int = 0
    tokens_processed: int = 0
    rewards_earned: int = 0
    joined_at: float = field(default_factory=time.time)
    last_active: float = field(default_factory=time.time)

    def effective_stake(self) -> int:
        """Stake weight with activity bonus"""
        activity_bonus = min(self.inferences // 10, 100)
        return self.stake * (100 + activity_bonus) // 100

@dataclass
class Block:
    height: int
    prev_hash: str
    miner: str
    timestamp: float
    transactions: List[Dict]
    reward: int

    def hash(self) -> str:
        data = f"{self.height}{self.prev_hash}{self.miner}{self.timestamp}"
        return hashlib.sha256(data.encode()).hexdigest()[:16]

# ═══════════════════════════════════════════════════════════════════════════════
# MAINNET SIMULATION
# ═══════════════════════════════════════════════════════════════════════════════

class MainnetSimulation:
    def __init__(self, num_nodes: int = 10):
        self.nodes: Dict[str, Node] = {}
        self.blocks: List[Block] = []
        self.total_supply = PHOENIX_NUMBER
        self.circulating_supply = 0

        # Create genesis block
        self._create_genesis()

        # Initialize nodes
        for i in range(num_nodes):
            node_id = f"node_{i:02d}"
            stake = random.randint(100, 10000)
            self.nodes[node_id] = Node(node_id=node_id, stake=stake)

    def _create_genesis(self):
        """Create genesis block"""
        genesis = Block(
            height=0,
            prev_hash="0" * 16,
            miner="genesis",
            timestamp=time.time(),
            transactions=[],
            reward=0
        )
        self.blocks.append(genesis)
        print(f"Genesis block created: {genesis.hash()}")

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

        block = Block(
            height=height,
            prev_hash=prev_hash,
            miner=miner_id,
            timestamp=time.time(),
            transactions=[],
            reward=reward
        )

        # Update miner stats
        miner.blocks_mined += 1
        miner.balance += reward
        miner.rewards_earned += reward
        miner.last_active = time.time()
        self.circulating_supply += reward

        self.blocks.append(block)
        return block

    def simulate_inference(self, node_id: str, tokens: int = 1000) -> int:
        """Simulate inference and reward"""
        if node_id not in self.nodes:
            return 0

        node = self.nodes[node_id]
        coherent = random.random() > 0.1  # 90% coherent

        reward = self.calculate_inference_reward(tokens, coherent)

        node.inferences += 1
        node.tokens_processed += tokens
        node.balance += reward
        node.rewards_earned += reward
        node.last_active = time.time()
        self.circulating_supply += reward

        return reward

    def run_simulation(self, num_blocks: int = 10, inferences_per_block: int = 5):
        """Run mainnet simulation"""
        print("\n" + "=" * 70)
        print("$TRI MAINNET SIMULATION")
        print(f"Supply: 3^21 = {PHOENIX_NUMBER:,} $TRI")
        print("=" * 70)

        print(f"\nNodes: {len(self.nodes)}")
        print(f"Initial blocks: {len(self.blocks)}")

        for i in range(num_blocks):
            # Mine block
            block = self.mine_block()
            print(f"\n[Block {block.height}] Miner: {block.miner} | Reward: {block.reward} $TRI")

            # Simulate inferences
            for _ in range(inferences_per_block):
                node_id = random.choice(list(self.nodes.keys()))
                tokens = random.randint(500, 5000)
                reward = self.simulate_inference(node_id, tokens)
                if reward > 0:
                    print(f"  Inference: {node_id} | {tokens} tokens | +{reward} $TRI")

            time.sleep(0.1)  # Simulate block time

        self._print_summary()

    def _print_summary(self):
        """Print simulation summary"""
        print("\n" + "=" * 70)
        print("MAINNET SIMULATION SUMMARY")
        print("=" * 70)

        print(f"\nChain Stats:")
        print(f"  Blocks: {len(self.blocks)}")
        print(f"  Total supply: {self.total_supply:,} $TRI")
        print(f"  Circulating: {self.circulating_supply:,} $TRI")
        print(f"  Inflation: {100 * self.circulating_supply / self.total_supply:.6f}%")

        print(f"\nNode Leaderboard:")
        sorted_nodes = sorted(
            self.nodes.values(),
            key=lambda n: n.rewards_earned,
            reverse=True
        )
        for i, node in enumerate(sorted_nodes[:5]):
            print(f"  {i+1}. {node.node_id}: {node.rewards_earned} $TRI "
                  f"(blocks: {node.blocks_mined}, inferences: {node.inferences})")

        total_rewards = sum(n.rewards_earned for n in self.nodes.values())
        total_inferences = sum(n.inferences for n in self.nodes.values())
        total_tokens = sum(n.tokens_processed for n in self.nodes.values())

        print(f"\nAggregate Stats:")
        print(f"  Total rewards: {total_rewards} $TRI")
        print(f"  Total inferences: {total_inferences}")
        print(f"  Total tokens processed: {total_tokens:,}")
        print(f"  Avg reward per inference: {total_rewards / total_inferences:.2f} $TRI" if total_inferences > 0 else "")

        # Verify phi identity
        phi_sq = PHI * PHI
        inv_phi_sq = 1.0 / phi_sq
        phi_result = phi_sq + inv_phi_sq
        print(f"\nφ² + 1/φ² = {phi_result:.10f}")
        print(f"Trinity identity verified: {abs(phi_result - 3.0) < 0.0001}")

        print("\n" + "=" * 70)
        print("KOSCHEI IS IMMORTAL | $TRI MAINNET LIVE | φ² + 1/φ² = 3")
        print("=" * 70)

        return {
            "blocks": len(self.blocks),
            "circulating": self.circulating_supply,
            "total_rewards": total_rewards,
            "total_inferences": total_inferences,
            "nodes": len(self.nodes)
        }


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    print("=" * 70)
    print("$TRI MAINNET DEMO")
    print(f"Phoenix Number: 3^21 = {PHOENIX_NUMBER:,}")
    print("=" * 70)

    # Verify tokenomics
    total_pct = sum(a["pct"] for a in ALLOCATIONS.values())
    print(f"\nTokenomics (total: {total_pct}%):")
    for name, alloc in ALLOCATIONS.items():
        amount = PHOENIX_NUMBER * alloc["pct"] // 100
        print(f"  {name}: {alloc['pct']}% = {amount:,} $TRI")

    # Run simulation
    sim = MainnetSimulation(num_nodes=10)
    result = sim.run_simulation(num_blocks=10, inferences_per_block=5)

    return result


if __name__ == "__main__":
    main()
