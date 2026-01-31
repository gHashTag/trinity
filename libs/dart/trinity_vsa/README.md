# trinity_vsa

Vector Symbolic Architecture with balanced ternary arithmetic for Dart/Flutter.

## Installation

```yaml
dependencies:
  trinity_vsa: ^0.1.0
```

## Quick Start

```dart
import 'package:trinity_vsa/trinity_vsa.dart';

void main() {
  final apple = tritRandom(10000, 42);
  final red = tritRandom(10000, 123);
  
  final redApple = tritBind(apple, red);
  print('Similarity: ${tritSimilarity(redApple, apple)}');
  
  final recovered = tritUnbind(redApple, red);
  print('Recovery: ${tritSimilarity(recovered, apple)}');
}
```

## License

MIT License
