# TrinityVSA

R package for Vector Symbolic Architecture with balanced ternary arithmetic.

## Installation

```r
# From GitHub
devtools::install_github("gHashTag/trinity", subdir = "libs/r/TrinityVSA")
```

## Quick Start

```r
library(TrinityVSA)

# Create random hypervectors
apple <- trit_random(10000, seed = 42)
red <- trit_random(10000, seed = 123)

# Bind: create association
red_apple <- trit_bind(apple, red)

# Similarity
sim <- trit_similarity(red_apple, apple)
cat("Similarity:", round(sim, 3), "\n")

# Unbind: recover original
recovered <- trit_unbind(red_apple, red)
recovery <- trit_similarity(recovered, apple)
cat("Recovery:", round(recovery, 3), "\n")
```

## Functions

| Function | Description |
|----------|-------------|
| `trit_zeros(dim)` | Create zero vector |
| `trit_random(dim, seed)` | Create random vector |
| `trit_bind(a, b)` | Bind two vectors |
| `trit_unbind(a, b)` | Unbind |
| `trit_bundle(vectors)` | Bundle via majority vote |
| `trit_permute(v, shift)` | Circular shift |
| `trit_similarity(a, b)` | Cosine similarity |
| `trit_dot(a, b)` | Dot product |
| `trit_hamming(a, b)` | Hamming distance |

## License

MIT License
