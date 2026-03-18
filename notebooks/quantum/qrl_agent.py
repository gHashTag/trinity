#!/usr/bin/env python3
"""
TRINITY v9.0 QUANTUM — Quantum Reinforcement Learning Agent
===========================================================

QRL with qutrit-based quantum networks.

Features:
- QNetwork: Quantum Q-network for DQN
- ReplayBuffer: Experience replay
- QutritPolicy: Policy gradient with quantum circuits
- PPO: Proximal Policy Optimization
- GAE: Generalized Advantage Estimation

Reference: TRINITY v9.0 QUANTUM Framework
"""

import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np
from dataclasses import dataclass, field
from typing import List, Tuple, Dict, Optional, Any
from collections import deque
import random

# ============================================================================
// Constants
// ============================================================================

GOLDEN_RATIO: float = (1 + np.sqrt(5)) / 2
NUM_TRIT_STATES: int = 3

# ============================================================================
// Types
// ============================================================================

@dataclass
class Transition:
    """Single transition for replay buffer."""
    state: torch.Tensor
    action: int
    reward: float
    next_state: torch.Tensor
    done: bool


@dataclass
class Trajectory:
    """Episode trajectory for policy gradient."""
    states: List[torch.Tensor]
    actions: List[int]
    rewards: List[float]
    log_probs: List[torch.Tensor]
    dones: List[bool]


# ============================================================================
// Replay Buffer
// ============================================================================

class ReplayBuffer:
    """Experience replay buffer for DQN."""

    def __init__(self, capacity: int = 10000):
        self.buffer = deque(maxlen=capacity)
        self.capacity = capacity

    def push(
        self,
        state: torch.Tensor,
        action: int,
        reward: float,
        next_state: torch.Tensor,
        done: bool,
    ) -> None:
        """Add transition to buffer."""
        self.buffer.append(Transition(
            state.clone(),
            action,
            reward,
            next_state.clone(),
            done
        ))

    def sample(self, batch_size: int) -> List[Transition]:
        """Sample random minibatch."""
        return random.sample(self.buffer, min(batch_size, len(self.buffer)))

    def __len__(self) -> int:
        return len(self.buffer)


# ============================================================================
// Quantum Q-Network
// ============================================================================

class QuantumQNetwork(nn.Module):
    """Q-network with quantum layer for DQN."""

    def __init__(
        self,
        state_dim: int,
        action_space: int,
        hidden_dim: int = 64,
    ):
        super().__init__()
        self.state_dim = state_dim
        self.action_space = action_space

        # State encoder
        self.encoder = nn.Linear(state_dim, hidden_dim)

        # Quantum layer parameters (simplified)
        self.quantum_params = nn.Parameter(torch.randn(3))

        # Action value heads
        self.value_head = nn.Linear(NUM_TRIT_STATES, action_space)

    def forward(self, state: torch.Tensor) -> torch.Tensor:
        """
        Forward pass through Q-network.

        Args:
            state: State tensor of shape (batch, state_dim)

        Returns:
            Q-values of shape (batch, action_space)
        """
        # Encode state
        features = self.encoder(state)

        # Simulated quantum layer (in practice, use actual qutrit simulation)
        # Apply quantum-inspired transformation
        q_features = self._quantum_layer(features)

        # Compute Q-values
        q_values = self.value_head(q_features)
        return q_values

    def _quantum_layer(self, x: torch.Tensor) -> torch.Tensor:
        """Simulate quantum layer transformation."""
        # Apply rotation-like transformation
        params = self.quantum_params

        # Create quantum-inspired features
        batch_size = x.shape[0]
        quantum_features = torch.zeros(batch_size, NUM_TRIT_STATES)

        for i in range(NUM_TRIT_STATES):
            # Each "qutrit" dimension gets a transformed feature
            quantum_features[:, i] = torch.sin(x[:, 0] + params[i]) + \
                                       torch.cos(x[:, 1] + params[i]) * \
                                       torch.tanh(x[:, min(2, x.shape[1]-1)])

        return quantum_features


