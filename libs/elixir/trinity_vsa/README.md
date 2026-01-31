# TrinityVsa

Vector Symbolic Architecture with balanced ternary arithmetic for Elixir.

## Installation

```elixir
def deps do
  [{:trinity_vsa, "~> 0.1.0"}]
end
```

## Quick Start

```elixir
apple = TrinityVsa.random(10000, 42)
red = TrinityVsa.random(10000, 123)

red_apple = TrinityVsa.bind(apple, red)
IO.puts("Similarity: #{TrinityVsa.similarity(red_apple, apple)}")

recovered = TrinityVsa.unbind(red_apple, red)
IO.puts("Recovery: #{TrinityVsa.similarity(recovered, apple)}")
```

## License

MIT License
