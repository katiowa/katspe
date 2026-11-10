part of 'editor_screen.dart';

mixin _KeyboardShortcuts on _MapEditorScreenStateBase, _SelectionLogic, _CoreInteractionLogic, _PoiPlacementLogic {
  static const _digitKeysInOrder = [
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  Map<LogicalKeyboardKey, String> get _poiCategoryDigitKeys {
    final map = <LogicalKeyboardKey, String>{};
    for (int i = 0; i < _poiCategories.length && i < _digitKeysInOrder.length; i++) {
      final id = _poiCategories[i]['id']?.toString();
      if (id != null) map[_digitKeysInOrder[i]] = id;
    }
    return map;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (_isEditingText) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final isShiftKey = key == LogicalKeyboardKey.shiftLeft || key == LogicalKeyboardKey.shiftRight;

    if (event is KeyDownEvent) {
      if (isShiftKey) {
        _isShiftActive.value = true;
        return KeyEventResult.handled;
      }
      
      final hw = HardwareKeyboard.instance;
      final isCtrl = hw.isLogicalKeyPressed(LogicalKeyboardKey.controlLeft) || hw.isLogicalKeyPressed(LogicalKeyboardKey.controlRight);
      final isShift = _isShiftActive.value;

      if (isCtrl && key == LogicalKeyboardKey.keyC) { 
        _copyProvince(); 
        return KeyEventResult.handled; 
      }
      
      if (isCtrl && key == LogicalKeyboardKey.keyV) { 
        _pasteProvince(); 
        return KeyEventResult.handled; 
      }

      if (isCtrl && key == LogicalKeyboardKey.keyZ) {
        if (_pointsInProgress.isNotEmpty) {
          setState(() {
            _pointsInProgress.removeLast();
          });
          return KeyEventResult.handled;
        }

        if (isShift) { 
           _performRedo(); 
        } else { 
           _performUndo(); 
        }
        return KeyEventResult.handled;
      }
      
      if (isCtrl && key == LogicalKeyboardKey.keyY) { 
        _performRedo(); 
        return KeyEventResult.handled; 
      }

      if (key == LogicalKeyboardKey.escape) {
        if (_islandCorrectionCompleter != null) {
          _islandCorrectionCompleter!.complete(IslandCorrectionResult.cancel);
          return KeyEventResult.handled;
        }
        
        if (_draggingPoint.value != null) {
          _draggingPoint.value = null; _dragWorldPosition.value = null; return KeyEventResult.handled;
        } else if (_selectedPoints.isNotEmpty) {
           _cancelPointMoves(); return KeyEventResult.handled;
        } else if (_pendingPoiEditorContext != null) {
           _closePoiEditor(); return KeyEventResult.handled;
        } else if (_pointsInProgress.isNotEmpty) {
           setState(() => _pointsInProgress.clear()); return KeyEventResult.handled;
        } else if (_selectedProvinceIds.isNotEmpty) {
           setState(() => _selectedProvinceIds.clear()); return KeyEventResult.handled;
        }
      }

      if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
        if (_pointsInProgress.isNotEmpty) { 
          setState(() {
            _pointsInProgress.removeLast();
          }); 
          return KeyEventResult.handled; 
        }

        if (_tool == EditorTool.createProvincePoint) {
          return KeyEventResult.handled;
        }

        _handleDelete(); 
        return KeyEventResult.handled;
      }

      if (_tool == EditorTool.editPoint && _selectedPoints.isNotEmpty) {
        NudgeDirection? direction;
        if (key == LogicalKeyboardKey.arrowUp) direction = NudgeDirection.up;
        if (key == LogicalKeyboardKey.arrowDown) direction = NudgeDirection.down;
        if (key == LogicalKeyboardKey.arrowLeft) direction = NudgeDirection.left;
        if (key == LogicalKeyboardKey.arrowRight) direction = NudgeDirection.right;
        if (direction != null) {
          _nudgeSelectedPoints(direction);
          return KeyEventResult.handled;
        }
      }

      if (key == LogicalKeyboardKey.keyS) { _enableSnapping.value = !_enableSnapping.value; return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.keyV) { _showAllPoints.value = !_showAllPoints.value; return KeyEventResult.handled; }

      if (key == LogicalKeyboardKey.keyP) { _showProvinces.value = !_showProvinces.value; return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.keyX) { _showXRay.value = !_showXRay.value; return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.keyB) { _showBg.value = !_showBg.value; return KeyEventResult.handled; }

      if (key == LogicalKeyboardKey.digit1) { setState(() { _tool = EditorTool.select; _pendingPoiEditorContext = null; }); return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.digit2) { setState(() { _tool = EditorTool.moveProvince; _pendingPoiEditorContext = null; }); return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.digit3) { setState(() { _tool = EditorTool.createProvincePoint; _pendingPoiEditorContext = null; }); return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.digit4) { setState(() { _tool = EditorTool.editPoint; _pendingPoiEditorContext = null; }); return KeyEventResult.handled; }

      final poiKey = _poiCategoryDigitKeys[key];
      if (poiKey != null) {
        setState(() { _tool = EditorTool.placePoi; _activePoiCategory = poiKey; _selectedPoints.clear(); _updateSubdivisionCache(); _syncFastSelectedPoints(); });
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      if (isShiftKey) {
        _isShiftActive.value = false;
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _nudgeSelectedPoints(NudgeDirection direction) {
    final (unitX, unitY) = nudgeDeltaUnits[direction]!;
    final step = _config.pointNudgeStep;
    final deltaX = (unitX * step).round();
    final deltaY = (unitY * step).round();
    if (deltaX == 0 && deltaY == 0) return;

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
}