import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../api/lua/lua_converter_session.dart';
import '../core/engine_context.dart';
import '../editor/point_edit_controller.dart';
import '../engine/engine_config.dart';
import '../engine/engine_storage.dart';
import '../engine/spatial_grid.dart';
import '../models/province.dart';

part 'map_repository/history_manager.part.dart';
part 'map_repository/geometry_engine.part.dart';
part 'map_repository/lua_interop.part.dart';
part 'map_repository/map_mutations.part.dart';

/// O Entry Point de Dados do Mapa. 
/// Agora a classe principal é minúscula, servindo apenas como uma fachada
/// enquanto a lógica pesada vive em módulos especializados (parts).
class MapRepository extends ChangeNotifier 
    with 
      _HistoryManager, 
      _GeometryEngine, 
      _LuaInterop, 
      _MapMutations {
        
  final MapEngineConfig config;
  final EngineStorageManager storage;

  EngineMapData _mapData = EngineMapData.empty();
  SpatialGrid? _spatialIndex;
  bool _isBusy = false;

  MapRepository({required this.config}) : storage = EngineStorageManager(config: config);

  EngineMapData get mapData => _mapData;
  SpatialGrid? get spatialIndex => _spatialIndex;
  bool get isBusy => _isBusy;
  bool get hasMap => _mapData.provinces.isNotEmpty;

  void _setBusy(bool value) { 
    _isBusy = value; 
    notifyListeners(); 
  }

  void _rebuildSpatialIndex() {
    _spatialIndex = SpatialGrid(provinces: _mapData.provinces, cellSize: config.spatialGridCellSize);
  }

  void _updateSpatialIndexFor(int provinceId, BoundingBox oldBoundingBox) {
    final grid = _spatialIndex;
    if (grid == null) return;
    final index = _mapData.indexOf(provinceId);
    if (index == null) {
      _rebuildSpatialIndex();
      return;
    }
    grid.provinces = _mapData.provinces;
    grid.updateProvinceAt(index, oldBoundingBox);
  }

  void _updateSpatialIndexForMany(Map<int, BoundingBox> oldBoundingBoxes) {
    if (oldBoundingBoxes.isEmpty) return;
    final grid = _spatialIndex;
    if (grid == null) return;
    grid.provinces = _mapData.provinces;
    for (final entry in oldBoundingBoxes.entries) {
      final index = _mapData.indexOf(entry.key);
      if (index == null) {
        _rebuildSpatialIndex();
        return;
      }
      grid.updateProvinceAt(index, entry.value);
    }
  }

  int _nextAvailableId() {
    if (_mapData.provinces.isEmpty) return 0;
    return _mapData.provinces.map((p) => p.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<bool> loadFromCache() async {
    _setBusy(true);
    final cached = await storage.loadMapCache();
    if (cached != null) {
      _mapData = cached;
      _rebuildSpatialIndex();
    }
    _setBusy(false);
    return cached != null;
  }

  void clearMap() {
    _mapData = EngineMapData.empty();
    _clearHistory();
    _spatialIndex = null;
    notifyListeners();
  }
}