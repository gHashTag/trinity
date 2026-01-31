# TrinityVSA for MATLAB/Octave

Vector Symbolic Architecture with balanced ternary arithmetic.

## Installation

Add the `matlab` folder to your MATLAB path:

```matlab
addpath('/path/to/trinity/libs/matlab');
```

## Quick Start

```matlab
% Create random hypervectors
apple = TrinityVSA.random(10000, 42);
red = TrinityVSA.random(10000, 123);

% Bind: create association
red_apple = TrinityVSA.bind(apple, red);

% Similarity
sim = TrinityVSA.similarity(red_apple, apple);
fprintf('Similarity: %.3f\n', sim);

% Unbind: recover original
recovered = TrinityVSA.unbind(red_apple, red);
recovery = TrinityVSA.similarity(recovered, apple);
fprintf('Recovery: %.3f\n', recovery);
```

## Functions

| Function | Description |
|----------|-------------|
| `TrinityVSA.zeros(dim)` | Create zero vector |
| `TrinityVSA.random(dim, seed)` | Create random vector |
| `TrinityVSA.bind(a, b)` | Bind two vectors |
| `TrinityVSA.unbind(a, b)` | Unbind |
| `TrinityVSA.bundle(vectors)` | Bundle via majority vote |
| `TrinityVSA.permute(v, shift)` | Circular shift |
| `TrinityVSA.similarity(a, b)` | Cosine similarity |

## License

MIT License
