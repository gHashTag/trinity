# Trinity VSA for D

Vector Symbolic Architecture with balanced ternary arithmetic.

## Installation

```
dub add trinity-vsa
```

## Quick Start

```d
import trinityvsa;

void main() {
    auto apple = random(10000, 42);
    auto red = random(10000, 123);
    
    auto redApple = bind(apple, red);
    writefln("Similarity: %.3f", similarity(redApple, apple));
    
    auto recovered = unbind(redApple, red);
    writefln("Recovery: %.3f", similarity(recovered, apple));
}
```

## License

MIT License