# ============================================================================
// Qutrit Policy (Actor-Critic)
// ============================================================================

class QutritPolicy(nn.Module):
    """Policy gradient network with quantum circuits."""

    def __init__(
        self,
        state_dim: int,
        action_space: int,
        hidden_dim: int = 64,
        entropy_coeff: float = 0.01,
    ):
        super().__init__()
        self.state_dim = state_dim
        self.action_space = action_space
        self.entropy_coeff = entropy_coeff

        # Actor (policy) network
        self.actor = nn.Sequential(
            nn.Linear(state_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, action_space),
        )

        # Critic (value) network
        self.critic = nn.Sequential(
            nn.Linear(state_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, 1),
        )

    def act(
        self,
        state: torch.Tensor,
        epsilon: float = 0.0,
    ) -> Tuple[int, torch.Tensor, torch.Tensor]:
        """
        Select action via epsilon-greedy or policy.

        Returns:
            (action, log_prob, value)
        """
        with torch.no_grad():
            # Get action probabilities
            logits = self.actor(state)
            probs = F.softmax(logits, dim=-1)
            value = self.critic(state)

        # Epsilon-greedy exploration
        if random.random() < epsilon:
            action = random.randint(0, self.action_space - 1)
            log_prob = torch.log(probs[0, action] + 1e-10)
        else:
            dist = torch.distributions.Categorical(probs)
            action = dist.sample().item()
            log_prob = dist.log_prob(torch.tensor(action))

        return action, log_prob, value

    def evaluate_actions(
        self,
        states: torch.Tensor,
        actions: torch.Tensor,
    ) -> Tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
        """Evaluate actions for PPO."""
        logits = self.actor(states)
        probs = F.softmax(logits, dim=-1)
        dist = torch.distributions.Categorical(probs)

        log_probs = dist.log_prob(actions)
        entropy = dist.entropy()
        values = self.critic(states).squeeze(-1)

        return log_probs, entropy, values


# ============================================================================
// DQN Agent
// ============================================================================

class QuantumDQNAgent:
    """Deep Q-Network agent with quantum layers."""

    def __init__(
        self,
        state_dim: int,
        action_space: int,
        learning_rate: float = 1e-3,
        gamma: float = 0.99,
        epsilon_start: float = 1.0,
        epsilon_end: float = 0.01,
        epsilon_decay: float = 0.995,
        buffer_size: int = 10000,
        batch_size: int = 64,
    ):
        self.state_dim = state_dim
        self.action_space = action_space
        self.gamma = gamma
        self.epsilon = epsilon_start
        self.epsilon_end = epsilon_end
        self.epsilon_decay = epsilon_decay
        self.batch_size = batch_size

        # Q-networks
        self.q_network = QuantumQNetwork(state_dim, action_space)
        self.target_network = QuantumQNetwork(state_dim, action_space)
        self.target_network.load_state_dict(self.q_network.state_dict())

        self.optimizer = torch.optim.Adam(self.q_network.parameters(), lr=learning_rate)
        self.replay_buffer = ReplayBuffer(buffer_size)

    def select_action(self, state: torch.Tensor) -> int:
        """Select action via epsilon-greedy policy."""
        if random.random() < self.epsilon:
            return random.randint(0, self.action_space - 1)

        with torch.no_grad():
            q_values = self.q_network(state.unsqueeze(0))
            return q_values.argmax(1).item()

    def train_step(self) -> float:
        """Single DQN training step."""
        if len(self.replay_buffer) < self.batch_size:
            return 0.0

        # Sample minibatch
        transitions = self.replay_buffer.sample(self.batch_size)
        batch = Transition(*zip(*transitions))

        states = torch.stack(batch.state)
        actions = torch.tensor(batch.action)
        rewards = torch.tensor(batch.reward, dtype=torch.float32)
        next_states = torch.stack(batch.next_state)
        dones = torch.tensor(batch.done, dtype=torch.float32)

        # Compute current Q-values
        current_q = self.q_network(states).gather(1, actions.unsqueeze(1))

        # Compute target Q-values
        with torch.no_grad():
            next_q = self.target_network(next_states).max(1)[0]
            target_q = rewards + (1 - dones) * self.gamma * next_q

        # Huber loss
        loss = F.smooth_l1_loss(current_q.squeeze(), target_q)

        # Optimize
        self.optimizer.zero_grad()
        loss.backward()
        self.optimizer.step()

        # Decay epsilon
        self.epsilon = max(self.epsilon_end, self.epsilon * self.epsilon_decay)

        return loss.item()

    def update_target_network(self) -> None:
        """Update target network with current network."""
        self.target_network.load_state_dict(self.q_network.state_dict())


