"""Core types for Trinity VSA."""

from enum import IntEnum
from typing import List, Optional, Union
import numpy as np


class Trit(IntEnum):
    """Balanced ternary digit: -1, 0, or +1."""
    NEG = -1
    ZERO = 0
    POS = 1

    @classmethod
    def from_int(cls, v: int) -> "Trit":
        """Create trit from integer (uses sign)."""
        if v > 0:
            return cls.POS
        elif v < 0:
            return cls.NEG
        return cls.ZERO


class TritVector:
    """Dense vector of balanced ternary values.
    
    Attributes:
        data: numpy array of int8 values in {-1, 0, 1}
        
    Example:
        >>> v = TritVector.random(1000)
        >>> print(v.dim, v.nnz)
        1000 667
    """
    
    def __init__(self, data: np.ndarray):
        """Create from numpy array."""
        self.data = np.clip(data, -1, 1).astype(np.int8)
    
    @classmethod
    def zeros(cls, dim: int) -> "TritVector":
        """Create zero vector."""
        return cls(np.zeros(dim, dtype=np.int8))
    
    @classmethod
    def random(cls, dim: int, seed: Optional[int] = None) -> "TritVector":
        """Create random hypervector with uniform distribution over {-1, 0, 1}."""
        rng = np.random.default_rng(seed)
        data = rng.integers(-1, 2, size=dim, dtype=np.int8)
        return cls(data)
    
    @classmethod
    def random_sparse(cls, dim: int, sparsity: float = 0.9, seed: Optional[int] = None) -> "TritVector":
        """Create random sparse vector.
        
        Args:
            dim: Vector dimension
            sparsity: Fraction of zeros (0.9 = 90% zeros)
            seed: Random seed
        """
        rng = np.random.default_rng(seed)
        data = np.zeros(dim, dtype=np.int8)
        nnz = int(dim * (1 - sparsity))
        indices = rng.choice(dim, size=nnz, replace=False)
        values = rng.choice([-1, 1], size=nnz)
        data[indices] = values
        return cls(data)
    
    @classmethod
    def from_list(cls, data: List[int]) -> "TritVector":
        """Create from list of integers."""
        return cls(np.array(data, dtype=np.int8))
    
    @property
    def dim(self) -> int:
        """Vector dimension."""
        return len(self.data)
    
    @property
    def nnz(self) -> int:
        """Number of non-zero elements."""
        return int(np.count_nonzero(self.data))
    
    @property
    def sparsity(self) -> float:
        """Fraction of zeros."""
        return 1.0 - (self.nnz / self.dim)
    
    def __len__(self) -> int:
        return self.dim
    
    def __getitem__(self, idx: int) -> Trit:
        return Trit(self.data[idx])
    
    def __setitem__(self, idx: int, value: Union[int, Trit]):
        self.data[idx] = int(value)
    
    def __neg__(self) -> "TritVector":
        return TritVector(-self.data)
    
    def __eq__(self, other: "TritVector") -> bool:
        return np.array_equal(self.data, other.data)
    
    def __repr__(self) -> str:
        return f"TritVector(dim={self.dim}, nnz={self.nnz})"
    
    def to_numpy(self) -> np.ndarray:
        """Get underlying numpy array."""
        return self.data.copy()


