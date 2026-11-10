import 'dart:typed_data';

/// Axis-Aligned Bounding Box de uma província (ou do mapa inteiro).
///
/// É calculada UMA ÚNICA VEZ na importação (ver `aoh2_converter.dart`) e
/// persistida no JSON interno, para que a engine nunca mais precise
/// varrer todos os pontos de um polígono só para saber sua extensão —
/// isso é o que torna o Frustum Culling em `map_painter.dart` O(1) por
/// província em vez de O(pontos).
class BoundingBox {
  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  const BoundingBox({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  /// Caixa "vazia" sentinela. Usa min invertido com max (min > max) em vez
  /// de (0,0,0,0): uma província real com todos os pontos na origem tem
  /// uma AABB legítima de (0,0,0,0), que colidiria com esse sentinela e
  /// seria descartada silenciosamente por `merge()`/`isEmpty`. Com min/max
  /// invertidos, `merge()` funciona por comparação pura, sem caso especial.
  factory BoundingBox.empty() => const BoundingBox(
        minX: _posInf,
        minY: _posInf,
        maxX: _negInf,
        maxY: _negInf,
      );

  static const int _posInf = 0x7FFFFFFF;
  static const int _negInf = -0x80000000;

  factory BoundingBox.fromPoints(Int32List xs, Int32List ys) {
    if (xs.isEmpty) return BoundingBox.empty();
    int minX = xs[0], maxX = xs[0], minY = ys[0], maxY = ys[0];
    for (int i = 1; i < xs.length; i++) {
      final x = xs[i];
      final y = ys[i];
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
    return BoundingBox(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
  }

  factory BoundingBox.fromJson(Map<String, dynamic> json) => BoundingBox(
        minX: json['minX'] as int,
        minY: json['minY'] as int,
        maxX: json['maxX'] as int,
        maxY: json['maxY'] as int,
      );

  Map<String, dynamic> toJson() => {
        'minX': minX,
        'minY': minY,
        'maxX': maxX,
        'maxY': maxY,
      };

  bool intersects(BoundingBox other) {
    return minX <= other.maxX &&
        maxX >= other.minX &&
        minY <= other.maxY &&
        maxY >= other.minY;
  }

  bool containsPoint(int x, int y) =>
      x >= minX && x <= maxX && y >= minY && y <= maxY;

  BoundingBox merge(BoundingBox other) {
    if (isEmpty) return other;
    if (other.isEmpty) return this;
    return BoundingBox(
      minX: minX < other.minX ? minX : other.minX,
      minY: minY < other.minY ? minY : other.minY,
      maxX: maxX > other.maxX ? maxX : other.maxX,
      maxY: maxY > other.maxY ? maxY : other.maxY,
    );
  }

  /// Vazia sse min > max (sentinela), nunca por coincidir com dado real.
  bool get isEmpty => minX > maxX || minY > maxY;
  int get centerX => (minX + maxX) ~/ 2;
  int get centerY => (minY + maxY) ~/ 2;
  int get width => isEmpty ? 0 : maxX - minX;
  int get height => isEmpty ? 0 : maxY - minY;
}
