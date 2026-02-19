# Trinity VSA for Ruby

Vector Symbolic Architecture with balanced ternary arithmetic.

## Installation

```ruby
gem 'trinity_vsa'
```

## Quick Start

```ruby
require 'trinity_vsa'

apple = TrinityVSA::TritVector.random(10000, seed: 42)
red = TrinityVSA::TritVector.random(10000, seed: 123)

red_apple = TrinityVSA.bind(apple, red)
puts "Similarity: #{TrinityVSA.similarity(red_apple, apple).round(3)}"

recovered = TrinityVSA.unbind(red_apple, red)
puts "Recovery: #{TrinityVSA.similarity(recovered, apple).round(3)}"
```

## License

MIT License