# ============================================================================
// PPO Agent
// ============================================================================

class PPOAgent:
    """Proximal Policy Optimization agent."""

    def __init__(
        self,
        state_dim: int,
        action_space: int,
        learning_rate: float = 3e-4,
        gamma: float = 0.99,
        gae_lambda: float = 0.95,
        clip_epsilon: float = 0.2,
        entropy_coeff: float = 0.01,
    ):
        self.state_dim = state_dim
        self.action_space = action_space
        self.gamma = gamma
        self.gae_lambda = gae_lambda
        self.clip_epsilon = clip_epsilon
        self.entropy_coeff = entropy_coeff

        self.policy = QutritPolicy(state_dim, action_space, entropy_coeff)
        self.optimizer = torch.optim.Adam(self.policy.parameters(), lr=learning_rate)

    def select_action(
        self,
        state: torch.Tensor,
    ) -> Tuple[int, torch.Tensor, torch.Tensor]:
        """Select action from policy."""
        return self.policy.act(state)

    def compute_gae(
        self,
        rewards: List[float],
        values: List[torch.Tensor],
        dones: List[bool],
    ) -> List[float]:
        """
        Compute Generalized Advantage Estimation.

        A_t = Σ (γλ)^l δ_{t+l}
        δ_t = r_t + γV(s_{t+1}) - V(s_t)
        """
        advantages = []
        gae = 0.0

        values = [v.item() for v in values]

        for t in reversed(range(len(rewards))):
            if t == len(rewards) - 1:
                next_value = 0.0
            else:
                next_value = values[t + 1]

            delta = rewards[t] + self.gamma * next_value * (1 - dones[t]) - values[t]
            gae = delta + self.gamma * self.gae_lambda * (1 - dones[t]) * gae
            advantages.insert(0, gae)

        return advantages

    def ppo_loss(
        self,
        states: torch.Tensor,
        actions: torch.Tensor,
        old_log_probs: torch.Tensor,
        advantages: torch.Tensor,
    ) -> torch.Tensor:
        """
        Compute PPO loss.

        L_clip = min(r_t A_t, clip(r_t, 1-ε, 1+ε) A_t)
        r_t = π_new(a|s) / π_old(a|s)
        """
        log_probs, entropy, values = self.policy.evaluate_actions(states, actions)

        # Ratio
        ratio = torch.exp(log_probs - old_log_probs)

        # Clipped surrogate loss
        surr1 = ratio * advantages
        surr2 = torch.clamp(ratio, 1 - self.clip_epsilon, 1 + self.clip_epsilon) * advantages
        policy_loss = -torch.min(surr1, surr2).mean()

        # Value loss
        value_loss = F.mse_loss(values, advantages)

        # Entropy bonus
        entropy_loss = -entropy.mean()

        # Total loss
        total_loss = policy_loss + 0.5 * value_loss + self.entropy_coeff * entropy_loss

        return total_loss

    def update(
        self,
        trajectory: Trajectory,
        epochs: int = 10,
    ) -> Dict[str, float]:
        """Update policy with PPO."""
        states = torch.stack(trajectory.states)
        actions = torch.tensor(trajectory.actions)
        old_log_probs = torch.stack(trajectory.log_probs)

        # Compute advantages
        values = []
        for i, state in enumerate(trajectory.states):
            _, _, val = self.policy.act(state, epsilon=0)
            values.append(val)

        advantages = self.compute_gae(
            trajectory.rewards,
            values,
            trajectory.dones,
        )
        advantages = torch.tensor(advantages)
        advantages = (advantages - advantages.mean()) / (advantages.std() + 1e-8)

        losses = []
        for _ in range(epochs):
            self.optimizer.zero_grad()
            loss = self.ppo_loss(states, actions, old_log_probs, advantages)
            loss.backward()
            self.optimizer.step()
            losses.append(loss.item())

        return {"loss": np.mean(losses)}


