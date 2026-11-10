import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals, setEquals;

import '../../engine/engine_config.dart';
import '../../models/map_marker.dart';
import '../point_edit_controller.dart';
import '../../models/province.dart';
import '../../engine/spatial_grid.dart';
import '../../models/prop_model.dart';
import 'camera_transform.dart';
import 'map_painter_cache.dart';

part 'map_painter/background_painter.part.dart';
part 'map_painter/props_painter.part.dart';
part 'map_painter/provinces_painter.part.dart';
part 'map_painter/pois_painter.part.dart';
part 'map_painter/interaction_logic.part.dart';

abstract class MapPainterBase extends CustomPainter {
  final List<ProvinceModel> provinces;
  final SpatialGrid? spatialIndex;
  final Offset panOffset;
  final double zoomScale;
  final Set<int> selectedProvinceIds;
  final MapEngineConfig config;

  final List<Offset>? provinceInProgress;
  final Color? provinceInProgressColor;
  final ui.Image? backgroundImage;

  final List<MapMarker> markers;
  final MarkerSpatialIndex? markerIndex;
  final Set<String> hiddenCategories;
  
  final Map<String, dynamic>? pendingPoiContext;
  final List<Map<String, dynamic>> poiCategories;

  final List<SelectedPointRef> selectedPoints;
  final Set<(int, int)> fastSelectedPoints;

  final bool enableFrustumCulling;
  final double cullingMargin;
  final bool showAllPoints;

  final bool showProvinces;
  final bool showXRay;
  final bool showBackground;

  final SelectedPointRef? draggingPoint;
  final Offset? dragWorldPosition;
  final Offset provinceDragDelta;

  final List<PropModel> props;
  final Map<String, ui.Image> propImages;
  final String? selectedPropId;

  final MapPainterCache cache;

  MapPainterBase({
    required this.provinces,
    required this.panOffset,
    required this.zoomScale,
    required this.config,
    required this.cache,
    this.spatialIndex,
    this.selectedProvinceIds = const {},
    this.provinceInProgress,
    this.provinceInProgressColor,
    this.backgroundImage,
    this.markers = const [],
    this.markerIndex,
    this.hiddenCategories = const {},
    this.pendingPoiContext,
    this.poiCategories = const [],
    this.selectedPoints = const [],
    this.fastSelectedPoints = const {},
    this.enableFrustumCulling = true,
    this.cullingMargin = 0.5,
    this.showAllPoints = false,
    this.showProvinces = true,
    this.showXRay = false,
    this.showBackground = true,
    this.draggingPoint,
    this.dragWorldPosition,
    this.provinceDragDelta = Offset.zero,
    this.props = const [],
    this.propImages = const {},
    this.selectedPropId,
  });

  late final CameraTransform _camera = CameraTransform(panOffset: panOffset, zoomScale: zoomScale);

  late final Paint _bgPaint = Paint()..color = config.backgroundColor;
  late final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  late final Paint _borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = config.borderColor
    ..strokeWidth = config.borderWidth / zoomScale;
  late final Paint _selectedBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = config.selectedBorderColor
    ..strokeWidth = config.selectedBorderWidth / zoomScale;
  late final Paint _xRayPaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = Colors.pinkAccent
    ..strokeWidth = 3.0 / zoomScale;
  late final Paint _poiPaint = Paint();
  late final Paint _handlePaint = Paint()
    ..color = config.pointHandleColor
    ..strokeCap = ui.StrokeCap.round
    ..strokeWidth = (config.pointHandleRadius * 2) / zoomScale;
  late final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = config.selectedFillColor
    ..strokeWidth = 2 / zoomScale;
  late final Paint _edgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = Colors.greenAccent
    ..strokeWidth = 4 / zoomScale;

  late final Path _baseTrianglePath = _buildBaseTriangle();
  late final Path _baseStarPath = _buildBaseStar();

  Path _buildBaseTriangle() {
    return Path()..moveTo(0, -1)..lineTo(-0.85, 0.7)..lineTo(0.85, 0.7)..close();
  }

  Path _buildBaseStar() {
    const points = 5;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? 1.0 : 0.45;
      final angle = (i * math.pi / points) - math.pi / 2;
      final x = radius * math.cos(angle);
      final y = radius * math.sin(angle);
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    path.close();
    return path;
  }

  Offset screenToWorld(Offset localPosition) => _camera.screenToWorld(localPosition);
  Offset worldToScreen(Offset worldPosition) => _camera.worldToScreen(worldPosition);

