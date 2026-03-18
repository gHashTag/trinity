# Trinity VSA for Kotlin

Vector Symbolic Architecture with balanced ternary arithmetic.

## Installation

```kotlin
dependencies {
    implementation("com.trinity:trinity-vsa:0.1.0")
}
```

## Quick Start

```kotlin
import com.trinity.vsa.*

fun main() {
    val apple = TritVector.random(10000, seed = 42)
    val red = TritVector.random(10000, seed = 123)
    
    val redApple = bind(apple, red)
    println("Similarity: ${similarity(redApple, apple)}")
    
    val recovered = unbind(redApple, red)
    println("Recovery: ${similarity(recovered, apple)}")
}
```

## License

MIT License
