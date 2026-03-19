# trinity-vsa

Vector Symbolic Architecture with balanced ternary arithmetic for Clojure.

## Installation

```clojure
[trinity-vsa "0.1.0"]
```

## Quick Start

```clojure
(require '[trinity.vsa :as vsa])

(def apple (vsa/random-vec 10000 42))
(def red (vsa/random-vec 10000 123))

(def red-apple (vsa/bind apple red))
(println "Similarity:" (vsa/similarity red-apple apple))

(def recovered (vsa/unbind red-apple red))
(println "Recovery:" (vsa/similarity recovered apple))
```

## License

MIT License
