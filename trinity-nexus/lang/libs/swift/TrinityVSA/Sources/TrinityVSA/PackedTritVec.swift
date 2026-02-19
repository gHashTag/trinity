import Foundation

/// Packed trit vector using bitsliced storage (2 bits per trit)
public struct PackedTritVec {
    public var pos: [UInt64]
    public var neg: [UInt64]
    public let dim: Int
    public var numWords: Int { pos.count }
    
    public init(pos: [UInt64], neg: [UInt64], dim: Int) {
        self.pos = pos
        self.neg = neg
        self.dim = dim
    }
    
    /// Create from dense vector
    public static func from(_ v: TritVector) -> PackedTritVec {
        let numWords = (v.dim + 63) / 64
        var pos = [UInt64](repeating: 0, count: numWords)
        var neg = [UInt64](repeating: 0, count: numWords)
        
        for i in 0..<v.dim {
            let wordIdx = i / 64
            let bitIdx = i % 64
            if v.data[i] == 1 {
                pos[wordIdx] |= 1 << bitIdx
            } else if v.data[i] == -1 {
                neg[wordIdx] |= 1 << bitIdx
            }
        }
        return PackedTritVec(pos: pos, neg: neg, dim: v.dim)
    }
    
    /// Convert to dense vector
    public func toVector() -> TritVector {
        var data = [Int8](repeating: 0, count: dim)
        for i in 0..<dim {
            let wordIdx = i / 64
            let bitIdx = i % 64
            let posSet = (pos[wordIdx] >> bitIdx) & 1
            let negSet = (neg[wordIdx] >> bitIdx) & 1
            if posSet == 1 { data[i] = 1 }
            else if negSet == 1 { data[i] = -1 }
        }
        return TritVector(data: data)
    }
}

/// Fast packed bind
public func packedBind(_ a: PackedTritVec, _ b: PackedTritVec) -> PackedTritVec {
    precondition(a.dim == b.dim, "Dimension mismatch")
    var pos = [UInt64](repeating: 0, count: a.numWords)
    var neg = [UInt64](repeating: 0, count: a.numWords)
    
    for i in 0..<a.numWords {
        // +1 when: (+1,+1) or (-1,-1)
        pos[i] = (a.pos[i] & b.pos[i]) | (a.neg[i] & b.neg[i])
        // -1 when: (+1,-1) or (-1,+1)
        neg[i] = (a.pos[i] & b.neg[i]) | (a.neg[i] & b.pos[i])
    }
    return PackedTritVec(pos: pos, neg: neg, dim: a.dim)
}

/// Fast packed dot product
public func packedDot(_ a: PackedTritVec, _ b: PackedTritVec) -> Int64 {
    precondition(a.dim == b.dim, "Dimension mismatch")
    var posCount: Int64 = 0
    var negCount: Int64 = 0
    
    for i in 0..<a.numWords {
        posCount += Int64(((a.pos[i] & b.pos[i]) | (a.neg[i] & b.neg[i])).nonzeroBitCount)
        negCount += Int64(((a.pos[i] & b.neg[i]) | (a.neg[i] & b.pos[i])).nonzeroBitCount)
    }
    return posCount - negCount
}
