--- Trinity VSA - Vector Symbolic Architecture with balanced ternary arithmetic
-- @module trinityvsa

local trinityvsa = {}

--- Create zero trit vector
-- @param dim Dimension
-- @return Table of zeros
function trinityvsa.zeros(dim)
    local v = {}
    for i = 1, dim do v[i] = 0 end
    return v
end

--- Create random trit vector
-- @param dim Dimension
-- @param seed Random seed (optional)
-- @return Table with values in {-1, 0, 1}
function trinityvsa.random(dim, seed)
    if seed then math.randomseed(seed) end
    local v = {}
    for i = 1, dim do
        v[i] = math.random(3) - 2
    end
    return v
end

--- Bind two vectors (element-wise multiplication)
-- @param a First vector
-- @param b Second vector
-- @return Bound vector
function trinityvsa.bind(a, b)
    assert(#a == #b, "Dimension mismatch")
    local c = {}
    for i = 1, #a do
        c[i] = a[i] * b[i]
    end
    return c
end

--- Unbind (inverse of bind)
-- @param a First vector
-- @param b Second vector
-- @return Unbound vector
function trinityvsa.unbind(a, b)
    return trinityvsa.bind(a, b)
end

--- Bundle vectors via majority voting
-- @param vectors Table of vectors
-- @return Bundled vector
function trinityvsa.bundle(vectors)
    assert(#vectors > 0, "Empty vector list")
    local dim = #vectors[1]
    local c = {}
    
    for i = 1, dim do
        local sum = 0
        for _, v in ipairs(vectors) do
            sum = sum + v[i]
        end
        if sum > 0 then c[i] = 1
        elseif sum < 0 then c[i] = -1
        else c[i] = 0 end
    end
    return c
end

--- Circular permutation
-- @param v Vector
-- @param shift Shift amount
-- @return Permuted vector
function trinityvsa.permute(v, shift)
    local dim = #v
    local c = {}
    for i = 1, dim do
        local new_idx = ((i - 1 + shift) % dim) + 1
        c[new_idx] = v[i]
    end
    return c
end

--- Dot product
-- @param a First vector
-- @param b Second vector
-- @return Dot product
function trinityvsa.dot(a, b)
    assert(#a == #b, "Dimension mismatch")
    local sum = 0
    for i = 1, #a do
        sum = sum + a[i] * b[i]
    end
    return sum
end

--- Cosine similarity
-- @param a First vector
-- @param b Second vector
-- @return Similarity in [-1, 1]
function trinityvsa.similarity(a, b)
    local d = trinityvsa.dot(a, b)
    local norm_a = math.sqrt(trinityvsa.dot(a, a))
    local norm_b = math.sqrt(trinityvsa.dot(b, b))
    if norm_a == 0 or norm_b == 0 then return 0 end
    return d / (norm_a * norm_b)
end

--- Hamming distance
-- @param a First vector
-- @param b Second vector
-- @return Number of differing positions
function trinityvsa.hamming(a, b)
    assert(#a == #b, "Dimension mismatch")
    local count = 0
    for i = 1, #a do
        if a[i] ~= b[i] then count = count + 1 end
    end
    return count
end

--- Number of non-zero elements
-- @param v Vector
-- @return Count
function trinityvsa.nnz(v)
    local count = 0
    for i = 1, #v do
        if v[i] ~= 0 then count = count + 1 end
    end
    return count
end

return trinityvsa
