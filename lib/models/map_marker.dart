import 'dart:ui' show Offset;

class MapMarker {
  final double x;
  final double y;
  final String shape;
  final int colorValue;
  final double size;
  final String label;
  final String category;
  final int index;

  const MapMarker({
    required this.x,
    required this.y,
    required this.shape,
    required this.colorValue,
    required this.size,
    required this.label,
    required this.category,
    required this.index,
  });

  factory MapMarker.fromMap(Map<String, dynamic> map) {
    return MapMarker(
      x: (map['x'] as num?)?.toDouble() ?? 0,
      y: (map['y'] as num?)?.toDouble() ?? 0,
      shape: map['shape']?.toString() ?? 'circle',
      colorValue: (map['color'] as num?)?.toInt() ?? 0xFFFFFFFF,
      size: (map['size'] as num?)?.toDouble() ?? 4.0,
      label: map['label']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      index: (map['index'] as num?)?.toInt() ?? 0,
    );
  }
}

class MarkerSpatialIndex {
  static const int cellSize = 64;
  
  // Otimização Nível 2: Hashing espacial Web-Safe para Index de Markers
  final Map<int, List<int>> _cells = {};
  final List<MapMarker> markers;

  MarkerSpatialIndex(this.markers) {
    for (int i = 0; i < markers.length; i++) {
      final m = markers[i];
      final cx = (m.x / cellSize).floor();
      final cy = (m.y / cellSize).floor();
      final hash = (cx + 1000000) * 10000000 + (cy + 1000000);
      _cells.putIfAbsent(hash, () => []).add(i);
    }
  }

  Iterable<int> queryRadius(double px, double py, double radius) {
    final cxMin = ((px - radius) / cellSize).floor();
    final cxMax = ((px + radius) / cellSize).floor();
    final cyMin = ((py - radius) / cellSize).floor();
    final cyMax = ((py + radius) / cellSize).floor();
    final result = <int>[];
    for (int cx = cxMin; cx <= cxMax; cx++) {
      for (int cy = cyMin; cy <= cyMax; cy++) {
        final hash = (cx + 1000000) * 10000000 + (cy + 1000000);
        final bucket = _cells[hash];
        if (bucket != null) result.addAll(bucket);
      }
    }
    return result;
  }
}

class MarkerHit {
  final String category;
  final int index;
  final String label;
  final Offset worldPosition;

  const MarkerHit({
    required this.category,
    required this.index,
    required this.label,
    required this.worldPosition,
  });
}