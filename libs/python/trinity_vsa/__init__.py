"""
Trinity VSA - Vector Symbolic Architecture for Python
Version 0.1.0
"""

__version__ = "0.1.0"
__author__ = "Trinity VSA Team"

from .core import Hypervector, bind, unbind, bundle, cosine_similarity

__all__ = [
    "Hypervector",
    "bind",
    "unbind",
    "bundle",
    "cosine_similarity",
]
