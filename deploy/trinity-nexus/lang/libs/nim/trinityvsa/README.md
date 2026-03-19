# TrinityVSA for Nim

Vector Symbolic Architecture with balanced ternary arithmetic.

## Installation

```
nimble install trinityvsa
```

## Quick Start

```nim
import trinityvsa

let apple = random(10000, 42)
let red = random(10000, 123)

let redApple = `bind`(apple, red)
echo "Similarity: ", similarity(redApple, apple)

let recovered = unbind(redApple, red)
echo "Recovery: ", similarity(recovered, apple)
```

## License

MIT License
