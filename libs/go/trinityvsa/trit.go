// Package trinityvsa provides Vector Symbolic Architecture with balanced ternary arithmetic.
package trinityvsa

import (
	"math"
	"math/rand"
)

// Trit represents a balanced ternary value: -1, 0, or +1
type Trit int8

const (
	Neg  Trit = -1
	Zero Trit = 0
	Pos  Trit = 1
)

// Mul multiplies two trits
func (t Trit) Mul(other Trit) Trit {
	return Trit(int8(t) * int8(other))
}

// Neg returns the negation of a trit
func (t Trit) Negate() Trit {
	return Trit(-int8(t))
}

// TritVector is a dense vector of trits
type TritVector struct {
	Data []Trit
	Dim  int
}

// NewZeros creates a zero vector of given dimension
func NewZeros(dim int) *TritVector {
	return &TritVector{
		Data: make([]Trit, dim),
		Dim:  dim,
	}
}

// NewRandom creates a random vector with balanced distribution
func NewRandom(dim int, seed int64) *TritVector {
	rng := rand.New(rand.NewSource(seed))
	data := make([]Trit, dim)
	for i := range data {
		r := rng.Intn(3)
		data[i] = Trit(r - 1) // -1, 0, or 1
	}
	return &TritVector{Data: data, Dim: dim}
}

// Clone creates a copy of the vector
func (v *TritVector) Clone() *TritVector {
	data := make([]Trit, v.Dim)
	copy(data, v.Data)
	return &TritVector{Data: data, Dim: v.Dim}
}

// Bind performs element-wise multiplication (XOR-like for ternary)
func Bind(a, b *TritVector) *TritVector {
	if a.Dim != b.Dim {
		panic("dimension mismatch")
	}
	result := NewZeros(a.Dim)
	for i := 0; i < a.Dim; i++ {
		result.Data[i] = a.Data[i].Mul(b.Data[i])
	}
	return result
}

// Unbind is the inverse of Bind (same operation for balanced ternary)
func Unbind(a, b *TritVector) *TritVector {
	return Bind(a, b)
}

// Bundle combines multiple vectors via majority voting
func Bundle(vectors []*TritVector) *TritVector {
	if len(vectors) == 0 {
		panic("empty vector list")
	}
	dim := vectors[0].Dim
	result := NewZeros(dim)
	
	for i := 0; i < dim; i++ {
		sum := 0
		for _, v := range vectors {
			sum += int(v.Data[i])
		}
		if sum > 0 {
			result.Data[i] = Pos
		} else if sum < 0 {
			result.Data[i] = Neg
		} else {
			result.Data[i] = Zero
		}
	}
	return result
}

// Permute performs circular shift
func Permute(v *TritVector, shift int) *TritVector {
	result := NewZeros(v.Dim)
	for i := 0; i < v.Dim; i++ {
		newIdx := (i + shift) % v.Dim
		if newIdx < 0 {
			newIdx += v.Dim
		}
		result.Data[newIdx] = v.Data[i]
	}
	return result
}

// Dot computes dot product
func Dot(a, b *TritVector) int64 {
	if a.Dim != b.Dim {
		panic("dimension mismatch")
	}
	var sum int64
	for i := 0; i < a.Dim; i++ {
		sum += int64(a.Data[i]) * int64(b.Data[i])
	}
	return sum
}

// Similarity computes cosine similarity
func Similarity(a, b *TritVector) float64 {
	dot := float64(Dot(a, b))
	normA := math.Sqrt(float64(Dot(a, a)))
	normB := math.Sqrt(float64(Dot(b, b)))
	if normA == 0 || normB == 0 {
		return 0
	}
	return dot / (normA * normB)
}

// HammingDistance counts differing positions
func HammingDistance(a, b *TritVector) int {
	if a.Dim != b.Dim {
		panic("dimension mismatch")
	}
	count := 0
	for i := 0; i < a.Dim; i++ {
		if a.Data[i] != b.Data[i] {
			count++
		}
	}
	return count
}

// NNZ returns number of non-zero elements
func (v *TritVector) NNZ() int {
	count := 0
	for _, t := range v.Data {
		if t != Zero {
			count++
		}
	}
	return count
}

// Sparsity returns fraction of zeros
func (v *TritVector) Sparsity() float64 {
	return 1.0 - float64(v.NNZ())/float64(v.Dim)
}

// Negate negates all elements in place
func (v *TritVector) Negate() {
	for i := range v.Data {
		v.Data[i] = v.Data[i].Negate()
	}
}
