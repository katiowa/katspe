part of 'editor_screen.dart';

mixin _PointManipulationLogic on _MapEditorScreenStateBase, _SelectionLogic {

  void _tapSelectOrMove(Offset localPosition, MapPainter painter) {
    final world = painter.screenToWorld(localPosition);
    String? hitPropId;

    for (final prop in _propsController.props.reversed) {
      if (prop.isLocked || !prop.isVisible) continue;

      bool inside = false;
      final poly = prop.corners;
      int j = poly.length - 1;
      
      for (int i = 0; i < poly.length; i++) {
        if ((poly[i].dy > world.dy) != (poly[j].dy > world.dy) &&
            world.dx < (poly[j].dx - poly[i].dx) * (world.dy - poly[i].dy) / (poly[j].dy - poly[i].dy) + poly[i].dx) {
          inside = !inside;
        }
        j = i;
      }

      if (inside) {
        hitPropId = prop.id;
        break;
      }
    }

    if (hitPropId != null) {
      setState(() {
        _selectedPropId = hitPropId;
        _selectedProvinceIds.clear();
        _pendingPoiEditorContext = null;
      });
      return;
    }

    final province = painter.resolveProvinceAt(localPosition);
    setState(() {
      _selectedPropId = null;
      _pendingPoiEditorContext = null;

      if (province != null) {
        if (_isShiftActive.value) {
          if (_selectedProvinceIds.contains(province.id)) {
            _selectedProvinceIds.remove(province.id);
          } else {
            _selectedProvinceIds.add(province.id);
          }
        } else {
          if (_selectedProvinceIds.length == 1 && _selectedProvinceIds.first == province.id) {
            _selectedProvinceIds.clear();
          } else {
            _selectedProvinceIds = {province.id};
          }
        }
      } else {
        if (!_isShiftActive.value) _selectedProvinceIds.clear();
      }
    });
  }

  void _tapEditPoint(Offset localPosition, MapPainter painter) {
    final world = painter.screenToWorld(localPosition);
    final maxDist = _config.pointPickRadiusScreen / _zoom.value;
    final maxDistSq = maxDist * maxDist;

    final hits = findPointsNear(
      provinces: _mapRepo.mapData.provinces,
      spatialIndex: _enableFrustumCulling.value ? _mapRepo.spatialIndex : null,
      worldX: world.dx, worldY: world.dy, maxWorldDistance: maxDist, priorityProvinceIds: _selectedProvinceIds,
    );

    if (hits.isEmpty) {
      if (!_isShiftActive.value) {
        setState(() {
          _currentHitPoints.clear(); 
          _currentHitIndex = 0;
          _selectedPoints.clear(); 
          _originalPointCoords.clear();
          _updateSubdivisionCache();
          _syncFastSelectedPoints();
        });
      }
      return;
    }

    bool clickedSameCluster = false;
    if (_currentHitPoints.isNotEmpty) {
      final lastHit = _currentHitPoints[_currentHitIndex];
      if ((Offset(lastHit.worldX.toDouble(), lastHit.worldY.toDouble()) - world).distanceSquared <= maxDistSq) {
        clickedSameCluster = true;
      }
    }

    setState(() {
      if (clickedSameCluster) {
        _currentHitIndex = (_currentHitIndex + 1) % _currentHitPoints.length;
        final nextHit = _currentHitPoints[_currentHitIndex];

        if (_isShiftActive.value) {
          if (!_selectedPoints.any((p) => p.provinceId == nextHit.provinceId && p.pointIndex == nextHit.pointIndex)) {
            _selectedPoints.add(nextHit);
            _originalPointCoords['${nextHit.provinceId}_${nextHit.pointIndex}'] = Offset(nextHit.worldX.toDouble(), nextHit.worldY.toDouble());
          }
        } else {
          _selectedPoints = [nextHit];
          _originalPointCoords.clear();
          _originalPointCoords['${nextHit.provinceId}_${nextHit.pointIndex}'] = Offset(nextHit.worldX.toDouble(), nextHit.worldY.toDouble());
        }
      } else {
        _currentHitPoints = hits;
        _currentHitIndex = 0;
        final firstHit = hits.first;

        if (_isShiftActive.value) {
          if (!_selectedPoints.any((p) => p.provinceId == firstHit.provinceId && p.pointIndex == firstHit.pointIndex)) {
            _selectedPoints.add(firstHit);
            _originalPointCoords['${firstHit.provinceId}_${firstHit.pointIndex}'] = Offset(firstHit.worldX.toDouble(), firstHit.worldY.toDouble());
          }
        } else {
          _selectedPoints = [firstHit];
          _originalPointCoords.clear();
          _originalPointCoords['${firstHit.provinceId}_${firstHit.pointIndex}'] = Offset(firstHit.worldX.toDouble(), firstHit.worldY.toDouble());
        }
      }
      _updateSubdivisionCache();
      _syncFastSelectedPoints();
    });
  }

  void _handleRightClick(Offset localPosition, MapPainter painter) {
    final world = painter.screenToWorld(localPosition);
    
    setState(() {
      if (_tool == EditorTool.editPoint && _selectedPoints.isNotEmpty) {
        final maxDist = _config.pointPickRadiusScreen / _zoom.value;
        final maxDistSq = maxDist * maxDist;
        int toRemove = -1;
        double minDSq = double.infinity;
        for (int i = 0; i < _selectedPoints.length; i++) {
          final p = _selectedPoints[i];
          final dSq = (Offset(p.worldX.toDouble(), p.worldY.toDouble()) - world).distanceSquared;
          if (dSq <= maxDistSq && dSq < minDSq) {
            minDSq = dSq;
            toRemove = i;
          }
        }
        if (toRemove != -1) {
          _selectedPoints.removeAt(toRemove);
          _updateSubdivisionCache();
          _syncFastSelectedPoints();
        }
      } else if (_tool == EditorTool.select || _tool == EditorTool.moveProvince) {
        _selectedPropId = null;
        final province = painter.resolveProvinceAt(localPosition);
        if (province != null && _selectedProvinceIds.contains(province.id)) {
          _selectedProvinceIds.remove(province.id);
        }
      }
    });
  }
}