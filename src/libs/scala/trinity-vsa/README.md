# Trinity VSA for Scala

Vector Symbolic Architecture with balanced ternary arithmetic.

## Installation

```scala
libraryDependencies += "com.trinity" %% "trinity-vsa" % "0.1.0"
```

## Quick Start

```scala
import com.trinity.vsa._

val apple = TritVector.random(10000, Some(42L))
val red = TritVector.random(10000, Some(123L))

val redApple = VSA.bind(apple, red)
println(s"Similarity: ${VSA.similarity(redApple, apple)}")

val recovered = VSA.unbind(redApple, red)
println(s"Recovery: ${VSA.similarity(recovered, apple)}")
```

## License

MIT License
