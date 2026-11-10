part of '../map_painter.dart';

mixin _InteractionLogic on MapPainterBase {
  void drawSelectedPointHighlight(Canvas canvas) {
    if (selectedPoints.length == 2 && selectedPoints[0].provinceId == selectedPoints[1].provinceId) {
       final p1 = selectedPoints[0];
       final p2 = selectedPoints[1];
       final prov = _findProvinceById(p1.provinceId, p1.worldX, p1.worldY);

       if (prov != null) {
         int minIdx = math.min(p1.pointIndex, p2.pointIndex);
         int maxIdx = math.max(p1.pointIndex, p2.pointIndex);
         bool adjacent = (maxIdx - minIdx == 1) || (minIdx == 0 && maxIdx == prov.pointCount - 1);

         if (adjacent) {
            canvas.drawLine(
              Offset(p1.worldX.toDouble(), p1.worldY.toDouble()), 
              Offset(p2.worldX.toDouble(), p2.worldY.toDouble()), 
              _edgePaint
            );
         }
       }
    }

    Offset dragDelta = Offset.zero;
    if (draggingPoint != null && dragWorldPosition != null) {
      dragDelta = dragWorldPosition! - Offset(draggingPoint!.worldX.toDouble(), draggingPoint!.worldY.toDouble());
    }

    for (final sp in selectedPoints) {
      final center = Offset(sp.worldX.toDouble() + dragDelta.dx, sp.worldY.toDouble() + dragDelta.dy);
      canvas.drawCircle(center, 6 / zoomScale, _ringPaint);
    }
  }

  ProvinceModel? _findProvinceById(int id, int nearWorldX, int nearWorldY) {
    final grid = spatialIndex;
    if (grid != null) {
      for (final idx in grid.queryPoint(nearWorldX, nearWorldY)) {
        if (provinces[idx].id == id) return provinces[idx];
      }
    }
    for (final p in provinces) {
      if (p.id == id) return p;
    }
    return null;
  }

  ProvinceModel? resolveProvinceAt(Offset localPosition) {
    final world = screenToWorld(localPosition);
    final candidates = (spatialIndex != null && enableFrustumCulling) 
      ? spatialIndex!.queryPoint(world.dx.round(), world.dy.round()) 
      : Iterable<int>.generate(provinces.length).toSet();
    
    ProvinceModel? bestMatch;
    int bestArea = 0x7FFFFFFF;

    for (final index in candidates) {
      final p = provinces[index];
      if (p.containsWorldPoint(world.dx, world.dy)) {
        final area = p.boundingBox.width * p.boundingBox.height;
        if (bestMatch == null || area < bestArea) {
          bestMatch = p;
          bestArea = area;
        }
      }
    }
    return bestMatch;
  }

  MarkerHit? resolvePoiAt(Offset localPosition) {
    if (markers.isEmpty) return null;
    final world = screenToWorld(localPosition);
    final tolerance = 12.0 / zoomScale;

    final candidates = markerIndex != null
        ? markerIndex!.queryRadius(world.dx, world.dy, tolerance)
        : Iterable<int>.generate(markers.length);

    int? bestIndex;
    double bestDistSq = tolerance * tolerance;

    for (final i in candidates) {
      final marker = markers[i];
      if (hiddenCategories.contains(marker.category)) continue;

      final dx = marker.x - world.dx, dy = marker.y - world.dy;
      final distSq = dx * dx + dy * dy;
      if (distSq <= bestDistSq) {
        bestDistSq = distSq;
        bestIndex = i;
      }
    }

    if (bestIndex == null) return null;
    final marker = markers[bestIndex];
    return MarkerHit(
      category: marker.category,
      index: marker.index,
      label: marker.label,
      worldPosition: Offset(marker.x, marker.y),
    );
  }
}