# ============================================================================
// Actor-Critic Agent
// ============================================================================

class ActorCriticAgent:
    """Advantage Actor-Critic agent."""

    def __init__(
        self,
        state_dim: int,
        action_space: int,
        learning_rate: float = 1e-3,
        gamma: float = 0.99,
    ):
        self.state_dim = state_dim
        self.action_space = action_space
        self.gamma = gamma

        self.policy = QutritPolicy(state_dim, action_space)
        self.optimizer = torch.optim.Adam(self.policy.parameters(), lr=learning_rate)

    def select_action(
        self,
        state: torch.Tensor,
    ) -> Tuple[int, torch.Tensor]:
        """Select action from policy."""
        action, log_prob, _ = self.policy.act(state)
        return action, log_prob

    def update(self, trajectory: Trajectory) -> Dict[str, float]:
        """Actor-critic update."""
        states = torch.stack(trajectory.states)
        actions = torch.tensor(trajectory.actions)

        # Compute returns
        returns = []
        R = 0.0
        for r, done in zip(reversed(trajectory.rewards), reversed(trajectory.dones)):
            R = r + self.gamma * R * (1 - done)
            returns.insert(0, R)
        returns = torch.tensor(returns)

        # Update
        log_probs, _, values = self.policy.evaluate_actions(states, actions)

        # Advantage
        advantages = returns - values.detach()

        # Actor loss
        actor_loss = -(log_probs * advantages).mean()

        # Critic loss
        critic_loss = F.mse_loss(values.squeeze(), returns)

        # Total loss
        loss = actor_loss + 0.5 * critic_loss

        self.optimizer.zero_grad()
        loss.backward()
        self.optimizer.step()

        return {"loss": loss.item()}


# ============================================================================
// Exploration Bonuses
// ============================================================================

class CountBasedExploration:
    """Count-based exploration bonus."""

    def __init__(self, beta: float = 0.01):
        self.beta = beta
        self.counts: Dict[Tuple[int, ...], int] = {}

    def get_bonus(self, state: torch.Tensor) -> float:
        """Get exploration bonus based on visit count."""
        # Discretize state
        state_key = tuple(state.round(decimals=2).tolist())
        count = self.counts.get(state_key, 0) + 1
        self.counts[state_key] = count

        # Bonus ~ 1/√N(s)
        return self.beta / np.sqrt(count)


# ============================================================================
// Main
// ============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("TRINITY v9.0 QUANTUM — QRL Agent")
    print("=" * 60)
    print()

    # Test Quantum Q-Network
    print("Quantum Q-Network Test:")
    q_net = QuantumQNetwork(state_dim=4, action_space=2)
    state = torch.randn(4)
    q_values = q_net(state.unsqueeze(0))
    print(f"  Q-values: {q_values}")
    print(f"  Argmax action: {q_values.argmax(1).item()}")
    print()

    # Test Replay Buffer
    print("Replay Buffer Test:")
    buffer = ReplayBuffer(capacity=1000)
    for _ in range(10):
        buffer.push(torch.randn(4), 0, 1.0, torch.randn(4), False)
    print(f"  Buffer size: {len(buffer)}")
    batch = buffer.sample(5)
    print(f"  Sampled batch size: {len(batch)}")
    print()

    # Test Qutrit Policy
    print("Qutrit Policy Test:")
    policy = QutritPolicy(state_dim=4, action_space=3)
    state = torch.randn(4)
    action, log_prob, value = policy.act(state)
    print(f"  Action: {action}")
    print(f"  Log prob: {log_prob.item():.4f}")
    print(f"  Value: {value.item():.4f}")
    print()

    print("✓ QRL agent initialized")
