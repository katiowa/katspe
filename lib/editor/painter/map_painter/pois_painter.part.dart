part of '../map_painter.dart';

mixin _PoisPainter on MapPainterBase {
  void drawPoisLayer(Canvas canvas, BoundingBox visibleWorld) {
    final textDirection = TextDirection.ltr;

    if (pendingPoiContext != null && pendingPoiContext!['index'] == null) {
      final catId = pendingPoiContext!['category'];
      final catDef = poiCategories.firstWhere((c) => c['id'] == catId, orElse: () => <String, dynamic>{});
      
      if (catDef.isNotEmpty) {
        final center = Offset((pendingPoiContext!['x'] as num).toDouble(), (pendingPoiContext!['y'] as num).toDouble());
        _poiPaint.color = Color((catDef['marker_color'] as num?)?.toInt() ?? 0xFFFFFFFF);
        final size = ((catDef['marker_size'] as num?)?.toDouble() ?? 4.0) / zoomScale;

        switch (catDef['marker_shape']) {
          case 'triangle': _drawTriangle(canvas, center, size, _poiPaint); break;
          case 'star': _drawStar(canvas, center, size, _poiPaint); break;
          default: canvas.drawCircle(center, size, _poiPaint);
        }
      }
    }

    if (markers.isEmpty) return;

    for (final marker in markers) {
      if (hiddenCategories.contains(marker.category)) continue;

      double mx = marker.x;
      double my = marker.y;

      if (pendingPoiContext != null && marker.category == pendingPoiContext!['category'] && marker.index == pendingPoiContext!['index']) {
         mx = (pendingPoiContext!['x'] as num).toDouble();
         my = (pendingPoiContext!['y'] as num).toDouble();
      }

      if (enableFrustumCulling && !visibleWorld.containsPoint(mx.round(), my.round())) continue;

      final center = Offset(mx, my);
      _poiPaint.color = Color(marker.colorValue);
      final size = marker.size / zoomScale;

      switch (marker.shape) {
        case 'triangle': _drawTriangle(canvas, center, size, _poiPaint); break;
        case 'star': _drawStar(canvas, center, size, _poiPaint); break;
        case 'circle':
        default: canvas.drawCircle(center, size, _poiPaint);
      }

      if (config.showPoiLabels && marker.label.isNotEmpty) {
        _drawLabel(canvas, marker.label, center, textDirection);
      }
    }
  }

  void _drawTriangle(Canvas canvas, Offset center, double size, Paint paint) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(size);
    canvas.drawPath(_baseTrianglePath, paint);
    canvas.restore();
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(size);
    canvas.drawPath(_baseStarPath, paint);
    canvas.restore();
  }

  void _drawLabel(Canvas canvas, String text, Offset worldPos, TextDirection direction) {
    final painter = cache.labels.getOrBuild(text, zoomScale, () {
      final p = TextPainter(
        text: TextSpan(text: text, style: TextStyle(
          color: Colors.white, 
          fontSize: config.poiLabelFontSize / zoomScale, 
          shadows: const [Shadow(blurRadius: 2, color: Colors.black)]
        )),
        textDirection: direction,
      );
      p.layout();
      return p;
    });
    painter.paint(canvas, worldPos + Offset(6 / zoomScale, -6 / zoomScale));
  }
}