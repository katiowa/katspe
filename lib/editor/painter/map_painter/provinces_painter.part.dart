part of '../map_painter.dart';

mixin _ProvincesPainter on MapPainterBase {
  void drawProvincesLayer(Canvas canvas, BoundingBox visibleWorld, Iterable<int> candidateIndices) {
    final unselectedIndices = <int>[];
    final selectedIndices = <int>[];

    for (final index in candidateIndices) {
      final province = provinces[index];
      if (enableFrustumCulling && !province.boundingBox.intersects(visibleWorld)) continue;

      if (selectedProvinceIds.contains(province.id)) {
        selectedIndices.add(index);
      } else {
        unselectedIndices.add(index);
      }
    }

    void drawProv(int index, bool isSelected) {
      final province = provinces[index];
      final path = _buildPath(province);

      _fillPaint.color = isSelected
          ? config.selectedFillColor.withAlpha(config.selectedFillAlpha)
          : province.color.withAlpha(config.provinceFillAlpha);
      
      canvas.drawPath(path, _fillPaint);
      canvas.drawPath(path, isSelected ? _selectedBorderPaint : _borderPaint);

      if (config.showPointHandles || showAllPoints) {
        _drawPointHandles(canvas, province);
      }
    }

    for (final i in unselectedIndices) { drawProv(i, false); }
    for (final i in selectedIndices) { drawProv(i, true); }
  }

  void drawXRayLayer(Canvas canvas, Iterable<int> candidateIndices) {
    final edgeCounts = <(int, int, int, int), int>{};
    final edgeMap = <(int, int, int, int), Path>{};

    for (final index in candidateIndices) {
      final p = provinces[index];
      for (int i = 0; i < p.pointCount; i++) {
        final next = (i + 1) % p.pointCount;
        final x1 = p.pointsX[i]; final y1 = p.pointsY[i];
        final x2 = p.pointsX[next]; final y2 = p.pointsY[next];

        final minX = math.min(x1, x2); final maxX = math.max(x1, x2);
        final minY = math.min(y1, y2); final maxY = math.max(y1, y2);
        final key = (minX, minY, maxX, maxY);

        edgeCounts[key] = (edgeCounts[key] ?? 0) + 1;
        if (!edgeMap.containsKey(key)) {
          edgeMap[key] = Path()..moveTo(x1.toDouble(), y1.toDouble())..lineTo(x2.toDouble(), y2.toDouble());
        }
      }
    }

    for (final entry in edgeCounts.entries) {
      if (entry.value == 1) canvas.drawPath(edgeMap[entry.key]!, _xRayPaint);
    }
  }

  void drawInProgressLayer(Canvas canvas) {
    final path = Path()..moveTo(provinceInProgress![0].dx, provinceInProgress![0].dy);
    for (int i = 1; i < provinceInProgress!.length; i++) { 
      path.lineTo(provinceInProgress![i].dx, provinceInProgress![i].dy); 
    }
    path.close();

    final baseColor = provinceInProgressColor ?? config.selectedFillColor;
    
    _fillPaint.color = baseColor.withAlpha(config.selectedFillAlpha ~/ 2);
    canvas.drawPath(path, _fillPaint);
    
    final previousColor = _selectedBorderPaint.color;
    _selectedBorderPaint.color = baseColor;
    canvas.drawPath(path, _selectedBorderPaint);
    _selectedBorderPaint.color = previousColor;

    final Float32List rawPts = Float32List(provinceInProgress!.length * 2);
    int idx = 0;
    for (final point in provinceInProgress!) {
      rawPts[idx++] = point.dx;
      rawPts[idx++] = point.dy;
    }
    
    final previousHandleColor = _handlePaint.color;
    _handlePaint.color = baseColor;
    canvas.drawRawPoints(ui.PointMode.points, rawPts, _handlePaint);
    _handlePaint.color = previousHandleColor;
  }

  Path _buildPath(ProvinceModel province) {
    final isBeingDragged = _isProvinceBeingDragged(province.id);
    if (!isBeingDragged) {
      return cache.paths.getOrBuild(province.id, province.geometryVersion, () => _buildRawPath(province));
    }
    return _buildRawPath(province);
  }

  bool _isProvinceBeingDragged(int provinceId) {
    if (provinceDragDelta != Offset.zero && selectedProvinceIds.contains(provinceId)) return true;
    if (draggingPoint != null) {
      for (final sp in selectedPoints) {
        if (sp.provinceId == provinceId) return true;
      }
    }
    return false;
  }

  Path _buildRawPath(ProvinceModel province) {
    final path = Path();
    Offset dragDelta = Offset.zero;
    if (draggingPoint != null && dragWorldPosition != null) {
      dragDelta = dragWorldPosition! - Offset(draggingPoint!.worldX.toDouble(), draggingPoint!.worldY.toDouble());
    }

    bool isSel(int i) => fastSelectedPoints.contains((province.id, i));
    
    double getX(int i) {
      if (selectedProvinceIds.contains(province.id)) return province.pointsX[i] + provinceDragDelta.dx;
      return isSel(i) ? province.pointsX[i] + dragDelta.dx : province.pointsX[i].toDouble();
    }

    double getY(int i) {
      if (selectedProvinceIds.contains(province.id)) return province.pointsY[i] + provinceDragDelta.dy;
      return isSel(i) ? province.pointsY[i] + dragDelta.dy : province.pointsY[i].toDouble();
    }

    path.moveTo(getX(0), getY(0));
    for (int i = 1; i < province.pointsX.length; i++) { path.lineTo(getX(i), getY(i)); }
    path.close();
    return path;
  }

  void _drawPointHandles(Canvas canvas, ProvinceModel province) {
    Offset dragDelta = Offset.zero;
    if (draggingPoint != null && dragWorldPosition != null) {
      dragDelta = dragWorldPosition! - Offset(draggingPoint!.worldX.toDouble(), draggingPoint!.worldY.toDouble());
    }

    final bool isProvDragged = selectedProvinceIds.contains(province.id);
    final int len = province.pointsX.length;
    
    final Float32List rawPoints = Float32List(len * 2);
    int idx = 0;

    for (int i = 0; i < len; i++) {
      final bool selected = fastSelectedPoints.contains((province.id, i));
      
      final double x = isProvDragged
          ? province.pointsX[i] + provinceDragDelta.dx
          : (selected ? province.pointsX[i] + dragDelta.dx : province.pointsX[i].toDouble());
          
      final double y = isProvDragged
          ? province.pointsY[i] + provinceDragDelta.dy
          : (selected ? province.pointsY[i] + dragDelta.dy : province.pointsY[i].toDouble());
          
      rawPoints[idx++] = x;
      rawPoints[idx++] = y;
    }

    canvas.drawRawPoints(ui.PointMode.points, rawPoints, _handlePaint);
  }
}