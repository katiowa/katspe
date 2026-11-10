import 'dart:ui';

/// Central, injectable configuration for the Map Engine.
///
/// ARCHITECTURE RULE: no color, scale, file path or numeric limit should
/// be written directly inside engine logic. All logic receives a
/// [MapEngineConfig] instance through its constructor. To customize
/// engine behaviour, create a new instance of this class — never edit the
/// engine files themselves.
class MapEngineConfig {
  // --- Storage (engine_storage.dart) ---
  final String cacheDirectoryName;
  final String cacheFileName;

  // --- Spatial indexing (spatial_grid.dart) ---
  final int spatialGridCellSize;

  // --- Province rendering (map_painter.dart) ---
  final int provinceFillAlpha;
  final Color selectedFillColor;
  final int selectedFillAlpha;
  final Color borderColor;
  final double borderWidth;
  final Color selectedBorderColor;
  final double selectedBorderWidth;
  final Color backgroundColor;
  final Color pointHandleColor;
  final double pointHandleRadius;
  final bool showPointHandles;

  // --- Background image (background_image_controller.dart) ---
  final double backgroundOpacity;

  // --- POIs: cities, mountains, wonders ---
  final double poiLabelFontSize;
  final bool showPoiLabels;

  // --- Point editing (point_edit_controller.dart) ---
  /// Pick radius (in SCREEN pixels, independent of zoom) for considering
  /// a click "close enough" to an existing vertex.
  final double pointPickRadiusScreen;

  /// Distance (in WORLD units) each arrow-key press moves the selected
  /// point.
  final double pointNudgeStep;

  // --- Camera / navigation ---
  final double minZoom;
  final double maxZoom;
  final double zoomStep;

  const MapEngineConfig({
    // Renamed from the old `aoh2_engine_cache` default: the Core must not
    // carry the identity of any single converter/target format — see the
    // architecture's "Zero Hardcode" rule. Converters live entirely under
    // `engine/converters/<name>/`; the render cache is a Core concern and
    // stays name-agnostic.
    this.cacheDirectoryName = 'engine_cache',
    // The real format is a binary FlatBuffer (see
    // `EngineStorageManager._buildFlatBuffer`), never JSON — the file
    // extension reflects that.
    this.cacheFileName = 'map_cache.bin',
    this.spatialGridCellSize = 256,
    this.provinceFillAlpha = 120,
    this.selectedFillColor = const Color(0xFFFFC107),
    this.selectedFillAlpha = 200,
    this.borderColor = const Color(0xFF14151A),
    this.borderWidth = 0.6,
    this.selectedBorderColor = const Color(0xFFFFFFFF),
    this.selectedBorderWidth = 1.4,
    this.backgroundColor = const Color(0xFF1B1D23),
    this.pointHandleColor = const Color(0xFFFF5252),
    this.pointHandleRadius = 2.5,
    this.showPointHandles = false,
    this.backgroundOpacity = 1.0,
    this.poiLabelFontSize = 10.0,
    this.showPoiLabels = true,
    this.pointPickRadiusScreen = 12.0,
    this.pointNudgeStep = 2.0,
    this.minZoom = 0.05,
    this.maxZoom = 40.0,
    this.zoomStep = 0.1,
  });

  MapEngineConfig copyWith({
    String? cacheDirectoryName,
    String? cacheFileName,
    int? spatialGridCellSize,
    int? provinceFillAlpha,
    Color? selectedFillColor,
    int? selectedFillAlpha,
    Color? borderColor,
    double? borderWidth,
    Color? selectedBorderColor,
    double? selectedBorderWidth,
    Color? backgroundColor,
    Color? pointHandleColor,
    double? pointHandleRadius,
    bool? showPointHandles,
    double? backgroundOpacity,
    double? poiLabelFontSize,
    bool? showPoiLabels,
    double? pointPickRadiusScreen,
    double? pointNudgeStep,
    double? minZoom,
    double? maxZoom,
    double? zoomStep,
  }) {
    return MapEngineConfig(
      cacheDirectoryName: cacheDirectoryName ?? this.cacheDirectoryName,
      cacheFileName: cacheFileName ?? this.cacheFileName,
      spatialGridCellSize: spatialGridCellSize ?? this.spatialGridCellSize,
      provinceFillAlpha: provinceFillAlpha ?? this.provinceFillAlpha,
      selectedFillColor: selectedFillColor ?? this.selectedFillColor,
      selectedFillAlpha: selectedFillAlpha ?? this.selectedFillAlpha,
      borderColor: borderColor ?? this.borderColor,
      borderWidth: borderWidth ?? this.borderWidth,
      selectedBorderColor: selectedBorderColor ?? this.selectedBorderColor,
      selectedBorderWidth: selectedBorderWidth ?? this.selectedBorderWidth,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      pointHandleColor: pointHandleColor ?? this.pointHandleColor,
      pointHandleRadius: pointHandleRadius ?? this.pointHandleRadius,
      showPointHandles: showPointHandles ?? this.showPointHandles,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      poiLabelFontSize: poiLabelFontSize ?? this.poiLabelFontSize,
      showPoiLabels: showPoiLabels ?? this.showPoiLabels,
      pointPickRadiusScreen: pointPickRadiusScreen ?? this.pointPickRadiusScreen,
      pointNudgeStep: pointNudgeStep ?? this.pointNudgeStep,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      zoomStep: zoomStep ?? this.zoomStep,
    );
  }
}
