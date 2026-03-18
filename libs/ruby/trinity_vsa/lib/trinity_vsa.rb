# frozen_string_literal: true

# Trinity VSA - Vector Symbolic Architecture with balanced ternary arithmetic
module TrinityVSA
  # Dense trit vector
  class TritVector
    attr_reader :data, :dim

    def initialize(data)
      @data = data
      @dim = data.length
    end

    def self.zeros(dim)
      new(Array.new(dim, 0))
    end

    def self.random(dim, seed: nil)
      srand(seed) if seed
      new(Array.new(dim) { rand(3) - 1 })
    end

    def [](i)
      @data[i]
    end

    def []=(i, v)
      @data[i] = v
    end

    def nnz
      @data.count { |x| x != 0 }
    end

    def sparsity
      1.0 - nnz.to_f / dim
    end

    def negate!
      @data.map! { |x| -x }
    end

    def clone
      TritVector.new(@data.dup)
    end
  end

  class << self
    # Bind two vectors (element-wise multiplication)
    def bind(a, b)
      raise 'Dimension mismatch' unless a.dim == b.dim
      TritVector.new(a.data.zip(b.data).map { |x, y| x * y })
    end

    # Unbind (inverse of bind)
    def unbind(a, b)
      bind(a, b)
    end

    # Bundle vectors via majority voting
    def bundle(vectors)
      raise 'Empty vector list' if vectors.empty?
      dim = vectors[0].dim
      result = Array.new(dim) do |i|
        sum = vectors.sum { |v| v[i] }
        sum > 0 ? 1 : (sum < 0 ? -1 : 0)
      end
      TritVector.new(result)
    end

    # Circular permutation
    def permute(v, shift)
      TritVector.new(v.data.rotate(-shift))
    end

    # Dot product
    def dot(a, b)
      raise 'Dimension mismatch' unless a.dim == b.dim
      a.data.zip(b.data).sum { |x, y| x * y }
    end

    # Cosine similarity
    def similarity(a, b)
      d = dot(a, b).to_f
      norm_a = Math.sqrt(dot(a, a))
      norm_b = Math.sqrt(dot(b, b))
      return 0.0 if norm_a.zero? || norm_b.zero?
      d / (norm_a * norm_b)
    end

    # Hamming distance
    def hamming_distance(a, b)
      raise 'Dimension mismatch' unless a.dim == b.dim
      a.data.zip(b.data).count { |x, y| x != y }
    end
  end
end
