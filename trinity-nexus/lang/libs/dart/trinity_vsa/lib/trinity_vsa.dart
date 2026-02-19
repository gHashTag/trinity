/// Trinity VSA - Vector Symbolic Architecture with balanced ternary arithmetic
library trinity_vsa;

import 'dart:math';
import 'dart:typed_data';

typedef TritVector = Int8List;

TritVector tritZeros(int dim) => Int8List(dim);

TritVector tritRandom(int dim, [int? seed]) {
  final rng = seed != null ? Random(seed) : Random();
  return Int8List.fromList(
    List.generate(dim, (_) => rng.nextInt(3) - 1),
  );
}

TritVector tritBind(TritVector a, TritVector b) {
  assert(a.length == b.length, 'Dimension mismatch');
  return Int8List.fromList(
    List.generate(a.length, (i) => a[i] * b[i]),
  );
}

TritVector tritUnbind(TritVector a, TritVector b) => tritBind(a, b);

TritVector tritBundle(List<TritVector> vectors) {
  assert(vectors.isNotEmpty, 'Empty vector list');
  final dim = vectors[0].length;
  return Int8List.fromList(
    List.generate(dim, (i) {
      final sum = vectors.fold<int>(0, (acc, v) => acc + v[i]);
      return sum > 0 ? 1 : (sum < 0 ? -1 : 0);
    }),
  );
}

TritVector tritPermute(TritVector v, int shift) {
  final dim = v.length;
  final result = Int8List(dim);
  for (var i = 0; i < dim; i++) {
    final newIdx = (i + shift) % dim;
    result[newIdx < 0 ? newIdx + dim : newIdx] = v[i];
  }
  return result;
}

int tritDot(TritVector a, TritVector b) {
  assert(a.length == b.length, 'Dimension mismatch');
  var sum = 0;
  for (var i = 0; i < a.length; i++) {
    sum += a[i] * b[i];
  }
  return sum;
}

double tritSimilarity(TritVector a, TritVector b) {
  final d = tritDot(a, b).toDouble();
  final normA = sqrt(tritDot(a, a).toDouble());
  final normB = sqrt(tritDot(b, b).toDouble());
  if (normA == 0 || normB == 0) return 0;
  return d / (normA * normB);
}

int tritHammingDistance(TritVector a, TritVector b) {
  assert(a.length == b.length, 'Dimension mismatch');
  var count = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) count++;
  }
  return count;
}
