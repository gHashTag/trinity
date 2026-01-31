# trinity-vsa

TypeScript/JavaScript library for Vector Symbolic Architecture with balanced ternary arithmetic.

## Installation

```bash
npm install trinity-vsa
```

## Quick Start

```typescript
import { TritVector, bind, unbind, similarity, bundle, permute } from 'trinity-vsa';

// Create random hypervectors
const apple = TritVector.random(10000, 42);
const red = TritVector.random(10000, 123);

// Bind: create association
const redApple = bind(apple, red);

// Similarity
const sim = similarity(redApple, apple);
console.log(`Similarity: ${sim.toFixed(3)}`);

// Unbind: recover original
const recovered = unbind(redApple, red);
const recovery = similarity(recovered, apple);
console.log(`Recovery: ${recovery.toFixed(3)}`);
```

## API

### Types

```typescript
type Trit = -1 | 0 | 1;

class TritVector {
  readonly data: Int8Array;
  readonly dim: number;
  
  static zeros(dim: number): TritVector;
  static random(dim: number, seed?: number): TritVector;
  clone(): TritVector;
  nnz(): number;
  sparsity(): number;
}

class PackedTritVec {
  readonly pos: BigUint64Array;
  readonly neg: BigUint64Array;
  readonly dim: number;
  
  static fromVector(v: TritVector): PackedTritVec;
  toVector(): TritVector;
}
```

### Functions

| Function | Description |
|----------|-------------|
| `bind(a, b)` | Bind two vectors |
| `unbind(a, b)` | Unbind (inverse of bind) |
| `bundle(vectors)` | Bundle via majority vote |
| `permute(v, shift)` | Circular shift |
| `similarity(a, b)` | Cosine similarity |
| `dot(a, b)` | Dot product |
| `hammingDistance(a, b)` | Hamming distance |
| `packedBind(a, b)` | Fast packed bind |
| `packedDot(a, b)` | Fast packed dot |

## Example: Associative Memory

```typescript
import { TritVector, bind, similarity } from 'trinity-vsa';

// Create item-attribute pairs
const items = {
  apple: TritVector.random(10000, 1),
  banana: TritVector.random(10000, 2),
};

const colors = {
  red: TritVector.random(10000, 3),
  yellow: TritVector.random(10000, 4),
};

// Store associations
const memory = [
  bind(items.apple, colors.red),
  bind(items.banana, colors.yellow),
];

// Query: find best match
const query = bind(items.apple, colors.red);
memory.forEach((mem, i) => {
  console.log(`Memory ${i}: ${similarity(query, mem).toFixed(3)}`);
});
```

## License

MIT License
