# Trinity VSA for Lua

Vector Symbolic Architecture with balanced ternary arithmetic.

## Installation

```lua
local vsa = require("trinityvsa")
```

## Quick Start

```lua
local vsa = require("trinityvsa")

local apple = vsa.random(10000, 42)
local red = vsa.random(10000, 123)

local red_apple = vsa.bind(apple, red)
print(string.format("Similarity: %.3f", vsa.similarity(red_apple, apple)))

local recovered = vsa.unbind(red_apple, red)
print(string.format("Recovery: %.3f", vsa.similarity(recovered, apple)))
```

## License

MIT License
