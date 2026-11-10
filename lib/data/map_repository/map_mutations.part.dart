part of '../map_repository.dart';

mixin _MapMutations on ChangeNotifier, _HistoryManager, _GeometryEngine {
  
  EngineMapData get _currentData => (this as MapRepository)._mapData;
  set _currentData(EngineMapData val) => (this as MapRepository)._mapData = val;

  Future<ProvinceModel> cloneProvince(ProvinceModel source) async {
    final repo = this as MapRepository;
    _pushMapHistory(_currentData);

    final newId = repo._nextAvailableId();
    final newProv = ProvinceModel.fromPoints(
      id: newId,
      xs: source.pointsX.toList(),
      ys: source.pointsY.toList(),
      colorValue: randomProvinceColorValue(),
      geometryVersion: 0,
    );

    _currentData = _currentData.upsertProvince(newProv);
    repo._rebuildSpatialIndex();
    notifyListeners();
    await repo.storage.saveMapCache(_currentData);
    return newProv;
  }

  Future<ProvinceModel> commitProvince({
    int? id,
    required List<int> xs,
    required List<int> ys,
    int? colorValue,
    Set<int> clipTargets = const {},
    bool enableSnapping = true,
  }) async {
    final repo = this as MapRepository;
    _pushMapHistory(_currentData);
    
    final resolvedId = id ?? repo._nextAvailableId();
    final existingProv = id != null ? _currentData.findById(id) : null;
    
    final newProv = ProvinceModel.fromPoints(
      id: resolvedId, 
      xs: xs, 
      ys: ys, 
      colorValue: colorValue,
      geometryVersion: existingProv != null ? existingProv.geometryVersion + 1 : 0,
    );

    var newMap = _currentData.upsertProvince(newProv);

    if (clipTargets.isNotEmpty) {
      repo._setBusy(true); 
      await Future.delayed(const Duration(milliseconds: 50));
      
      try {
        final oldProvs = clipTargets.map((id) => newMap.findById(id)).whereType<ProvinceModel>().toList();
        
        if (oldProvs.isNotEmpty) {
          final clipResults = _GeometryWorker.runClipping(newProv, oldProvs, enableSnapping);
          
          for (final res in clipResults) {
            if (res.updatedProv == null) {
              newMap = newMap.removeProvince(res.id);
            } else {
              newMap = newMap.upsertProvince(res.updatedProv!);
            }
          }
        }
      } finally {
        repo._setBusy(false); 
      }
    }

    _currentData = newMap;
    repo._rebuildSpatialIndex();
    notifyListeners();
    await repo.storage.saveMapCache(_currentData);
    return newProv;
  }

  Future<void> updatePointInProvince(int provinceId, int pointIndex, int newX, int newY, {bool skipHistory = false}) async {
    final province = _currentData.findById(provinceId);
    if (province == null) return;
    
    if (!skipHistory) _pushMapHistory(_currentData);
    
    final oldBoundingBox = province.boundingBox;
    final updated = province.withPointMoved(pointIndex, newX, newY);
    _currentData = _currentData.upsertProvince(updated);
    
    final repo = this as MapRepository;
    repo._updateSpatialIndexFor(provinceId, oldBoundingBox);
    notifyListeners();
    await repo.storage.saveMapCache(_currentData);
  }

  Future<void> updateMultiplePoints(List<SelectedPointRef> pointsToUpdate, int deltaX, int deltaY) async {
    if (pointsToUpdate.isEmpty || (deltaX == 0 && deltaY == 0)) return;

    _pushMapHistory(_currentData);

    final byProvince = <int, List<SelectedPointRef>>{};
    for (final p in pointsToUpdate) {
      byProvince.putIfAbsent(p.provinceId, () => []).add(p);
    }

    final oldBoundingBoxes = <int, BoundingBox>{};
    final changed = <ProvinceModel>[];
    for (final entry in byProvince.entries) {
      final provId = entry.key;
      final pts = entry.value;
      final province = _currentData.findById(provId);
      if (province == null) continue;

      final newXs = Int32List.fromList(province.pointsX);
      final newYs = Int32List.fromList(province.pointsY);

      for (final pt in pts) {
        if (pt.pointIndex < newXs.length) {
          newXs[pt.pointIndex] += deltaX;
          newYs[pt.pointIndex] += deltaY;
        }
      }

      oldBoundingBoxes[provId] = province.boundingBox;
      changed.add(province.copyWith(pointsX: newXs, pointsY: newYs));
    }

    _currentData = _currentData.upsertMany(changed);
    final repo = this as MapRepository;
    repo._updateSpatialIndexForMany(oldBoundingBoxes);
    notifyListeners();
    await repo.storage.saveMapCache(_currentData);
  }

  Future<void> moveProvinces(Set<int> provinceIds, int deltaX, int deltaY) async {
    if (provinceIds.isEmpty || (deltaX == 0 && deltaY == 0)) return;

    _pushMapHistory(_currentData);

    final oldBoundingBoxes = <int, BoundingBox>{};
    final changed = <ProvinceModel>[];
    for (final id in provinceIds) {
      final province = _currentData.findById(id);
      if (province == null) continue;

      final newXs = Int32List(province.pointCount);
      final newYs = Int32List(province.pointCount);

      for (int i = 0; i < province.pointCount; i++) {
        newXs[i] = province.pointsX[i] + deltaX;
        newYs[i] = province.pointsY[i] + deltaY;
      }

      oldBoundingBoxes[id] = province.boundingBox;
      changed.add(province.copyWith(pointsX: newXs, pointsY: newYs));
    }

    _currentData = _currentData.upsertMany(changed);
    final repo = this as MapRepository;
    repo._updateSpatialIndexForMany(oldBoundingBoxes);
    notifyListeners();
    await repo.storage.saveMapCache(_currentData);
  }

  Future<void> subdivideEdge(int provinceId, int p1Index, int p2Index) async {
    final province = _currentData.findById(provinceId);
    if (province == null) return;

    int minIdx = math.min(p1Index, p2Index);
    int maxIdx = math.max(p1Index, p2Index);
    bool adjacent = (maxIdx - minIdx == 1) || (minIdx == 0 && maxIdx == province.pointCount - 1);
    if (!adjacent) return;

    int insertAt = (minIdx == 0 && maxIdx == province.pointCount - 1) ? province.pointCount : maxIdx;
    int midX = (province.pointsX[p1Index] + province.pointsX[p2Index]) ~/ 2;
    int midY = (province.pointsY[p1Index] + province.pointsY[p2Index]) ~/ 2;

    _pushMapHistory(_currentData);
    final oldBoundingBox = province.boundingBox;
    final newXs = province.pointsX.toList()..insert(insertAt, midX);
    final newYs = province.pointsY.toList()..insert(insertAt, midY);

    final updated = province.copyWith(pointsX: Int32List.fromList(newXs), pointsY: Int32List.fromList(newYs));
    _currentData = _currentData.upsertProvince(updated);
    
    final repo = this as MapRepository;
    repo._updateSpatialIndexFor(provinceId, oldBoundingBox);
    notifyListeners();
    await repo.storage.saveMapCache(_currentData);
  }

  Future<void> subdivideEdges(List<MapEntry<int, List<int>>> edges) async {
    if (edges.isEmpty) return;
    _pushMapHistory(_currentData);

    final oldBoundingBoxes = <int, BoundingBox>{};
    final changed = <ProvinceModel>[];
    for (final edge in edges) {
      final provinceId = edge.key;
      final p1Index = edge.value[0];
      final p2Index = edge.value[1];

      final province = _currentData.findById(provinceId);
      if (province == null) continue;

      int minIdx = math.min(p1Index, p2Index);
      int maxIdx = math.max(p1Index, p2Index);
      bool adjacent = (maxIdx - minIdx == 1) || (minIdx == 0 && maxIdx == province.pointCount - 1);
      if (!adjacent) continue;

      int insertAt = (minIdx == 0 && maxIdx == province.pointCount - 1) ? province.pointCount : maxIdx;
      int midX = (province.pointsX[p1Index] + province.pointsX[p2Index]) ~/ 2;
      int midY = (province.pointsY[p1Index] + province.pointsY[p2Index]) ~/ 2;

      final newXs = province.pointsX.toList()..insert(insertAt, midX);
      final newYs = province.pointsY.toList()..insert(insertAt, midY);

      oldBoundingBoxes[provinceId] = province.boundingBox;
      changed.add(province.copyWith(pointsX: Int32List.fromList(newXs), pointsY: Int32List.fromList(newYs)));
    }

    _currentData = _currentData.upsertMany(changed);
    final repo = this as MapRepository;
    repo._updateSpatialIndexForMany(oldBoundingBoxes);
    notifyListeners();
    await repo.storage.saveMapCache(_currentData);
  }

  Future<void> deletePointInProvince(int provinceId, int pointIndex) async {
    final province = _currentData.findById(provinceId);
    if (province == null || province.pointCount <= 3) return;
    
    _pushMapHistory(_currentData);
    
    final oldBoundingBox = province.boundingBox;
    final newXs = province.pointsX.toList()..removeAt(pointIndex);
    final newYs = province.pointsY.toList()..removeAt(pointIndex);
    final updated = province.copyWith(pointsX: Int32List.fromList(newXs), pointsY: Int32List.fromList(newYs));
    
    _currentData = _currentData.upsertProvince(updated);
    
    final repo = this as MapRepository;
    repo._updateSpatialIndexFor(provinceId, oldBoundingBox);
    notifyListeners();
    await repo.storage.saveMapCache(_currentData);
  }

  Future<void> deleteProvinces(Set<int> provinceIds) async {
    _pushMapHistory(_currentData);
    _currentData = _currentData.removeMany(provinceIds);
    
    final repo = this as MapRepository;
    repo._rebuildSpatialIndex();
    repo.notifyListeners();
    await repo.storage.saveMapCache(_currentData);
  }

  Future<MergeContoursData?> calculateMergeContours(Set<int> provinceIds) async {
    final provincesToMerge = provinceIds.map((id) => _currentData.findById(id)).whereType<ProvinceModel>().toList();
    if (provincesToMerge.length < 2) return null;

    final repo = this as MapRepository;
    repo._setBusy(true); 
    await Future.delayed(const Duration(milliseconds: 50));

    MergeContoursData? result;
    try {
      result = _GeometryWorker.runBooleanMergePhaseA(provincesToMerge);
    } catch (e) {
      _mergeLog('Erro no Merge Fase A: $e');
    } finally {
      repo._setBusy(false); 
    }
    
    return result;
  }

  ProvinceModel buildMergeProvince(MergeContoursData data, int pathChoice) {
     return _GeometryWorker.runBooleanMergePhaseB(data, pathChoice);
  }

  Future<void> applyMerge(ProvinceModel newProv, Set<int> originalIds) async {
    _pushMapHistory(_currentData); 

    var newMap = _currentData;
    for (final id in originalIds) { newMap = newMap.removeProvince(id); }
    newMap = newMap.upsertProvince(newProv);
    
    _currentData = newMap;
    final repo = this as MapRepository;
    repo._rebuildSpatialIndex();
    repo.notifyListeners();
    await repo.storage.saveMapCache(_currentData);
  }
}