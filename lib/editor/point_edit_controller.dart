import '../engine/spatial_grid.dart';
import '../models/province.dart';

enum NudgeDirection { up, down, left, right, upLeft, upRight, downLeft, downRight }

const Map<NudgeDirection, (int dx, int dy)> nudgeDeltaUnits = {
  NudgeDirection.up: (0, -1),
  NudgeDirection.down: (0, 1),
  NudgeDirection.left: (-1, 0),
  NudgeDirection.right: (1, 0),
  NudgeDirection.upLeft: (-1, -1),
  NudgeDirection.upRight: (1, -1),
  NudgeDirection.downLeft: (-1, 1),
  NudgeDirection.downRight: (1, 1),
};

class SelectedPointRef {
  final int provinceId;
  final int pointIndex;
  final int worldX;
  final int worldY;
  final double distance;

  const SelectedPointRef({
    required this.provinceId,
    required this.pointIndex,
    required this.worldX,
    required this.worldY,
    this.distance = 0.0,
  });

  SelectedPointRef withWorldPosition(int x, int y) => SelectedPointRef(
        provinceId: provinceId,
        pointIndex: pointIndex,
        worldX: x,
        worldY: y,
        distance: distance,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SelectedPointRef &&
          provinceId == other.provinceId &&
          pointIndex == other.pointIndex &&
          worldX == other.worldX &&
          worldY == other.worldY);

  @override
  int get hashCode => Object.hash(provinceId, pointIndex, worldX, worldY);
}

/// Encontra TODOS os pontos próximos ao clique e ordena por prioridade
List<SelectedPointRef> findPointsNear({
  required List<ProvinceModel> provinces,
  required SpatialGrid? spatialIndex,
  required double worldX,
  required double worldY,
  required double maxWorldDistance,
  Set<int>? priorityProvinceIds,
}) {
  final candidateIndices = spatialIndex != null
      ? spatialIndex.queryRadius(worldX, worldY, maxWorldDistance)
      : Iterable<int>.generate(provinces.length).toSet();

  List<SelectedPointRef> hits = [];
  double maxWorldDistanceSq = maxWorldDistance * maxWorldDistance;

  for (final index in candidateIndices) {
    final province = provinces[index];
    for (int i = 0; i < province.pointCount; i++) {
      double dx = province.pointsX[i] - worldX;
      double dy = province.pointsY[i] - worldY;
      double distSq = dx * dx + dy * dy;

      if (distSq <= maxWorldDistanceSq) {
        hits.add(SelectedPointRef(
          provinceId: province.id,
          pointIndex: i,
          worldX: province.pointsX[i],
          worldY: province.pointsY[i],
          distance: distSq, // Guardando a Distância ao Quadrado para evitar math.sqrt
        ));
      }
    }
  }

  hits.sort((a, b) {
    bool aPrio = priorityProvinceIds != null && priorityProvinceIds.contains(a.provinceId);
    bool bPrio = priorityProvinceIds != null && priorityProvinceIds.contains(b.provinceId);

    if (aPrio && !bPrio) return -1;
    if (!aPrio && bPrio) return 1;
    return a.distance.compareTo(b.distance); // Compara usando a distância ao quadrado (mantém a mesma ordem lógica)
  });

  return hits;
}

SelectedPointRef? findNearestPoint({
  required List<ProvinceModel> provinces,
  required SpatialGrid? spatialIndex,
  required double worldX,
  required double worldY,
  required double maxWorldDistance,
  Set<int>? priorityProvinceIds,
}) {
  final hits = findPointsNear(
    provinces: provinces, spatialIndex: spatialIndex,
    worldX: worldX, worldY: worldY,
    maxWorldDistance: maxWorldDistance, priorityProvinceIds: priorityProvinceIds
  );
  return hits.isNotEmpty ? hits.first : null;
}