class PackedTritVec:
    """Packed trit vector using 2 bits per trit.
    
    Memory efficient storage: 4x smaller than dense.
    
    Encoding:
        - 00 = 0
        - 01 = +1
        - 10 = -1
    """
    
    def __init__(self, pos: np.ndarray, neg: np.ndarray, dim: int):
        """Create from positive and negative bit arrays."""
        self.pos = pos  # uint64 array
        self.neg = neg  # uint64 array
        self._dim = dim
    
    @classmethod
    def from_trit_vector(cls, v: TritVector) -> "PackedTritVec":
        """Pack a TritVector."""
        dim = v.dim
        num_words = (dim + 63) // 64
        pos = np.zeros(num_words, dtype=np.uint64)
        neg = np.zeros(num_words, dtype=np.uint64)
        
        for i, trit in enumerate(v.data):
            word_idx = i // 64
            bit_idx = i % 64
            if trit == 1:
                pos[word_idx] |= np.uint64(1) << bit_idx
            elif trit == -1:
                neg[word_idx] |= np.uint64(1) << bit_idx
        
        return cls(pos, neg, dim)
    
    def to_trit_vector(self) -> TritVector:
        """Unpack to TritVector."""
        data = np.zeros(self._dim, dtype=np.int8)
        
        for i in range(self._dim):
            word_idx = i // 64
            bit_idx = i % 64
            mask = np.uint64(1) << bit_idx
            
            if self.pos[word_idx] & mask:
                data[i] = 1
            elif self.neg[word_idx] & mask:
                data[i] = -1
        
        return TritVector(data)
    
    @property
    def dim(self) -> int:
        return self._dim
    
    def memory_bytes(self) -> int:
        """Memory usage in bytes."""
        return len(self.pos) * 8 * 2
    
    def bind(self, other: "PackedTritVec") -> "PackedTritVec":
        """Fast bitwise bind operation."""
        assert self._dim == other._dim
        
        # Result is +1 when: (a=+1 AND b=+1) OR (a=-1 AND b=-1)
        new_pos = (self.pos & other.pos) | (self.neg & other.neg)
        # Result is -1 when: (a=+1 AND b=-1) OR (a=-1 AND b=+1)
        new_neg = (self.pos & other.neg) | (self.neg & other.pos)
        
        return PackedTritVec(new_pos, new_neg, self._dim)
    
    def dot(self, other: "PackedTritVec") -> int:
        """Fast dot product using popcount."""
        assert self._dim == other._dim
        
        # Count +1 * +1 and -1 * -1 (contribute +1)
        pos_pos = np.sum([bin(x).count('1') for x in (self.pos & other.pos)])
        neg_neg = np.sum([bin(x).count('1') for x in (self.neg & other.neg)])
        
        # Count +1 * -1 and -1 * +1 (contribute -1)
        pos_neg = np.sum([bin(x).count('1') for x in (self.pos & other.neg)])
        neg_pos = np.sum([bin(x).count('1') for x in (self.neg & other.pos)])
        
        return int(pos_pos + neg_neg - pos_neg - neg_pos)


class SparseVec:
    """Sparse trit vector storing only non-zero elements.
    
    Efficient for vectors with >90% zeros.
    """
    
    def __init__(self, indices: np.ndarray, values: np.ndarray, dim: int):
        """Create from indices and values."""
        self.indices = indices.astype(np.int64)
        self.values = values.astype(np.int8)
        self._dim = dim
    
    @classmethod
    def from_trit_vector(cls, v: TritVector) -> "SparseVec":
        """Create sparse representation."""
        nonzero = np.nonzero(v.data)[0]
        return cls(nonzero, v.data[nonzero], v.dim)
    
    def to_trit_vector(self) -> TritVector:
        """Convert to dense."""
        data = np.zeros(self._dim, dtype=np.int8)
        data[self.indices] = self.values
        return TritVector(data)
    
    @property
    def dim(self) -> int:
        return self._dim
    
    @property
    def nnz(self) -> int:
        return len(self.indices)
    
    @property
    def sparsity(self) -> float:
        return 1.0 - (self.nnz / self._dim)
    
    def dot(self, other: "SparseVec") -> int:
        """Sparse dot product."""
        assert self._dim == other._dim
        
        # Use set intersection for efficiency
        self_dict = dict(zip(self.indices, self.values))
        result = 0
        for idx, val in zip(other.indices, other.values):
            if idx in self_dict:
                result += int(self_dict[idx]) * int(val)
        return result
