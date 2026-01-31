"""
Trinity VSA - Vector Symbolic Architecture with Balanced Ternary Arithmetic

High-performance library for hyperdimensional computing.

Example:
    >>> from trinity_vsa import TritVector, bind, bundle, similarity
    >>> apple = TritVector.random(10000)
    >>> red = TritVector.random(10000)
    >>> red_apple = bind(apple, red)
    >>> sim = similarity(red_apple, apple)
"""

from .core import (
    Trit,
    TritVector,
    PackedTritVec,
    SparseVec,
)

from .ops import (
    bind,
    unbind,
    bundle,
    permute,
    similarity,
    hamming_distance,
)

__version__ = "0.1.0"
__all__ = [
    "Trit",
    "TritVector",
    "PackedTritVec",
    "SparseVec",
    "bind",
    "unbind",
    "bundle",
    "permute",
    "similarity",
    "hamming_distance",
]
