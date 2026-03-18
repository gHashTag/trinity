# Trinity VSA for Java

Vector Symbolic Architecture with balanced ternary arithmetic.

## Installation

### Maven
```xml
<dependency>
    <groupId>com.trinity</groupId>
    <artifactId>trinity-vsa</artifactId>
    <version>0.1.0</version>
</dependency>
```

### Gradle
```groovy
implementation 'com.trinity:trinity-vsa:0.1.0'
```

## Quick Start

```java
import com.trinity.vsa.*;

public class Example {
    public static void main(String[] args) {
        // Create random hypervectors
        TritVector apple = TritVector.random(10000, 42);
        TritVector red = TritVector.random(10000, 123);
        
        // Bind: create association
        TritVector redApple = VSA.bind(apple, red);
        
        // Similarity
        double sim = VSA.similarity(redApple, apple);
        System.out.printf("Similarity: %.3f%n", sim);
        
        // Unbind: recover original
        TritVector recovered = VSA.unbind(redApple, red);
        double recovery = VSA.similarity(recovered, apple);
        System.out.printf("Recovery: %.3f%n", recovery);
    }
}
```

## API

### Classes

```java
// Balanced ternary value
enum Trit { NEG, ZERO, POS }

// Dense vector
class TritVector {
    static TritVector zeros(int dim);
    static TritVector random(int dim, long seed);
    int getDim();
    byte get(int i);
    int nnz();
    double sparsity();
}

// Packed vector (2 bits per trit)
class PackedTritVec {
    static PackedTritVec fromVector(TritVector v);
    TritVector toVector();
    static PackedTritVec bind(PackedTritVec a, PackedTritVec b);
    static long dot(PackedTritVec a, PackedTritVec b);
}
```

### VSA Operations

```java
class VSA {
    static TritVector bind(TritVector a, TritVector b);
    static TritVector unbind(TritVector a, TritVector b);
    static TritVector bundle(List<TritVector> vectors);
    static TritVector permute(TritVector v, int shift);
    static long dot(TritVector a, TritVector b);
    static double similarity(TritVector a, TritVector b);
    static int hammingDistance(TritVector a, TritVector b);
}
```

## Example: Associative Memory

```java
import com.trinity.vsa.*;
import java.util.*;

public class AssociativeMemory {
    public static void main(String[] args) {
        // Create concepts
        Map<String, TritVector> items = Map.of(
            "apple", TritVector.random(10000, 1),
            "banana", TritVector.random(10000, 2)
        );
        
        Map<String, TritVector> colors = Map.of(
            "red", TritVector.random(10000, 3),
            "yellow", TritVector.random(10000, 4)
        );
        
        // Store associations
        List<TritVector> memory = List.of(
            VSA.bind(items.get("apple"), colors.get("red")),
            VSA.bind(items.get("banana"), colors.get("yellow"))
        );
        
        // Query
        TritVector query = VSA.bind(items.get("apple"), colors.get("red"));
        for (int i = 0; i < memory.size(); i++) {
            double sim = VSA.similarity(query, memory.get(i));
            System.out.printf("Memory %d: %.3f%n", i, sim);
        }
    }
}
```

## License

MIT License
