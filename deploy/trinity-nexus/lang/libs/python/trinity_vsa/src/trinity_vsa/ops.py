"""VSA operations: bind, bundle, permute, similarity."""

from typing import List, Sequence
import numpy as np

from .core import TritVector


def bind(a: TritVector, b: TritVector) -> TritVector:
    """Bind two vectors (element-wise multiplication).
    
    Creates an association between two concepts.
    
    Properties:
        - bind(a, a) results in all +1 (for non-zero elements)
        - bind(a, bind(a, b)) = b (unbinding)
        - Commutative: bind(a, b) = bind(b, a)
    
    Args:
        a: First vector
        b: Second vector
        
    Returns:
        Bound vector
        
    Example:
        >>> apple = TritVector.random(1000)
        >>> red = TritVector.random(1000)
        >>> red_apple = bind(apple, red)
    """
    assert a.dim == b.dim, "Vectors must have same dimension"
    return TritVector(a.data * b.data)


def unbind(bound: TritVector, key: TritVector) -> TritVector:
    """Unbind (same as bind for balanced ternary).
    
    Retrieves one vector from a bound pair.
    
    Args:
        bound: Bound vector
        key: Key vector to unbind with
        
    Returns:
        Retrieved vector (approximately equal to the other bound vector)
        
    Example:
        >>> red_apple = bind(apple, red)
        >>> recovered = unbind(red_apple, red)
        >>> # recovered ≈ apple
    """
    return bind(bound, key)


def bundle(vectors: Sequence[TritVector]) -> TritVector:
    """Bundle multiple vectors (majority voting).
    
    Creates a superposition that is similar to all inputs.
    
    Args:
        vectors: Sequence of vectors to bundle
        
    Returns:
        Bundled vector
        
    Example:
        >>> fruits = bundle([apple, orange, banana])
        >>> # fruits is similar to all three
    """
    if not vectors:
        return TritVector.zeros(0)
    
    dim = vectors[0].dim
    assert all(v.dim == dim for v in vectors), "All vectors must have same dimension"
    
    # Sum all vectors
    sums = np.sum([v.data.astype(np.int32) for v in vectors], axis=0)
    
    # Threshold: positive -> 1, negative -> -1, zero -> 0
    result = np.sign(sums).astype(np.int8)
    return TritVector(result)


def permute(v: TritVector, shift: int) -> TritVector:
    """Permute vector (circular shift).
    
    Used for encoding sequences and positions.
    
    Args:
        v: Vector to permute
        shift: Number of positions to shift (positive = right)
        
    Returns:
        Permuted vector
        
    Example:
        >>> # Encode sequence: word1, word2, word3
        >>> seq = bind(word1, bind(permute(word2, 1), permute(word3, 2)))
    """
    return TritVector(np.roll(v.data, shift))


def similarity(a: TritVector, b: TritVector) -> float:
    """Cosine similarity between two vectors.
    
    Args:
        a: First vector
        b: Second vector
        
    Returns:
        Similarity in [-1.0, 1.0]:
        - 1.0: identical
        - 0.0: orthogonal
        - -1.0: opposite
        
    Example:
        >>> sim = similarity(red_apple, apple)
        >>> print(f"Similarity: {sim:.3f}")
    """
    assert a.dim == b.dim, "Vectors must have same dimension"
    
    dot = np.sum(a.data.astype(np.float64) * b.data.astype(np.float64))
    norm_a = np.sqrt(np.sum(a.data.astype(np.float64) ** 2))
    norm_b = np.sqrt(np.sum(b.data.astype(np.float64) ** 2))
    
    if norm_a == 0 or norm_b == 0:
        return 0.0
    
    return float(dot / (norm_a * norm_b))


def hamming_distance(a: TritVector, b: TritVector) -> int:
    """Hamming distance (number of differing positions).
    
    Args:
        a: First vector
        b: Second vector
        
    Returns:
        Number of positions where vectors differ
    """
    assert a.dim == b.dim, "Vectors must have same dimension"
    return int(np.sum(a.data != b.data))


def dot_product(a: TritVector, b: TritVector) -> int:
    """Dot product of two vectors.
    
    Args:
        a: First vector
        b: Second vector
        
    Returns:
        Sum of element-wise products
    """
    assert a.dim == b.dim, "Vectors must have same dimension"
    return int(np.sum(a.data.astype(np.int64) * b.data.astype(np.int64)))


def encode_sequence(words: List[TritVector]) -> TritVector:
    """Encode a sequence of vectors using permutation.
    
    Args:
        words: List of word vectors in order
        
    Returns:
        Single vector encoding the sequence
        
    Example:
        >>> sentence = encode_sequence([the, cat, sat, on, mat])
    """
    if not words:
        return TritVector.zeros(0)
    
    result = words[0]
    for i, word in enumerate(words[1:], 1):
        result = bind(result, permute(word, i))
    
    return result


def cleanup(query: TritVector, memory: List[TritVector], threshold: float = 0.0) -> TritVector:
    """Clean up noisy vector by finding closest match in memory.
    
    Args:
        query: Noisy query vector
        memory: List of clean prototype vectors
        threshold: Minimum similarity to return a match
        
    Returns:
        Closest matching vector from memory, or query if no match
    """
    if not memory:
        return query
    
    best_sim = threshold
    best_match = query
    
    for proto in memory:
        sim = similarity(query, proto)
        if sim > best_sim:
            best_sim = sim
            best_match = proto
    
    return best_match
