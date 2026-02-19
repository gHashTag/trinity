# TrinityVSA for Wolfram/Mathematica

Vector Symbolic Architecture with balanced ternary arithmetic.

## Installation

```mathematica
Get["path/to/TrinityVSA.wl"]
```

## Quick Start

```mathematica
<< TrinityVSA`

apple = TritRandom[10000, 42];
red = TritRandom[10000, 123];

redApple = TritBind[apple, red];
Print["Similarity: ", TritSimilarity[redApple, apple]]

recovered = TritUnbind[redApple, red];
Print["Recovery: ", TritSimilarity[recovered, apple]]
```

## Functions

| Function | Description |
|----------|-------------|
| `TritZeros[dim]` | Create zero vector |
| `TritRandom[dim, seed]` | Create random vector |
| `TritBind[a, b]` | Bind two vectors |
| `TritUnbind[a, b]` | Unbind |
| `TritBundle[vectors]` | Bundle via majority vote |
| `TritPermute[v, shift]` | Circular shift |
| `TritSimilarity[a, b]` | Cosine similarity |
| `TritDot[a, b]` | Dot product |

## License

MIT License
