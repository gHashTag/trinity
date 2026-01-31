# TrinityVSA.jl

Julia package for Vector Symbolic Architecture with balanced ternary arithmetic.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/gHashTag/trinity", subdir="libs/julia/TrinityVSA")
```

## Quick Start

```julia
using TrinityVSA

# Create random hypervectors
apple = random_trit_vector(10000, seed=42)
red = random_trit_vector(10000, seed=123)

# Bind: create association
red_apple = bind(apple, red)

# Similarity
sim = similarity(red_apple, apple)
println("Similarity: ", round(sim, digits=3))

# Unbind: recover original
recovered = unbind(red_apple, red)
recovery = similarity(recovered, apple)
println("Recovery: ", round(recovery, digits=3))
```

## API

### Types

```julia
const Trit = Int8  # -1, 0, +1

struct TritVector
    data::Vector{Int8}
end

struct PackedTritVec
    pos::Vector{UInt64}
    neg::Vector{UInt64}
    dim::Int
end
```

### Functions

| Function | Description |
|----------|-------------|
| `zeros_trit_vector(dim)` | Create zero vector |
| `random_trit_vector(dim; seed)` | Create random vector |
| `bind(a, b)` | Bind two vectors |
| `unbind(a, b)` | Unbind (inverse of bind) |
| `bundle(vectors)` | Bundle via majority vote |
| `permute(v, shift)` | Circular shift |
| `similarity(a, b)` | Cosine similarity |
| `dot(a, b)` | Dot product |
| `hamming_distance(a, b)` | Hamming distance |
| `packed_from_vector(v)` | Convert to packed |
| `packed_to_vector(p)` | Convert to dense |
| `packed_bind(a, b)` | Fast packed bind |
| `packed_dot(a, b)` | Fast packed dot |

## Example: Associative Memory

```julia
using TrinityVSA

# Create concepts
items = Dict(
    "apple" => random_trit_vector(10000, seed=1),
    "banana" => random_trit_vector(10000, seed=2)
)

colors = Dict(
    "red" => random_trit_vector(10000, seed=3),
    "yellow" => random_trit_vector(10000, seed=4)
)

# Store associations
memory = [
    bind(items["apple"], colors["red"]),
    bind(items["banana"], colors["yellow"])
]

# Query
query = bind(items["apple"], colors["red"])
for (i, mem) in enumerate(memory)
    sim = similarity(query, mem)
    println("Memory $i: $(round(sim, digits=3))")
end
```

## Benchmarks

```julia
using BenchmarkTools

a = random_trit_vector(10000)
b = random_trit_vector(10000)

@btime bind($a, $b)        # ~5 µs
@btime similarity($a, $b)  # ~8 µs

pa = packed_from_vector(a)
pb = packed_from_vector(b)

@btime packed_bind($pa, $pb)  # ~0.5 µs
@btime packed_dot($pa, $pb)   # ~0.3 µs
```

## License

MIT License
