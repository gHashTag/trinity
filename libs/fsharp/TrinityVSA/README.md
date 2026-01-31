# TrinityVSA for F#

Vector Symbolic Architecture with balanced ternary arithmetic.

## Quick Start

```fsharp
open TrinityVSA

let apple = random 10000 42
let red = random 10000 123

let redApple = bind apple red
printfn "Similarity: %f" (similarity redApple apple)

let recovered = unbind redApple red
printfn "Recovery: %f" (similarity recovered apple)
```

## License

MIT License
