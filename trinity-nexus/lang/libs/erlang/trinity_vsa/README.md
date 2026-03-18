# trinity_vsa

Vector Symbolic Architecture with balanced ternary arithmetic for Erlang.

## Quick Start

```erlang
Apple = trinity_vsa:random(10000, 42),
Red = trinity_vsa:random(10000, 123),

RedApple = trinity_vsa:bind(Apple, Red),
io:format("Similarity: ~p~n", [trinity_vsa:similarity(RedApple, Apple)]),

Recovered = trinity_vsa:unbind(RedApple, Red),
io:format("Recovery: ~p~n", [trinity_vsa:similarity(Recovered, Apple)]).
```

## License

MIT License
