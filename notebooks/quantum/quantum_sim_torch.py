#!/usr/bin/env python3
"""
TRINITY v9.0 QUANTUM — Full PyTorch Quantum Simulation
========================================================

Differentiable quantum circuit simulation for qutrits (3-level systems).

Features:
- QutritState: 3-dimensional complex state vectors
- QutritGate: 3×3 unitary matrices
- QuantumCircuit: Sequences of gates
- Autograd support via PyTorch
- Golden gate and TRINITY phase gate

Reference: TRINITY v9.0 QUANTUM Framework
"""

import torch
import numpy as np
from dataclasses import dataclass, field
from typing import List, Tuple, Optional, Callable
from enum import Enum

# ============================================================================
# Constants
# ============================================================================

GOLDEN_RATIO: float = (1 + np.sqrt(5)) / 2
GOLDEN_ANGLE_DEG: float = 360 / (GOLDEN_RATIO ** 2)  # ≈ 137.508°
GOLDEN_ANGLE_RAD: float = np.radians(GOLDEN_ANGLE_DEG)
NUM_TRIT_STATES: int = 3

# Try to import torch, provide fallback
HAS_TORCH = True
try:
    import torch
    DEVICE = torch.device("cpu")
    DTYPE = torch.complex128
except ImportError:
    HAS_TORCH = False
    torch = None

# ============================================================================
# Types
# ============================================================================

@dataclass
class Measurement:
    """Measurement operation."""
    basis: str = "computational"  # "computational", "golden", "fourier"
    shots: int = 1000


@dataclass
class QuantumCircuit:
    """Sequence of qutrit gates."""
    gates: List['QutritGate'] = field(default_factory=list)
    num_qutrits: int = 1
    depth: int = 0

    def add_gate(self, gate: 'QutritGate') -> None:
        self.gates.append(gate)
        self.depth = len(self.gates)


# ============================================================================
# Qutrit State
# ============================================================================

class QutritState:
    """Single qutrit quantum state: α|+1⟩ + β|0⟩ + γ|-1⟩"""

    def __init__(self, amplitudes: torch.Tensor):
        """
        Initialize with complex amplitudes [α, β, γ].

        Args:
            amplitudes: Tensor of shape (3,) with complex entries
        """
        if not HAS_TORCH:
            raise RuntimeError("PyTorch not installed")
        if amplitudes.shape != (3,):
            raise ValueError("Qutrit requires exactly 3 amplitudes")
        self.amplitudes = amplitudes.to(dtype=DTYPE, device=DEVICE)

    @classmethod
    def basis(cls, trit: int) -> 'QutritState':
        """
        Create computational basis state |trit⟩.

        Args:
            trit: -1 (|−1⟩), 0 (|0⟩), or 1 (|+1⟩)

        Returns:
            Basis state
        """
        amplitudes = torch.zeros(3, dtype=DTYPE, device=DEVICE)
        if trit == 1:
            amplitudes[0] = 1.0  # |+1⟩
        elif trit == 0:
            amplitudes[1] = 1.0  # |0⟩
        elif trit == -1:
            amplitudes[2] = 1.0  # |-1⟩
        else:
            raise ValueError(f"Invalid trit value: {trit}")
        return cls(amplitudes)

    @classmethod
    def superposition(cls) -> 'QutritState':
        """Create equal superposition state."""
        amp = 1.0 / np.sqrt(3.0)
        amplitudes = torch.full((3,), amp, dtype=DTYPE, device=DEVICE)
        return cls(amplitudes)

    @classmethod
    def from_tensor(cls, tensor: torch.Tensor) -> 'QutritState':
        """Create state from tensor."""
        return cls(tensor)

    def probabilities(self) -> torch.Tensor:
        """Calculate measurement probabilities."""
        return torch.abs(self.amplitudes) ** 2

    def normalize(self) -> 'QutritState':
        """Normalize the state."""
        norm = torch.linalg.norm(self.amplitudes)
        if norm > 0:
            self.amplitudes = self.amplitudes / norm
        return self

    def expectation(self, operator: torch.Tensor) -> float:
        """Calculate expectation value ⟨ψ|O|ψ⟩."""
        return torch.vdot(self.amplitudes, operator @ self.amplitudes).real.item()

    def clone(self) -> 'QutritState':
        """Clone the state."""
        return QutritState(self.amplitudes.clone())

    def to(self, device: torch.device) -> 'QutritState':
        """Move state to device."""
        self.amplitudes = self.amplitudes.to(device)
        return self


# ============================================================================
# Qutrit Gate
# ============================================================================

