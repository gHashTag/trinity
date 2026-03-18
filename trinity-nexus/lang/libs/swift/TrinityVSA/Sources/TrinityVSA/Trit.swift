import Foundation

/// Balanced ternary value: -1, 0, or +1
public enum Trit: Int8, CaseIterable {
    case neg = -1
    case zero = 0
    case pos = 1
    
    /// Multiply two trits
    public func multiply(_ other: Trit) -> Trit {
        Trit(rawValue: self.rawValue * other.rawValue) ?? .zero
    }
    
    /// Negate trit
    public var negated: Trit {
        Trit(rawValue: -self.rawValue) ?? .zero
    }
    
    /// Create from integer
    public static func from(_ value: Int) -> Trit {
        if value > 0 { return .pos }
        if value < 0 { return .neg }
        return .zero
    }
}

/// Dense vector of balanced ternary values
public struct TritVector {
    public var data: [Int8]
    public var dim: Int { data.count }
    
    public init(data: [Int8]) {
        self.data = data
    }
    
    /// Create zero vector
    public static func zeros(_ dim: Int) -> TritVector {
        TritVector(data: [Int8](repeating: 0, count: dim))
    }
    
    /// Create random vector with balanced distribution
    public static func random(_ dim: Int, seed: UInt64 = 0) -> TritVector {
        var rng = seed == 0 ? UInt64.random(in: 0...UInt64.max) : seed
        var data = [Int8](repeating: 0, count: dim)
        
        for i in 0..<dim {
            // Simple LCG
            rng = rng &* 1103515245 &+ 12345
            data[i] = Int8((Int(rng % 3)) - 1)
        }
        return TritVector(data: data)
    }
    
    /// Get element
    public subscript(i: Int) -> Trit {
        get { Trit(rawValue: data[i]) ?? .zero }
        set { data[i] = newValue.rawValue }
    }
    
    /// Number of non-zero elements
    public var nnz: Int {
        data.filter { $0 != 0 }.count
    }
    
    /// Sparsity (fraction of zeros)
    public var sparsity: Double {
        1.0 - Double(nnz) / Double(dim)
    }
    
    /// Negate in place
    public mutating func negate() {
        for i in 0..<dim {
            data[i] = -data[i]
        }
    }
}

// MARK: - VSA Operations

/// Bind two vectors (element-wise multiplication)
public func bind(_ a: TritVector, _ b: TritVector) -> TritVector {
    precondition(a.dim == b.dim, "Dimension mismatch")
    var result = [Int8](repeating: 0, count: a.dim)
    for i in 0..<a.dim {
        result[i] = a.data[i] * b.data[i]
    }
    return TritVector(data: result)
}

/// Unbind (inverse of bind)
public func unbind(_ a: TritVector, _ b: TritVector) -> TritVector {
    bind(a, b)
}

/// Bundle multiple vectors via majority voting
public func bundle(_ vectors: [TritVector]) -> TritVector {
    precondition(!vectors.isEmpty, "Empty vector list")
    let dim = vectors[0].dim
    var result = [Int8](repeating: 0, count: dim)
    
    for i in 0..<dim {
        var sum = 0
        for v in vectors {
            sum += Int(v.data[i])
        }
        if sum > 0 { result[i] = 1 }
        else if sum < 0 { result[i] = -1 }
        else { result[i] = 0 }
    }
    return TritVector(data: result)
}

/// Circular permutation
public func permute(_ v: TritVector, shift: Int) -> TritVector {
    var result = [Int8](repeating: 0, count: v.dim)
    for i in 0..<v.dim {
        var newIdx = (i + shift) % v.dim
        if newIdx < 0 { newIdx += v.dim }
        result[newIdx] = v.data[i]
    }
    return TritVector(data: result)
}

/// Dot product
public func dot(_ a: TritVector, _ b: TritVector) -> Int64 {
    precondition(a.dim == b.dim, "Dimension mismatch")
    var sum: Int64 = 0
    for i in 0..<a.dim {
        sum += Int64(a.data[i]) * Int64(b.data[i])
    }
    return sum
}

/// Cosine similarity
public func similarity(_ a: TritVector, _ b: TritVector) -> Double {
    let d = Double(dot(a, b))
    let normA = sqrt(Double(dot(a, a)))
    let normB = sqrt(Double(dot(b, b)))
    guard normA > 0 && normB > 0 else { return 0 }
    return d / (normA * normB)
}

/// Hamming distance
public func hammingDistance(_ a: TritVector, _ b: TritVector) -> Int {
    precondition(a.dim == b.dim, "Dimension mismatch")
    var count = 0
    for i in 0..<a.dim {
        if a.data[i] != b.data[i] { count += 1 }
    }
    return count
}
