/// Trinity VSA - Vector Symbolic Architecture with balanced ternary arithmetic
module trinityvsa;

import std.math : sqrt;
import std.random : Random, uniform;
import std.algorithm : map, sum, count;
import std.array : array;
import std.range : iota, zip;

alias Trit = byte;  /// -1, 0, or +1
alias TritVector = Trit[];

/// Create zero vector
TritVector zeros(size_t dim) {
    return new Trit[dim];
}

/// Create random vector
TritVector random(size_t dim, uint seed = 0) {
    auto rng = Random(seed);
    auto result = new Trit[dim];
    foreach (ref t; result) {
        t = cast(Trit)(uniform(0, 3, rng) - 1);
    }
    return result;
}

/// Bind two vectors (element-wise multiplication)
TritVector bind(TritVector a, TritVector b) {
    assert(a.length == b.length, "Dimension mismatch");
    return zip(a, b).map!(t => cast(Trit)(t[0] * t[1])).array;
}

/// Unbind (inverse of bind)
TritVector unbind(TritVector a, TritVector b) {
    return bind(a, b);
}

/// Bundle vectors via majority voting
TritVector bundle(TritVector[] vectors) {
    assert(vectors.length > 0, "Empty vector list");
    auto dim = vectors[0].length;
    auto result = new Trit[dim];
    foreach (i; 0 .. dim) {
        int s = 0;
        foreach (v; vectors) s += v[i];
        result[i] = s > 0 ? 1 : (s < 0 ? -1 : 0);
    }
    return result;
}

/// Circular permutation
TritVector permute(TritVector v, int shift) {
    auto dim = v.length;
    auto result = new Trit[dim];
    foreach (i; 0 .. dim) {
        auto newIdx = ((i + shift) % cast(int)dim + dim) % dim;
        result[newIdx] = v[i];
    }
    return result;
}

/// Dot product
long dot(TritVector a, TritVector b) {
    assert(a.length == b.length, "Dimension mismatch");
    return zip(a, b).map!(t => cast(long)t[0] * t[1]).sum;
}

/// Cosine similarity
double similarity(TritVector a, TritVector b) {
    auto d = cast(double)dot(a, b);
    auto normA = sqrt(cast(double)dot(a, a));
    auto normB = sqrt(cast(double)dot(b, b));
    return (normA == 0 || normB == 0) ? 0.0 : d / (normA * normB);
}

/// Hamming distance
size_t hammingDistance(TritVector a, TritVector b) {
    assert(a.length == b.length, "Dimension mismatch");
    return zip(a, b).count!(t => t[0] != t[1]);
}