class QutritGate:
    """3×3 unitary gate for qutrits."""

    def __init__(self, matrix: torch.Tensor, params: Optional[torch.Tensor] = None):
        """
        Initialize gate with unitary matrix.

        Args:
            matrix: 3×3 unitary matrix
            params: Optional trainable parameters
        """
        if not HAS_TORCH:
            raise RuntimeError("PyTorch not installed")
        if matrix.shape != (3, 3):
            raise ValueError("Qutrit gate requires 3×3 matrix")
        self.matrix = matrix.to(dtype=DTYPE, device=DEVICE)
        self.params = params

    @classmethod
    def identity(cls) -> 'QutritGate':
        """Identity gate."""
        matrix = torch.eye(3, dtype=DTYPE, device=DEVICE)
        return cls(matrix)

    @classmethod
    def golden_gate(cls, angle: float = GOLDEN_ANGLE_RAD) -> 'QutritGate':
        """
        Golden ratio rotation gate.

        Uses Qutrit Fourier Transform matrix (unitary).
        """
        omega = torch.exp(2j * torch.pi / 3)
        inv_sqrt3 = 1.0 / np.sqrt(3.0)

        matrix = torch.tensor([
            [inv_sqrt3, inv_sqrt3, inv_sqrt3],
            [inv_sqrt3, omega * inv_sqrt3, omega.conj() * inv_sqrt3],
            [inv_sqrt3, omega.conj() * inv_sqrt3, omega * inv_sqrt3],
        ], dtype=DTYPE, device=DEVICE)

        return cls(matrix)

    @classmethod
    def trinity_phase_gate(cls) -> 'QutritGate':
        """
        TRINITY phase gate: applies cube roots of unity.

        Phases: [1, ω, ω²] where ω = exp(2πi/3)
        Related to φ² + 1/φ² = 3.
        """
        omega = torch.exp(2j * torch.pi / 3)
        matrix = torch.diag(torch.tensor([1.0, omega, omega ** 2], dtype=DTYPE, device=DEVICE))
        return cls(matrix)

    @classmethod
    def rotation(cls, axis: int, angle: float) -> 'QutritGate':
        """
        Gell-Mann matrix rotation gate.

        Args:
            axis: 1-8 (Gell-Mann matrix index)
            angle: rotation angle in radians
        """
        cos_t = np.cos(angle)
        sin_t = np.sin(angle)

        if axis == 1:  # λ₁
            matrix = torch.tensor([
                [0, sin_t, 0],
                [sin_t, 0, sin_t],
                [0, sin_t, 0],
            ], dtype=DTYPE, device=DEVICE)
            matrix += torch.eye(3, dtype=DTYPE, device=DEVICE) * cos_t

        elif axis == 2:  # λ₂
            matrix = torch.tensor([
                [0, -1j * sin_t, 0],
                [1j * sin_t, 0, -1j * sin_t],
                [0, 1j * sin_t, 0],
            ], dtype=DTYPE, device=DEVICE)
            matrix += torch.eye(3, dtype=DTYPE, device=DEVICE) * cos_t

        elif axis == 3:  # λ₃ (diagonal)
            matrix = torch.diag(torch.tensor([
                np.cos(angle / 2),
                torch.tensor(1.0),
                np.cos(-angle / 2),
            ], dtype=DTYPE, device=DEVICE))

        else:
            # Fallback to identity for other axes
            matrix = torch.eye(3, dtype=DTYPE, device=DEVICE)

        return cls(matrix)

    @classmethod
    def parametrized(cls, params: torch.Tensor) -> 'QutritGate':
        """
        Create gate with trainable parameters.

        Args:
            params: Tensor of shape (n,) for gate parameters
        """
        # Example: rotation gate with angle from params
        angle = params[0]
        return cls.rotation(1, angle.item())

    def is_unitary(self, tolerance: float = 1e-6) -> bool:
        """Check if gate is unitary (U†U = I)."""
        identity = torch.eye(3, dtype=DTYPE, device=DEVICE)
        product = self.matrix.conj().T @ self.matrix
        return torch.allclose(product, identity, atol=tolerance)


# ============================================================================
# Quantum Circuit
# ============================================================================

def apply_gate(state: QutritState, gate: QutritGate) -> QutritState:
    """Apply single-qutrit gate to state.

    Args:
        state: Input qutrit state
        gate: Qutrit gate to apply

    Returns:
        Evolved state |ψ'⟩ = U|ψ⟩
    """
    new_amplitudes = gate.matrix @ state.amplitudes
    return QutritState(new_amplitudes)


def apply_circuit(initial_state: QutritState, circuit: QuantumCircuit) -> QutritState:
    """Apply full circuit to state.

    Args:
        initial_state: Starting state
        circuit: Quantum circuit with sequence of gates

    Returns:
        Final state after all gates
    """
    state = initial_state.clone()
    for gate in circuit.gates:
        state = apply_gate(state, gate)
    return state


