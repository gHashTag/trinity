# Trinity VSA for Haskell

Vector Symbolic Architecture with balanced ternary arithmetic.

## Installation

```yaml
dependencies:
  - trinity-vsa
```

## Quick Start

```haskell
import TrinityVSA

main :: IO ()
main = do
  let apple = random 10000 42
      red = random 10000 123
      redApple = bind apple red
  putStrLn $ "Similarity: " ++ show (similarity redApple apple)
  let recovered = unbind redApple red
  putStrLn $ "Recovery: " ++ show (similarity recovered apple)
```

## License

MIT License
