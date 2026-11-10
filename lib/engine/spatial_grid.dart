import '../models/province.dart';

/// Índice espacial em grid uniforme sobre as AABBs das províncias.
class SpatialGrid {
  List<ProvinceModel> provinces;
  final int cellSize;
  
  // Otimização Nível 2: Spatial Hashing em Inteiro Único.
  // Substitui o uso de Records (int, int) que causavam constante alocação
  // de memória e acionavam o Garbage Collector durante interações de arraste.
  final Map<int, List<int>> _cells = {};

  SpatialGrid({required this.provinces, required this.cellSize}) {
    _build();
  }

  void _build() {
    for (int index = 0; index < provinces.length; index++) {
      _insertIndex(index, provinces[index].boundingBox);
    }
  }

  // Gera um ID numérico único (e Web-Safe) para qualquer par (cx, cy)
  // Suporta mapas massivos garantindo que não haverá colisão de hash.
  int _hash(int cx, int cy) => (cx + 1000000) * 10000000 + (cy + 1000000);

  int _cellHashOf(int worldX, int worldY) =>
      _hash((worldX / cellSize).floor(), (worldY / cellSize).floor());

  void _forEachCellInBounds(BoundingBox bb, void Function(int cellHash) fn) {
    if (bb.isEmpty) return;
    final cxMin = (bb.minX / cellSize).floor();
    final cxMax = (bb.maxX / cellSize).floor();
    final cyMin = (bb.minY / cellSize).floor();
    final cyMax = (bb.maxY / cellSize).floor();
    for (int cx = cxMin; cx <= cxMax; cx++) {
      for (int cy = cyMin; cy <= cyMax; cy++) {
        fn(_hash(cx, cy));
      }
    }
  }

  void _insertIndex(int index, BoundingBox bb) {
    _forEachCellInBounds(bb, (cellHash) {
      _cells.putIfAbsent(cellHash, () => <int>[]).add(index);
    });
  }

  void _removeIndex(int index, BoundingBox bb) {
    _forEachCellInBounds(bb, (cellHash) {
      final bucket = _cells[cellHash];
      if (bucket == null) return;
      bucket.remove(index);
      if (bucket.isEmpty) _cells.remove(cellHash);
    });
  }

  void updateProvinceAt(int index, BoundingBox oldBoundingBox) {
    _removeIndex(index, oldBoundingBox);
    _insertIndex(index, provinces[index].boundingBox);
  }

  Set<int> queryRegion(BoundingBox region) {
    final result = <int>{};
    _forEachCellInBounds(region, (cellHash) {
      final bucket = _cells[cellHash];
      if (bucket != null) result.addAll(bucket);
    });
    return result;
  }

  Set<int> queryPoint(int px, int py) {
    return Set<int>.of(_cells[_cellHashOf(px, py)] ?? const <int>[]);
  }

  Set<int> queryRadius(double px, double py, double radius) {
    if (radius <= cellSize / 2) {
      return queryPoint(px.round(), py.round());
    }
    final region = BoundingBox(
      minX: (px - radius).floor(),
      minY: (py - radius).floor(),
      maxX: (px + radius).ceil(),
      maxY: (py + radius).ceil(),
    );
    return queryRegion(region);
  }
}