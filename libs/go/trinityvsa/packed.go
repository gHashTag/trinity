package trinityvsa

// PackedTritVec uses bitsliced storage: 2 bits per trit
// pos[i] & neg[i] encodes: 00=0, 10=+1, 01=-1
type PackedTritVec struct {
	Pos      []uint64
	Neg      []uint64
	Dim      int
	NumWords int
}

// NewPackedFromVector converts dense vector to packed format
func NewPackedFromVector(v *TritVector) *PackedTritVec {
	numWords := (v.Dim + 63) / 64
	p := &PackedTritVec{
		Pos:      make([]uint64, numWords),
		Neg:      make([]uint64, numWords),
		Dim:      v.Dim,
		NumWords: numWords,
	}
	
	for i, t := range v.Data {
		wordIdx := i / 64
		bitIdx := uint(i % 64)
		switch t {
		case Pos:
			p.Pos[wordIdx] |= 1 << bitIdx
		case Neg:
			p.Neg[wordIdx] |= 1 << bitIdx
		}
	}
	return p
}

// ToVector converts packed to dense format
func (p *PackedTritVec) ToVector() *TritVector {
	v := NewZeros(p.Dim)
	for i := 0; i < p.Dim; i++ {
		wordIdx := i / 64
		bitIdx := uint(i % 64)
		posSet := (p.Pos[wordIdx] >> bitIdx) & 1
		negSet := (p.Neg[wordIdx] >> bitIdx) & 1
		if posSet == 1 {
			v.Data[i] = Pos
		} else if negSet == 1 {
			v.Data[i] = Neg
		}
	}
	return v
}

// PackedBind performs fast bitwise bind
func PackedBind(a, b *PackedTritVec) *PackedTritVec {
	if a.Dim != b.Dim {
		panic("dimension mismatch")
	}
	result := &PackedTritVec{
		Pos:      make([]uint64, a.NumWords),
		Neg:      make([]uint64, a.NumWords),
		Dim:      a.Dim,
		NumWords: a.NumWords,
	}
	
	for i := 0; i < a.NumWords; i++ {
		// Ternary multiplication via bitwise ops
		// +1 * +1 = +1, +1 * -1 = -1, -1 * -1 = +1
		// +1 * 0 = 0, -1 * 0 = 0, 0 * 0 = 0
		aPos, aNeg := a.Pos[i], a.Neg[i]
		bPos, bNeg := b.Pos[i], b.Neg[i]
		
		// Result is +1 when: (+1,+1) or (-1,-1)
		result.Pos[i] = (aPos & bPos) | (aNeg & bNeg)
		// Result is -1 when: (+1,-1) or (-1,+1)
		result.Neg[i] = (aPos & bNeg) | (aNeg & bPos)
	}
	return result
}

// PackedDot computes dot product using popcount
func PackedDot(a, b *PackedTritVec) int64 {
	if a.Dim != b.Dim {
		panic("dimension mismatch")
	}
	
	var posCount, negCount int64
	for i := 0; i < a.NumWords; i++ {
		// Count +1 * +1 and -1 * -1 (contribute +1)
		posCount += int64(popcount64((a.Pos[i] & b.Pos[i]) | (a.Neg[i] & b.Neg[i])))
		// Count +1 * -1 and -1 * +1 (contribute -1)
		negCount += int64(popcount64((a.Pos[i] & b.Neg[i]) | (a.Neg[i] & b.Pos[i])))
	}
	return posCount - negCount
}

// popcount64 counts set bits in a uint64
func popcount64(x uint64) int {
	// Brian Kernighan's algorithm
	count := 0
	for x != 0 {
		x &= x - 1
		count++
	}
	return count
}
