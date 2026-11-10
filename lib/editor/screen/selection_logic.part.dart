part of 'editor_screen.dart';

mixin _SelectionLogic on _MapEditorScreenStateBase {

  void _syncFastSelectedPoints() {
    _fastSelectedPoints = {
      for (final sp in _selectedPoints) (sp.provinceId, sp.pointIndex)
    };
  }

  void _updateSubdivisionCache() {
    _validEdgesToSubdivide.clear();
    if (_selectedPoints.isEmpty) return;

    final byProv = <int, List<SelectedPointRef>>{};
    for (final sp in _selectedPoints) {
      byProv.putIfAbsent(sp.provinceId, () => []).add(sp);
    }

    for (final entry in byProv.entries) {
      if (entry.value.length == 2) {
        final prov = _mapRepo.mapData.findById(entry.key);
        if (prov != null) {
          int i1 = entry.value[0].pointIndex;
          int i2 = entry.value[1].pointIndex;
          int minIdx = math.min(i1, i2);
          int maxIdx = math.max(i1, i2);
          if ((maxIdx - minIdx == 1) || (minIdx == 0 && maxIdx == prov.pointCount - 1)) {
            _validEdgesToSubdivide.add(MapEntry(prov.id, [i1, i2]));
          }
        }
      }
    }
  }

  void _onChanged() {
    setState(() {
      _selectedProvinceIds.removeWhere((id) => _mapRepo.mapData.findById(id) == null);

      final oldPtsLen = _selectedPoints.length;
      _selectedPoints.removeWhere((sp) {
        final p = _mapRepo.mapData.findById(sp.provinceId);
        return p == null || sp.pointIndex >= p.pointCount;
      });

      if (oldPtsLen != _selectedPoints.length) {
        _updateSubdivisionCache();
      }

      if (_selectedPoints.isEmpty) { _currentHitPoints.clear(); }
      _syncFastSelectedPoints();
    });
    _painterCache.paths.prune(_mapRepo.mapData.provinces.map((p) => p.id).toSet());
  }

  void _handleDelete() {
    if (_pointsInProgress.isNotEmpty) {
      setState(() {
        _pointsInProgress.removeLast();
      });
      return;
    }

    if (_tool == EditorTool.createProvincePoint) {
      return;
    }

    if (_selectedPoints.isNotEmpty) {
      final toDelete = List<SelectedPointRef>.from(_selectedPoints);
      toDelete.sort((a, b) => b.pointIndex.compareTo(a.pointIndex));

      for (final sp in toDelete) {
        _mapRepo.deletePointInProvince(sp.provinceId, sp.pointIndex);
      }
      setState(() {
        _selectedPoints.clear();
        _updateSubdivisionCache();
        _syncFastSelectedPoints();
      });
    } 
    else if (_selectedProvinceIds.isNotEmpty) {
      _mapRepo.deleteProvinces(_selectedProvinceIds);
      setState(() => _selectedProvinceIds.clear());
    } 
    else if (_selectedPropId != null) {
      _propsController.removeProp(_selectedPropId!);
      setState(() => _selectedPropId = null);
    }
  }

  void _copyProvince() {
    if (_tool == EditorTool.editPoint || _tool == EditorTool.createProvincePoint) return;
    if (_selectedProvinceIds.length == 1) {
      _clipboardProvince = _mapRepo.mapData.findById(_selectedProvinceIds.first);
    }
  }

  Future<void> _pasteProvince() async {
    if (_tool == EditorTool.editPoint || _tool == EditorTool.createProvincePoint) return;
    if (_clipboardProvince != null) {
      final newProv = await _mapRepo.cloneProvince(_clipboardProvince!);
      setState(() {
        _selectedProvinceIds = {newProv.id};
        _tool = EditorTool.moveProvince;
        _selectedPoints.clear();
        _updateSubdivisionCache();
        _pendingPoiEditorContext = null;
        _currentHitPoints.clear();
        _syncFastSelectedPoints();
      });
    }
  }

  void _cloneSelectedProvince() {
    _copyProvince();
    _pasteProvince();
  }

  Offset _applySnapping(Offset worldPos) {
    if (!_enableSnapping.value) return worldPos;

    final maxDist = _config.pointPickRadiusScreen / _zoom.value;
    final hits = findPointsNear(
      provinces: _mapRepo.mapData.provinces,
      spatialIndex: _enableFrustumCulling.value ? _mapRepo.spatialIndex : null,
      worldX: worldPos.dx,
      worldY: worldPos.dy,
      maxWorldDistance: maxDist,
      priorityProvinceIds: _selectedProvinceIds,
    );

    for (final hit in hits) {
      if (!_selectedPoints.any((sp) => sp.provinceId == hit.provinceId && sp.pointIndex == hit.pointIndex)) {
        return Offset(hit.worldX.toDouble(), hit.worldY.toDouble());
      }
    }

    return worldPos;
  }

  void _cancelPointMoves() {
    for (final sp in _selectedPoints) {
      final orig = _originalPointCoords['${sp.provinceId}_${sp.pointIndex}'];
      if (orig != null) {
         _mapRepo.updatePointInProvince(sp.provinceId, sp.pointIndex, orig.dx.round(), orig.dy.round(), skipHistory: true);
      }
    }
    setState(() {
      _selectedPoints.clear();
      _currentHitPoints.clear();
      _updateSubdivisionCache();
      _syncFastSelectedPoints();
    });
  }

  void _applyBoxSelection(MapPainter painter) {
    if (_boxSelectStart.value == null || _boxSelectEnd.value == null) return;

    final w1 = painter.screenToWorld(_boxSelectStart.value!);
    final w2 = painter.screenToWorld(_boxSelectEnd.value!);
    final rect = Rect.fromPoints(w1, w2);

    final bbox = BoundingBox(
      minX: rect.left.floor(), minY: rect.top.floor(),
      maxX: rect.right.ceil(), maxY: rect.bottom.ceil()
    );

    final candidates = (_enableFrustumCulling.value && _mapRepo.spatialIndex != null)
        ? _mapRepo.spatialIndex!.queryRegion(bbox)
        : Iterable<int>.generate(_mapRepo.mapData.provinces.length);

    final List<SelectedPointRef> inside = [];
    for (final idx in candidates) {
      final prov = _mapRepo.mapData.provinces[idx];
      if (!prov.boundingBox.intersects(bbox)) continue;

      for (int i = 0; i < prov.pointCount; i++) {
        if (rect.contains(Offset(prov.pointsX[i].toDouble(), prov.pointsY[i].toDouble()))) {
          inside.add(SelectedPointRef(
            provinceId: prov.id,
            pointIndex: i,
            worldX: prov.pointsX[i],
            worldY: prov.pointsY[i]
          ));
        }
      }
    }

    setState(() {
      if (_tool == EditorTool.editPoint) {
        for (final p in inside) {
          if (!_selectedPoints.any((sp) => sp.provinceId == p.provinceId && p.pointIndex == p.pointIndex)) {
            _selectedPoints.add(p);
            _originalPointCoords['${p.provinceId}_${p.pointIndex}'] = Offset(p.worldX.toDouble(), p.worldY.toDouble());
          }
        }
        _updateSubdivisionCache();
        _syncFastSelectedPoints();
      } else if (_tool == EditorTool.createProvincePoint) {
        for (final p in inside) {
          _pointsInProgress.add(Offset(p.worldX.toDouble(), p.worldY.toDouble()));
        }
      }
    });
  }
}