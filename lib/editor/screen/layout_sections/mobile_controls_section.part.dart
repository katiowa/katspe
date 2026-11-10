part of '../editor_screen.dart';

mixin _MobileControlsSection on 
    _MapEditorScreenStateBase, 
    _SelectionLogic, 
    _KeyboardShortcuts {

  Widget _buildMobileControlsOverlay() {
    final isDrawing = _pointsInProgress.isNotEmpty;
    final hasSelection = _selectedPoints.isNotEmpty || _selectedProvinceIds.isNotEmpty || _pendingPoiEditorContext != null;

    final actions = <Widget>[];

    if (hasSelection || isDrawing) {
      actions.add(
        FloatingActionButton(
          heroTag: 'esc_btn', 
          backgroundColor: AppTheme.bg4, 
          foregroundColor: AppTheme.textSecondary,
          onPressed: () { 
            _handleKeyEvent(_canvasFocusNode, const KeyDownEvent(logicalKey: LogicalKeyboardKey.escape, physicalKey: PhysicalKeyboardKey.escape, timeStamp: Duration.zero)); 
          },
          tooltip: _lang.get('tooltip_cancel'), 
          child: const Icon(Icons.close, size: 24),
        ),
      );
    }

    actions.add(
      ValueListenableBuilder<bool>(
        valueListenable: _isShiftActive,
        builder: (context, isActive, _) => FloatingActionButton(
          heroTag: 'shift_btn', 
          backgroundColor: isActive ? AppTheme.accent : AppTheme.bg3, 
          foregroundColor: isActive ? AppTheme.bg1 : AppTheme.textPrimary,
          onPressed: () => _isShiftActive.value = !_isShiftActive.value, 
          tooltip: _lang.get('tooltip_shift'), 
          child: const Icon(Icons.library_add, size: 24),
        ),
      ),
    );

    actions.add(
      ValueListenableBuilder<bool>(
        valueListenable: _isDeselectModeActive,
        builder: (context, isActive, _) => FloatingActionButton(
          heroTag: 'deselect_btn', 
          backgroundColor: isActive ? AppTheme.accent : AppTheme.bg3, 
          foregroundColor: isActive ? AppTheme.bg1 : AppTheme.textPrimary,
          onPressed: () => _isDeselectModeActive.value = !_isDeselectModeActive.value, 
          tooltip: _lang.get('tooltip_deselect_mode'), 
          child: const Icon(Icons.remove_circle_outline, size: 24),
        ),
      ),
    );

    if (_selectedProvinceIds.length == 1 && !isDrawing && _tool != EditorTool.editPoint) {
      actions.add(
        FloatingActionButton(
          heroTag: 'clone_btn', 
          backgroundColor: AppTheme.bg3, 
          foregroundColor: AppTheme.textPrimary,
          onPressed: _cloneSelectedProvince,
          tooltip: _lang.get('tooltip_clone'), 
          child: const Icon(Icons.content_copy, size: 22),
        ),
      );
    }

    actions.add(
      FloatingActionButton(
        heroTag: 'del_btn', 
        backgroundColor: AppTheme.danger, 
        foregroundColor: AppTheme.textPrimary,
        onPressed: () { 
          if (isDrawing) { 
            setState(() { 
              _pointsInProgress.removeLast(); 
            }); 
          } else if (_tool != EditorTool.createProvincePoint) { 
            _handleDelete(); 
          } 
        },
        tooltip: isDrawing ? _lang.get('tooltip_backspace') : _lang.get('tooltip_delete'), 
        child: Icon(isDrawing ? Icons.backspace_outlined : Icons.delete_outline, size: 24),
      ),
    );

    return AnimatedBuilder(
      animation: _panelController,
      builder: (context, _) {
        final safeArea = _panelController.getSafeArea();
        final screenSize = MediaQuery.of(context).size;

        final actionsSize = 8.0 + (actions.length * 64.0);

        double neededAbove = 0;
        double neededBelow = 0;
        double neededLeft = 0;
        double neededRight = 0;

        if (_isFabOpen) {
          if (_fabDirection == ActionExpandDirection.up) {
            neededAbove = actionsSize;
            neededRight = 160.0;
          } else if (_fabDirection == ActionExpandDirection.down) {
            neededBelow = actionsSize;
            neededRight = 160.0;
          } else if (_fabDirection == ActionExpandDirection.left) {
            neededLeft = actionsSize;
            neededAbove = 80.0;
          } else if (_fabDirection == ActionExpandDirection.right) {
            neededRight = actionsSize;
            neededAbove = 80.0;
          }
        }

        final minLeft = safeArea.left + 8.0 + neededLeft;
        final maxLeft = math.max(minLeft, screenSize.width - safeArea.right - 56.0 - neededRight);

        final minBottom = safeArea.bottom + 8.0 + neededBelow;
        final maxBottom = math.max(minBottom, screenSize.height - safeArea.top - 56.0 - neededAbove);

        final clampedX = _fabPosition.dx.clamp(minLeft, maxLeft);
        final clampedY = _fabPosition.dy.clamp(minBottom, maxBottom);

        double? posLeft, posRight, posTop, posBottom;

        if (_fabDirection == ActionExpandDirection.up) {
          posLeft = clampedX - 24.0;
          posBottom = clampedY - 24.0;
        } else if (_fabDirection == ActionExpandDirection.down) {
          posLeft = clampedX - 24.0;
          posTop = screenSize.height - clampedY - 56.0 - 24.0;
        } else if (_fabDirection == ActionExpandDirection.right) {
          posLeft = clampedX - 24.0;
          posBottom = clampedY - 24.0;
        } else if (_fabDirection == ActionExpandDirection.left) {
          posRight = screenSize.width - clampedX - 56.0 - 24.0;
          posBottom = clampedY - 24.0;
        }

        return AnimatedPositioned(
          duration: _isDraggingFab ? Duration.zero : const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          left: posLeft,
          right: posRight,
          top: posTop,
          bottom: posBottom,
          child: ExpandableActionMenu(
            actions: actions.reversed.toList(),
            safeArea: safeArea,
            lang: _lang,
            direction: _fabDirection,
            onStateChanged: (isOpen, direction) {
              setState(() {
                _isFabOpen = isOpen;
                _fabDirection = direction;
              });
            },
            onDragStateChanged: (dragging) {
              setState(() {
                _isDraggingFab = dragging;
                if (!dragging) {
                  _fabPosition = Offset(clampedX, clampedY);
                }
              });
            },
            onPositionChanged: (delta) {
              setState(() {
                _fabPosition = Offset(
                  (_fabPosition.dx + delta.dx).clamp(minLeft, maxLeft),
                  (_fabPosition.dy - delta.dy).clamp(minBottom, maxBottom),
                );
              });
            },
          ),
        );
      },
    );
  }
}