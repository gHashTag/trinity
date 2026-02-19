# Trinity VSA for OCaml

Vector Symbolic Architecture with balanced ternary arithmetic.

## Installation

```
opam install trinity-vsa
```

## Quick Start

```ocaml
open Trinity_vsa

let () =
  let apple = random 10000 42 in
  let red = random 10000 123 in
  let red_apple = bind apple red in
  Printf.printf "Similarity: %.3f\n" (similarity red_apple apple);
  let recovered = unbind red_apple red in
  Printf.printf "Recovery: %.3f\n" (similarity recovered apple)
```

## License

MIT License
