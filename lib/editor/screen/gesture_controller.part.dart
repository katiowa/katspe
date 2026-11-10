part of 'editor_screen.dart';

mixin _GestureController on _MapEditorScreenStateBase, _SelectionLogic, _PointManipulationLogic, _CoreInteractionLogic {
  
  Offset? _lastProvSnapRawWorld;
  Offset _lastProvSnapOffset = Offset.zero;
  
  Offset? _lastPointSnapRawWorld;
  Offset _lastPointSnapTarget = Offset.zero;

  late final Map<EditorTool, void Function(ScaleStartDetails, MapPainter)> _scaleStartDispatch = {
    EditorTool.select: _scaleStartSelect,
    EditorTool.moveProvince: _scaleStartMoveProvince,
    EditorTool.editPoint: _scaleStartEditPoint,
  };

  late final Map<EditorTool, void Function(ScaleUpdateDetails, MapPainter)> _scaleUpdateDispatch = {
    EditorTool.select: _scaleUpdateSelect,
    EditorTool.moveProvince: _scaleUpdateMoveProvince,
    EditorTool.editPoint: _scaleUpdateEditPoint,
  };

  late final Map<EditorTool, void Function(ScaleEndDetails, MapPainter)> _scaleEndDispatch = {
    EditorTool.select: _scaleEndSelect,
    EditorTool.moveProvince: _scaleEndMoveProvince,
    EditorTool.editPoint: _scaleEndEditPoint,
  };

  void _onPointerDown(PointerDownEvent event, MapPainter painter) {
    if (!_canvasFocusNode.hasFocus) {
      _canvasFocusNode.requestFocus();
    }

    if (event.buttons == kSecondaryButton) {
      _handleRightClick(event.localPosition, painter);
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final double scrollFactor = event.scrollDelta.dy / 500.0;
      final double zoomMultiplier = 1.0 - scrollFactor; 
      
      final oldZoom = _zoom.value;
      final newZoom = (oldZoom * zoomMultiplier).clamp(_config.minZoom, _config.maxZoom);
      
      if (oldZoom != newZoom) {
        _zoomAt(event.localPosition, oldZoom, newZoom);
      }
    }
  }

  void _zoomAt(Offset screenPos, double oldZoom, double newZoom) {
    final worldPos = screenPos / oldZoom + _panOffset.value;
    _panOffset.value = worldPos - screenPos / newZoom;
    _zoom.value = newZoom;
  }

  void _onScaleStart(ScaleStartDetails details, MapPainter painter) {
    if (_isShiftActive.value && (_tool == EditorTool.editPoint || _tool == EditorTool.createProvincePoint)) {
      _boxSelectStart.value = details.localFocalPoint;
      _boxSelectEnd.value = details.localFocalPoint;
      return;
    }

    _baseZoomForPinch = _zoom.value;
    _scaleStartDispatch[_tool]?.call(details, painter);
  }

  // --- Movimentação da Província ---

  void _scaleStartMoveProvince(ScaleStartDetails details, MapPainter painter) {
    if (_selectedProvinceIds.isEmpty) return;

    _dragMouseStartWorld = painter.screenToWorld(details.localFocalPoint);
    _provinceDragDelta.value = Offset.zero;
    
    _lastProvSnapRawWorld = null;
    _lastProvSnapOffset = Offset.zero;
    
    _movingVerticesCache.clear();
    for (final provId in _selectedProvinceIds) {
      final p = _mapRepo.mapData.findById(provId);
      if (p != null) {
        for (int i = 0; i < p.pointCount; i++) {
          _movingVerticesCache.add(Offset(p.pointsX[i].toDouble(), p.pointsY[i].toDouble()));
        }
      }
    }
  }

  void _scaleUpdateMoveProvince(ScaleUpdateDetails details, MapPainter painter) {
    final currentMouseWorld = painter.screenToWorld(details.localFocalPoint);
    final rawDelta = currentMouseWorld - _dragMouseStartWorld!;
    
    double dX = rawDelta.dx.roundToDouble();
    double dY = rawDelta.dy.roundToDouble();

    if (_enableSnapping.value && _movingVerticesCache.isNotEmpty) {
      if (_lastProvSnapRawWorld == null || (currentMouseWorld - _lastProvSnapRawWorld!).distanceSquared > 4.0) {
        _lastProvSnapRawWorld = currentMouseWorld;
        
        final snapRadius = _config.pointPickRadiusScreen / _zoom.value;
        final snapRadiusSq = snapRadius * snapRadius;
        double bestDistSq = snapRadiusSq;
        
        double snapOffsetX = 0;
        double snapOffsetY = 0;
        bool foundSnap = false;

        double minX = double.infinity, minY = double.infinity;
        double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

        for (final pt in _movingVerticesCache) {
          if (pt.dx < minX) minX = pt.dx;
          if (pt.dx > maxX) maxX = pt.dx;
          if (pt.dy < minY) minY = pt.dy;
          if (pt.dy > maxY) maxY = pt.dy;
        }

        minX += dX - snapRadius;
        maxX += dX + snapRadius;
        minY += dY - snapRadius;
        maxY += dY + snapRadius;

        final region = BoundingBox(
          minX: minX.floor(),
          minY: minY.floor(),
          maxX: maxX.ceil(),
          maxY: maxY.ceil()
        );

        final candidates = _enableFrustumCulling.value && _mapRepo.spatialIndex != null
            ? _mapRepo.spatialIndex!.queryRegion(region)
            : Iterable<int>.generate(_mapRepo.mapData.provinces.length);

        int step = (_movingVerticesCache.length / 40).ceil();
        if (step < 1) step = 1;

        // Loop principal unificado: sem alocação de List<int>, matemática inline pura.
        for (final hitIdx in candidates) {
          final hitProv = _mapRepo.mapData.provinces[hitIdx];
          if (_selectedProvinceIds.contains(hitProv.id)) continue;

          for (int j = 0; j < hitProv.pointCount; j++) {
            final double hx = hitProv.pointsX[j].toDouble();
            final double hy = hitProv.pointsY[j].toDouble();
            
            if (hx >= minX && hx <= maxX && hy >= minY && hy <= maxY) {
              
              for (int i = 0; i < _movingVerticesCache.length; i += step) {
                final pt = _movingVerticesCache[i];
                final double px = pt.dx + dX;
                final double py = pt.dy + dY;

                final double distSq = (hx - px) * (hx - px) + (hy - py) * (hy - py);

                if (distSq < bestDistSq) {
                  bestDistSq = distSq;
                  snapOffsetX = hx - px;
                  snapOffsetY = hy - py;
                  foundSnap = true;
                }
              }
            }
          }
        }

        if (foundSnap) {
          _lastProvSnapOffset = Offset(snapOffsetX, snapOffsetY);
        } else {
          _lastProvSnapOffset = Offset.zero;
        }
      }

      dX += _lastProvSnapOffset.dx;
      dY += _lastProvSnapOffset.dy;
    }

    _provinceDragDelta.value = Offset(dX, dY);
  }

  void _scaleEndMoveProvince(ScaleEndDetails details, MapPainter painter) {
    if (_dragMouseStartWorld != null) {
      final dX = _provinceDragDelta.value.dx.round();
      final dY = _provinceDragDelta.value.dy.round();

      if (dX != 0 || dY != 0) {
        _mapRepo.moveProvinces(_selectedProvinceIds, dX, dY);
      }

      _provinceDragDelta.value = Offset.zero;
      _dragMouseStartWorld = null;
      _lastDragEndTime = DateTime.now();
      _movingVerticesCache.clear();
      
      _lastProvSnapRawWorld = null;
    }
  }

  // --- Edição de Ponto (Província) ---

  void _scaleStartEditPoint(ScaleStartDetails details, MapPainter painter) {
    final world = painter.screenToWorld(details.localFocalPoint);
    final maxDist = _config.pointPickRadiusScreen / _zoom.value;
    final maxDistSq = maxDist * maxDist;

    _lastPointSnapRawWorld = null;
    _lastPointSnapTarget = Offset.zero;

    for (final sp in _selectedPoints) {
       if ((Offset(sp.worldX.toDouble(), sp.worldY.toDouble()) - world).distanceSquared <= maxDistSq) {
          _draggingPoint.value = sp;
          _dragMouseStartWorld = world;
          _dragWorldPosition.value = Offset(sp.worldX.toDouble(), sp.worldY.toDouble());
          return;
       }
    }

    final hits = findPointsNear(
      provinces: _mapRepo.mapData.provinces,
      spatialIndex: _enableFrustumCulling.value ? _mapRepo.spatialIndex : null,
      worldX: world.dx, worldY: world.dy, maxWorldDistance: maxDist,
      priorityProvinceIds: _selectedProvinceIds
    );
    if (hits.isNotEmpty) {
      _draggingPoint.value = hits.first;
      _dragMouseStartWorld = world;
      _dragWorldPosition.value = Offset(hits.first.worldX.toDouble(), hits.first.worldY.toDouble());
      setState(() {
        _selectedPoints.clear();
        _selectedPoints.add(hits.first);
        _updateSubdivisionCache();
        _syncFastSelectedPoints();
        _currentHitPoints = hits;
        _currentHitIndex = 0;
        _originalPointCoords.clear();
        _originalPointCoords['${hits.first.provinceId}_${hits.first.pointIndex}'] = Offset(hits.first.worldX.toDouble(), hits.first.worldY.toDouble());
      });
    }
  }

  void _scaleUpdateEditPoint(ScaleUpdateDetails details, MapPainter painter) {
    if (_draggingPoint.value != null) {
      final currentMouseWorld = painter.screenToWorld(details.localFocalPoint);
      final delta = currentMouseWorld - _dragMouseStartWorld!;
      final originalPoint = _draggingPoint.value!;

      double targetX = (originalPoint.worldX + delta.dx).roundToDouble();
      double targetY = (originalPoint.worldY + delta.dy).roundToDouble();
      Offset target = Offset(targetX, targetY);

      if (_enableSnapping.value) {
          if (_lastPointSnapRawWorld == null || (target - _lastPointSnapRawWorld!).distanceSquared > 2.0) {
              _lastPointSnapRawWorld = target;
              _lastPointSnapTarget = _applySnapping(target);
          }
          target = _lastPointSnapTarget;
      }
      _dragWorldPosition.value = target;
    }
  }

  void _scaleEndEditPoint(ScaleEndDetails details, MapPainter painter) {
    if (_draggingPoint.value != null && _dragWorldPosition.value != null) {
      final p = _draggingPoint.value!;
      final wPos = _dragWorldPosition.value!;

      final deltaX = wPos.dx.round() - p.worldX;
      final deltaY = wPos.dy.round() - p.worldY;

      if (deltaX != 0 || deltaY != 0) {
        _mapRepo.updateMultiplePoints(_selectedPoints, deltaX, deltaY);

        setState(() {
          for (int i = 0; i < _selectedPoints.length; i++) {
            final sp = _selectedPoints[i];
            _selectedPoints[i] = sp.withWorldPosition(sp.worldX + deltaX, sp.worldY + deltaY);
          }
          _updateSubdivisionCache();
          _syncFastSelectedPoints();
        });
      }

      _draggingPoint.value = null;
      _dragWorldPosition.value = null;
      _dragMouseStartWorld = null;
      _lastDragEndTime = DateTime.now();
      
      _lastPointSnapRawWorld = null;
    }
  }

  // --- Manipulação de Prop (Ferramenta: Select) com Undo/Redo e Deformação de Malha Real ---

  void _scaleStartSelect(ScaleStartDetails details, MapPainter painter) {
    if (_selectedPropId != null) {
      final propIdx = _propsController.props.indexWhere((p) => p.id == _selectedPropId);
      if (propIdx != -1) {
        final prop = _propsController.props[propIdx];
        if (!prop.isLocked && prop.isVisible) {
          final world = painter.screenToWorld(details.localFocalPoint);
          final radiusSq = (18.0 / _zoom.value) * (18.0 / _zoom.value);

          _dragMouseStartWorld = world;
          _propOriginalCorners = List.of(prop.corners);
          _propOriginalMesh = List.of(prop.mesh);

          if (prop.isDeforming) {
            for (int i = 0; i < prop.mesh.length; i++) {
              if ((prop.mesh[i] - world).distanceSquared <= radiusSq) {
                _propsController.recordSnapshot();
                _draggedPropCornerIndex = i;
                return;
              }
            }
          } else {
            for (int i = 0; i < 4; i++) {
              if ((prop.corners[i] - world).distanceSquared <= radiusSq) {
                _propsController.recordSnapshot();
                _draggedPropCornerIndex = i;
                return;
              }
            }
          }

          final cx = (prop.corners[0].dx + prop.corners[1].dx + prop.corners[2].dx + prop.corners[3].dx) / 4;
          final cy = (prop.corners[0].dy + prop.corners[1].dy + prop.corners[2].dy + prop.corners[3].dy) / 4;
          if ((Offset(cx, cy) - world).distanceSquared <= radiusSq * 2.0) {
            _propsController.recordSnapshot();
            _draggedPropCornerIndex = -1;
            return;
          }
        }
      }
    }
    
    _draggedPropCornerIndex = null;
    _dragMouseStartWorld = null;
    _propOriginalCorners = null;
    _propOriginalMesh = null;
  }

  void _scaleUpdateSelect(ScaleUpdateDetails details, MapPainter painter) {
    if (_draggedPropCornerIndex != null && _selectedPropId != null && _dragMouseStartWorld != null && _propOriginalCorners != null) {
      final currentWorld = painter.screenToWorld(details.localFocalPoint);
      final delta = currentWorld - _dragMouseStartWorld!;
      
      final propIdx = _propsController.props.indexWhere((p) => p.id == _selectedPropId);
      if (propIdx == -1) return;
      final prop = _propsController.props[propIdx];

      final newCorners = List<Offset>.of(_propOriginalCorners!);
      List<Offset> newMesh = _propOriginalMesh != null ? List.of(_propOriginalMesh!) : [];

      if (_draggedPropCornerIndex == -1) {
        for (int i = 0; i < 4; i++) {
          newCorners[i] = _propOriginalCorners![i] + delta;
        }
        for (int i = 0; i < newMesh.length; i++) {
          newMesh[i] = _propOriginalMesh![i] + delta;
        }
      } else {
        final i = _draggedPropCornerIndex!;
        
        if (prop.isDeforming) {
          if (i < newMesh.length) {
            newMesh[i] = _propOriginalMesh![i] + delta;
            
            final d = prop.divisions;
            if (i == 0) {
              newCorners[0] = newMesh[i];
            } else if (i == d) {
              newCorners[1] = newMesh[i];
            } else if (i == newMesh.length - 1) {
              newCorners[2] = newMesh[i];
            } else if (i == newMesh.length - 1 - d) {
              newCorners[3] = newMesh[i];
            }
          }
        } else {
          final oppIndex = (i + 2) % 4;
          final oppCorner = _propOriginalCorners![oppIndex];
          final oldVec = _propOriginalCorners![i] - oppCorner;
          final newVec = currentWorld - oppCorner;

          if (prop.keepAspectRatio) {
            final baseDist = oldVec.distance;
            final newDist = newVec.distance;
            if (baseDist > 0) {
              final scale = newDist / baseDist;
              for (int j = 0; j < 4; j++) {
                if (j == oppIndex) {
                  continue;
                }
                newCorners[j] = oppCorner + (_propOriginalCorners![j] - oppCorner) * scale;
              }
            }
          } else {
            final scaleX = oldVec.dx != 0 ? newVec.dx / oldVec.dx : 1.0;
            final scaleY = oldVec.dy != 0 ? newVec.dy / oldVec.dy : 1.0;
            for (int j = 0; j < 4; j++) {
              if (j == oppIndex) {
                continue;
              }
              final v = _propOriginalCorners![j] - oppCorner;
              newCorners[j] = oppCorner + Offset(v.dx * scaleX, v.dy * scaleY);
            }
          }
          newMesh = PropModel.generateMesh(newCorners, prop.divisions, prop.distance);
        }
      }
      
      _propsController.updateProp(prop.copyWith(corners: newCorners, mesh: newMesh), saveToDisk: false);
    } else {
      _handlePanAndZoom(details);
    }
  }

  void _scaleEndSelect(ScaleEndDetails details, MapPainter painter) {
    if (_selectedPropId != null && _draggedPropCornerIndex != null) {
      final propIdx = _propsController.props.indexWhere((p) => p.id == _selectedPropId);
      if (propIdx != -1) {
        _propsController.updateProp(_propsController.props[propIdx], saveToDisk: true);
        _mapRepo.markPropAction();
      }
    }

    _draggedPropCornerIndex = null;
    _propOriginalCorners = null;
    _propOriginalMesh = null;
    _dragMouseStartWorld = null;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, MapPainter painter) {
    if (details.pointerCount == 0) return;

    if (_boxSelectStart.value != null) {
      _boxSelectEnd.value = details.localFocalPoint;
      return;
    }

    final handler = _scaleUpdateDispatch[_tool];
    if (handler != null && _dragMouseStartWorld != null) {
      handler(details, painter);
    } else {
      _handlePanAndZoom(details);
    }
  }

  void _handlePanAndZoom(ScaleUpdateDetails details) {
    if (details.scale == 1.0) {
      _panOffset.value -= details.focalPointDelta / _zoom.value;
    } else {
      final oldZoom = _zoom.value;
      final newZoom = (_baseZoomForPinch * details.scale).clamp(_config.minZoom, _config.maxZoom);
      _zoomAt(details.localFocalPoint, oldZoom, newZoom);
    }
  }

  void _onScaleEnd(ScaleEndDetails details, MapPainter painter) {
    if (_boxSelectStart.value != null && _boxSelectEnd.value != null) {
      final distSq = (_boxSelectEnd.value! - _boxSelectStart.value!).distanceSquared;
      
      if (distSq > 25.0) {
        _applyBoxSelection(painter);
        _lastDragEndTime = DateTime.now();
      }

      _boxSelectStart.value = null;
      _boxSelectEnd.value = null;
      return;
    }

    _scaleEndDispatch[_tool]?.call(details, painter);
  }

  void _onTapUp(TapUpDetails details, MapPainter painter) {
    if (DateTime.now().difference(_lastDragEndTime).inMilliseconds < 300) {
      return;
    }
    if (_draggingPoint.value == null) {
      _handleTap(details.localPosition, painter);
    }
  }

  void _handleLongPressStart(LongPressStartDetails details, MapPainter painter) {
    _handleRightClick(details.localPosition, painter);
  }
}