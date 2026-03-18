"""
TrinityVSA - Vector Symbolic Architecture with balanced ternary arithmetic

# Example
```julia
using TrinityVSA

apple = random_trit_vector(10000)
red = random_trit_vector(10000)

red_apple = bind(apple, red)
sim = similarity(red_apple, apple)
println("Similarity: ", sim)
```
"""
module TrinityVSA

using Random

export Trit, TritVector, PackedTritVec
export zeros_trit_vector, random_trit_vector
export bind, unbind, bundle, permute
export similarity, dot, hamming_distance
export packed_from_vector, packed_to_vector, packed_bind, packed_dot

"""
Balanced ternary value: -1, 0, or +1
"""
const Trit = Int8

"""
Dense vector of balanced ternary values
"""
struct TritVector
    data::Vector{Int8}
end

Base.length(v::TritVector) = length(v.data)
Base.getindex(v::TritVector, i) = v.data[i]
Base.setindex!(v::TritVector, val, i) = v.data[i] = val

"""
Create zero vector of given dimension
"""
zeros_trit_vector(dim::Int) = TritVector(zeros(Int8, dim))

"""
Create random vector with balanced distribution
"""
function random_trit_vector(dim::Int; seed::Union{Int,Nothing}=nothing)
    rng = isnothing(seed) ? Random.default_rng() : Random.MersenneTwister(seed)
    data = rand(rng, Int8[-1, 0, 1], dim)
    TritVector(data)
end

"""
Number of non-zero elements
"""
nnz(v::TritVector) = count(!=(0), v.data)

"""
Sparsity (fraction of zeros)
"""
sparsity(v::TritVector) = 1.0 - nnz(v) / length(v)

"""
Negate vector
"""
negate(v::TritVector) = TritVector(-v.data)

"""
Bind two vectors (element-wise multiplication)
"""
function bind(a::TritVector, b::TritVector)
    @assert length(a) == length(b) "Dimension mismatch"
    TritVector(a.data .* b.data)
end

"""
Unbind (inverse of bind, same operation for balanced ternary)
"""
unbind(a::TritVector, b::TritVector) = bind(a, b)

"""
Bundle multiple vectors via majority voting
"""
function bundle(vectors::Vector{TritVector})
    @assert !isempty(vectors) "Empty vector list"
    dim = length(vectors[1])
    result = zeros(Int8, dim)
    
    for i in 1:dim
        s = sum(v.data[i] for v in vectors)
        if s > 0
            result[i] = 1
        elseif s < 0
            result[i] = -1
        end
    end
    TritVector(result)
end

"""
Circular permutation
"""
function permute(v::TritVector, shift::Int)
    TritVector(circshift(v.data, shift))
end

"""
Dot product
"""
function dot(a::TritVector, b::TritVector)
    @assert length(a) == length(b) "Dimension mismatch"
    sum(Int64(a.data[i]) * Int64(b.data[i]) for i in 1:length(a))
end

"""
Cosine similarity
"""
function similarity(a::TritVector, b::TritVector)
    d = dot(a, b)
    norm_a = sqrt(dot(a, a))
    norm_b = sqrt(dot(b, b))
    (norm_a == 0 || norm_b == 0) ? 0.0 : d / (norm_a * norm_b)
end

"""
Hamming distance
"""
function hamming_distance(a::TritVector, b::TritVector)
    @assert length(a) == length(b) "Dimension mismatch"
    count(a.data .!= b.data)
end

"""
Packed trit vector using bitsliced storage (2 bits per trit)
"""
struct PackedTritVec
    pos::Vector{UInt64}
    neg::Vector{UInt64}
    dim::Int
end

"""
Create packed vector from dense vector
"""
function packed_from_vector(v::TritVector)
    dim = length(v)
    num_words = cld(dim, 64)
    pos = zeros(UInt64, num_words)
    neg = zeros(UInt64, num_words)
    
    for i in 1:dim
        word_idx = cld(i, 64)
        bit_idx = (i - 1) % 64
        if v.data[i] == 1
            pos[word_idx] |= UInt64(1) << bit_idx
        elseif v.data[i] == -1
            neg[word_idx] |= UInt64(1) << bit_idx
        end
    end
    PackedTritVec(pos, neg, dim)
end

"""
Convert packed to dense vector
"""
function packed_to_vector(p::PackedTritVec)
    data = zeros(Int8, p.dim)
    for i in 1:p.dim
        word_idx = cld(i, 64)
        bit_idx = (i - 1) % 64
        pos_set = (p.pos[word_idx] >> bit_idx) & 1
        neg_set = (p.neg[word_idx] >> bit_idx) & 1
        if pos_set == 1
            data[i] = 1
        elseif neg_set == 1
            data[i] = -1
        end
    end
    TritVector(data)
end

"""
Fast packed bind
"""
function packed_bind(a::PackedTritVec, b::PackedTritVec)
    @assert a.dim == b.dim "Dimension mismatch"
    num_words = length(a.pos)
    pos = Vector{UInt64}(undef, num_words)
    neg = Vector{UInt64}(undef, num_words)
    
    for i in 1:num_words
        # +1 when: (+1,+1) or (-1,-1)
        pos[i] = (a.pos[i] & b.pos[i]) | (a.neg[i] & b.neg[i])
        # -1 when: (+1,-1) or (-1,+1)
        neg[i] = (a.pos[i] & b.neg[i]) | (a.neg[i] & b.pos[i])
    end
    PackedTritVec(pos, neg, a.dim)
end

"""
Fast packed dot product
"""
function packed_dot(a::PackedTritVec, b::PackedTritVec)
    @assert a.dim == b.dim "Dimension mismatch"
    pos_count = 0
    neg_count = 0
    
    for i in 1:length(a.pos)
        pos_count += count_ones((a.pos[i] & b.pos[i]) | (a.neg[i] & b.neg[i]))
        neg_count += count_ones((a.pos[i] & b.neg[i]) | (a.neg[i] & b.pos[i]))
    end
    pos_count - neg_count
end

end # module
