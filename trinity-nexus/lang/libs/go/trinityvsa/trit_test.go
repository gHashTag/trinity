package trinityvsa

import (
	"math"
	"testing"
)

func TestBind(t *testing.T) {
	a := NewRandom(1000, 42)
	b := NewRandom(1000, 123)
	
	// Bind and unbind should recover original
	bound := Bind(a, b)
	recovered := Unbind(bound, b)
	
	sim := Similarity(recovered, a)
	if sim < 0.7 {
		t.Errorf("Expected high similarity after unbind, got %f", sim)
	}
}

func TestBundle(t *testing.T) {
	a := NewRandom(1000, 1)
	b := NewRandom(1000, 2)
	c := NewRandom(1000, 3)
	
	bundle := Bundle([]*TritVector{a, b, c})
	
	// Bundle should be similar to all inputs
	simA := Similarity(bundle, a)
	simB := Similarity(bundle, b)
	simC := Similarity(bundle, c)
	
	if simA < 0.3 || simB < 0.3 || simC < 0.3 {
		t.Errorf("Bundle should be similar to inputs: %f, %f, %f", simA, simB, simC)
	}
}

func TestPermute(t *testing.T) {
	a := NewRandom(1000, 42)
	
	// Permute should make vectors dissimilar
	permuted := Permute(a, 1)
	sim := Similarity(permuted, a)
	if math.Abs(sim) > 0.1 {
		t.Errorf("Permuted vector should be dissimilar, got %f", sim)
	}
	
	// Inverse permute should recover
	unpermuted := Permute(permuted, -1)
	simRecovered := Similarity(unpermuted, a)
	if simRecovered < 0.99 {
		t.Errorf("Inverse permute should recover original, got %f", simRecovered)
	}
}

func TestPacked(t *testing.T) {
	a := NewRandom(1000, 42)
	b := NewRandom(1000, 123)
	
	pa := NewPackedFromVector(a)
	pb := NewPackedFromVector(b)
	
	// Packed dot should match dense dot
	denseDot := Dot(a, b)
	packedDot := PackedDot(pa, pb)
	
	if denseDot != packedDot {
		t.Errorf("Packed dot mismatch: dense=%d, packed=%d", denseDot, packedDot)
	}
	
	// Packed bind should match dense bind
	denseBound := Bind(a, b)
	packedBound := PackedBind(pa, pb)
	recoveredBound := packedBound.ToVector()
	
	sim := Similarity(denseBound, recoveredBound)
	if sim < 0.99 {
		t.Errorf("Packed bind mismatch, similarity=%f", sim)
	}
}

func BenchmarkBind(b *testing.B) {
	a := NewRandom(10000, 42)
	c := NewRandom(10000, 123)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = Bind(a, c)
	}
}

func BenchmarkPackedBind(b *testing.B) {
	a := NewPackedFromVector(NewRandom(10000, 42))
	c := NewPackedFromVector(NewRandom(10000, 123))
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = PackedBind(a, c)
	}
}

func BenchmarkSimilarity(b *testing.B) {
	a := NewRandom(10000, 42)
	c := NewRandom(10000, 123)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = Similarity(a, c)
	}
}