  BoundingBox _visibleWorldBounds(Size size) {
    final left = panOffset.dx;
    final top = panOffset.dy;
    final w = size.width / zoomScale;
    final h = size.height / zoomScale;
    final marginW = w * cullingMargin;
    final marginH = h * cullingMargin;

    return BoundingBox(
      minX: (left - marginW).floor(),
      minY: (top - marginH).floor(),
      maxX: (left + w + marginW).ceil(),
      maxY: (top + h + marginH).ceil(),
    );
  }
}

class MapPainter extends MapPainterBase
    with
        _BackgroundPainter,
        _PropsPainter,
        _ProvincesPainter,
        _PoisPainter,
        _InteractionLogic {
          
  MapPainter({
    required super.provinces,
    required super.panOffset,
    required super.zoomScale,
    required super.config,
    required super.cache,
    super.spatialIndex,
    super.selectedProvinceIds = const {},
    super.provinceInProgress,
    super.provinceInProgressColor,
    super.backgroundImage,
    super.markers = const [],
    super.markerIndex,
    super.hiddenCategories = const {},
    super.pendingPoiContext,
    super.poiCategories = const [],
    super.selectedPoints = const [],
    super.fastSelectedPoints = const {},
    super.enableFrustumCulling = true,
    super.cullingMargin = 0.5,
    super.showAllPoints = false,
    super.showProvinces = true,
    super.showXRay = false,
    super.showBackground = true,
    super.draggingPoint,
    super.dragWorldPosition,
    super.provinceDragDelta = Offset.zero,
    super.props = const [],
    super.propImages = const {},
    super.selectedPropId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPaint(_bgPaint);

    final visibleWorld = _visibleWorldBounds(size);
    final Iterable<int> candidateIndices = (spatialIndex != null && enableFrustumCulling)
        ? spatialIndex!.queryRegion(visibleWorld)
        : Iterable<int>.generate(provinces.length);

    canvas.save();
    canvas.scale(zoomScale);
    canvas.translate(-panOffset.dx, -panOffset.dy);

    if (showBackground) drawBackgroundLayer(canvas);

    if (showProvinces) {
      drawProvincesLayer(canvas, visibleWorld, candidateIndices);
    }

    if (showXRay && showProvinces) drawXRayLayer(canvas, candidateIndices);

    // Props acima das províncias, mas abaixo dos POIs e da UI em progresso
    drawPropsLayer(canvas, visibleWorld);

    drawPoisLayer(canvas, visibleWorld);

    if (provinceInProgress != null && provinceInProgress!.length > 1) {
      drawInProgressLayer(canvas);
    }

    if (selectedPoints.isNotEmpty && draggingPoint == null) {
      drawSelectedPointHighlight(canvas);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MapPainter oldDelegate) {
    return !identical(provinces, oldDelegate.provinces) ||
        !identical(spatialIndex, oldDelegate.spatialIndex) ||
        panOffset != oldDelegate.panOffset ||
        zoomScale != oldDelegate.zoomScale ||
        !setEquals(selectedProvinceIds, oldDelegate.selectedProvinceIds) ||
        !listEquals(provinceInProgress, oldDelegate.provinceInProgress) ||
        provinceInProgressColor != oldDelegate.provinceInProgressColor ||
        !identical(backgroundImage, oldDelegate.backgroundImage) ||
        !identical(markers, oldDelegate.markers) ||
        !setEquals(hiddenCategories, oldDelegate.hiddenCategories) ||
        !listEquals(selectedPoints, oldDelegate.selectedPoints) ||
        !setEquals(fastSelectedPoints, oldDelegate.fastSelectedPoints) ||
        pendingPoiContext != oldDelegate.pendingPoiContext ||
        enableFrustumCulling != oldDelegate.enableFrustumCulling ||
        cullingMargin != oldDelegate.cullingMargin ||
        showAllPoints != oldDelegate.showAllPoints ||
        showProvinces != oldDelegate.showProvinces ||
        showXRay != oldDelegate.showXRay ||
        showBackground != oldDelegate.showBackground ||
        draggingPoint != oldDelegate.draggingPoint ||
        dragWorldPosition != oldDelegate.dragWorldPosition ||
        provinceDragDelta != oldDelegate.provinceDragDelta ||
        !identical(props, oldDelegate.props) ||
        !identical(propImages, oldDelegate.propImages) ||
        selectedPropId != oldDelegate.selectedPropId;
  }
}