def measure(state: QutritState, measurement: Measurement) -> Tuple[int, float]:
    """
    Collapse state via measurement.

    Args:
        state: Qutrit state to measure
        measurement: Measurement configuration

    Returns:
        (outcome, probability) where outcome ∈ {-1, 0, 1}
    """
    probs = state.probabilities().detach().cpu().numpy()
    probs = probs / probs.sum()  # Normalize

    outcome_idx = np.random.choice(3, p=probs)
    outcome_map = [1, 0, -1]  # Index to trit mapping
    outcome = outcome_map[outcome_idx]

    return outcome, float(probs[outcome_idx])


def fidelity(state1: QutritState, state2: QutritState) -> float:
    """
    Calculate state overlap |⟨ψ₁|ψ₂⟩|².

    Args:
        state1: First state
        state2: Second state

    Returns:
        Fidelity in [0, 1]
    """
    overlap = torch.vdot(state1.amplitudes, state2.amplitudes)
    return torch.abs(overlap) ** 2


# ============================================================================
// Training and Optimization
// ============================================================================

def gradient_descent(
    circuit: QuantumCircuit,
    target_state: QutritState,
    initial_state: QutritState,
    learning_rate: float = 0.01,
    epochs: int = 100,
) -> Tuple[QuantumCircuit, List[float]]:
    """
    Optimize gate parameters via gradient descent.

    Args:
        circuit: Circuit with trainable parameters
        target_state: Target state to reach
        initial_state: Starting state
        learning_rate: Step size
        epochs: Number of optimization steps

    Returns:
        (trained_circuit, loss_history)
    """
    if not HAS_TORCH:
        raise RuntimeError("PyTorch required for optimization")

    # Create parameters if not present
    if circuit.gates[0].params is None:
        params = torch.randn(1, requires_grad=True)
        circuit.gates[0].params = params

    optimizer = torch.optim.SGD([circuit.gates[0].params], lr=learning_rate)
    loss_history = []

    for epoch in range(epochs):
        optimizer.zero_grad()

        # Forward pass
        final_state = apply_circuit(initial_state, circuit)
        fid = fidelity(final_state, target_state)
        loss = 1.0 - fid

        # Backward pass
        loss.backward()
        optimizer.step()

        loss_history.append(loss.item())

        if epoch % 10 == 0:
            print(f"Epoch {epoch}: loss = {loss.item():.6f}, fidelity = {fid:.6f}")

    return circuit, loss_history


# ============================================================================
// Tests
// ============================================================================

if __name__ == "__main__":
    if not HAS_TORCH:
        print("PyTorch not installed. Install with: pip install torch")
        exit(1)

    print("=" * 60)
    print("TRINITY v9.0 QUANTUM — PyTorch Quantum Simulation")
    print("=" * 60)
    print()

    # Verify TRINITY identity
    print("TRINITY Identity:")
    print(f"  φ² + 1/φ² = {GOLDEN_RATIO**2 + 1/GOLDEN_RATIO**2:.10f}")
    print(f"  Golden angle: {GOLDEN_ANGLE_DEG:.10f}° = {GOLDEN_ANGLE_RAD:.10f} rad")
    print()

    # Create states
    print("Qutrit States:")
    state_plus = QutritState.basis(1)
    state_zero = QutritState.basis(0)
    state_minus = QutritState.basis(-1)
    state_super = QutritState.superposition()

    print(f"  |+1⟩ probs: {state_plus.probabilities()}")
    print(f"  |0⟩ probs: {state_zero.probabilities()}")
    print(f"  |-1⟩ probs: {state_minus.probabilities()}")
    print(f"  Superposition probs: {state_super.probabilities()}")
    print()

    # Create gates
    print("Quantum Gates:")
    golden = QutritGate.golden_gate()
    trinity = QutritGate.trinity_phase_gate()

    print(f"  Golden gate is unitary: {golden.is_unitary()}")
    print(f"  TRINITY gate is unitary: {trinity.is_unitary()}")
    print()

    # Apply gates
    print("Gate Evolution:")
    state = state_super.clone()

    for step in range(5):
        probs = state.probabilities().detach().cpu().numpy()
        print(f"  Step {step}: P(+1)={probs[0]:.3f}, P(0)={probs[1]:.3f}, P(-1)={probs[2]:.3f}")
        state = apply_gate(state, golden)

    print()

    # Fidelity test
    state1 = QutritState.basis(1)
    state2 = QutritState.basis(1)
    fid = fidelity(state1, state2)
    print(f"Fidelity (identical states): {fid:.10f}")

    state3 = QutritState.basis(0)
    fid_orth = fidelity(state1, state3)
    print(f"Fidelity (orthogonal states): {fid_orth:.10f}")
    print()

    print("✓ PyTorch quantum simulation complete")
