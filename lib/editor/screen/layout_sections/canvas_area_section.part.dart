part of '../editor_screen.dart';

mixin _CanvasAreaSection on 
    _MapEditorScreenStateBase, 
    _SelectionLogic, 
    _GestureController, 
    _KeyboardShortcuts, 
    _CoreInteractionLogic, 
    _PointManipulationLogic, 
    _PoiPlacementLogic, 
    _ProvinceDrawingLogic {

  Widget _buildCanvasArea() {
    return Positioned.fill(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _panOffset, _zoom, _showProvinces, _showXRay, _showBg, 
            _hiddenPoiCategories, _draggingPoint, _dragWorldPosition, 
            _enableFrustumCulling, _cullingMargin, _showAllPoints, 
            _boxSelectStart, _boxSelectEnd, _provinceDragDelta,
            _isShiftActive, _isDeselectModeActive, _mapRepo, _propsController
          ]),
          builder: (context, _) {
            return Stack(
              key: _canvasKey,
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final painter = _buildPainter(constraints.biggest);
                        return Listener(
                          onPointerDown: (event) => _onPointerDown(event, painter),
                          onPointerSignal: (event) => _onPointerSignal(event),
                          child: GestureDetector(
                            onSecondaryTapUp: (details) => _handleRightClick(details.localPosition, painter),
                            onLongPressStart: (details) => _handleLongPressStart(details, painter),
                            onScaleStart: (details) => _onScaleStart(details, painter),
                            onScaleUpdate: (details) => _onScaleUpdate(details, painter),
                            onScaleEnd: (details) => _onScaleEnd(details, painter),
                            onTapUp: (details) => _onTapUp(details, painter),
                            child: CustomPaint(painter: painter, size: Size.infinite),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (_boxSelectStart.value != null && _boxSelectEnd.value != null) ...[
                  _buildBoxSelectionOverlay(),
                ],
                if (_selectedPoints.isNotEmpty && _draggingPoint.value == null) ...[
                  _buildPointActionMenuOverlay(),
                ],
                if (_pendingPoiEditorContext != null) ...[
                  _buildPoiEditorOverlay(context),
                  _buildPoiDragHandle(),
                ],
                if (_pointsInProgress.isNotEmpty) ...[
                  _buildDrawingActionButtons(),
                ],
                if (_selectedPoints.isNotEmpty && _tool == EditorTool.editPoint) ...[
                  AnimatedBuilder(
                    animation: _panelController,
                    builder: (context, _) {
                      final safeArea = _panelController.getSafeArea();
                      final minRight = safeArea.right + 24.0;
                      final minBottom = safeArea.bottom + 24.0;
                      return Positioned(
                        bottom: minBottom, 
                        right: minRight, 
                        child: _buildDPadBase(),
                      );
                    },
                  ),
                ],
                
                if (_islandCorrectionCompleter != null) ...[
                  ValueListenableBuilder<Offset>(
                    valueListenable: _islandCorrectionPosition,
                    builder: (context, pos, _) {
                      final size = MediaQuery.of(context).size;
                      return Positioned(
                        left: pos.dx,
                        top: pos.dy,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (details) {
                            final nextX = (_islandCorrectionPosition.value.dx + details.delta.dx)
                                .clamp(0.0, math.max(0.0, size.width - 120.0))
                                .toDouble();
                            final nextY = (_islandCorrectionPosition.value.dy + details.delta.dy)
                                .clamp(0.0, math.max(0.0, size.height - 80.0))
                                .toDouble();
                            _islandCorrectionPosition.value = Offset(nextX, nextY);
                          },
                          child: IslandCorrectionOverlayWidget(
                            lang: _lang,
                            onToggle: () {
                              final newPath = _islandCorrectionCurrentPath == 1 ? 2 : 1;
                              _onIslandCorrectionPathChanged?.call(newPath);
                            },
                            onConfirm: () {
                              if (!_islandCorrectionCompleter!.isCompleted) {
                                _islandCorrectionCompleter!.complete(IslandCorrectionResult.confirm);
                              }
                            },
                            onIgnore: () {
                              if (!_islandCorrectionCompleter!.isCompleted) {
                                _islandCorrectionCompleter!.complete(IslandCorrectionResult.ignore);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],

              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDPadBase() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dPadButton(Icons.keyboard_arrow_up, NudgeDirection.up, _lang.get('tooltip_nudge_up')),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dPadButton(Icons.keyboard_arrow_left, NudgeDirection.left, _lang.get('tooltip_nudge_left')),
            const SizedBox(width: 48),
            _dPadButton(Icons.keyboard_arrow_right, NudgeDirection.right, _lang.get('tooltip_nudge_right')),
          ],
        ),
        _dPadButton(Icons.keyboard_arrow_down, NudgeDirection.down, _lang.get('tooltip_nudge_down')),
      ],
    );
  }

  Widget _dPadButton(IconData icon, NudgeDirection dir, String tooltip) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Tooltip(
        message: tooltip, 
        child: Material(
          color: AppTheme.bg3.withValues(alpha: 0.85), 
          shape: const CircleBorder(), 
          elevation: 4, 
          child: InkWell(
            customBorder: const CircleBorder(), 
            onTap: () => _nudgeSelectedPoints(dir), 
            child: Padding(
              padding: const EdgeInsets.all(12), 
              child: Icon(icon, color: AppTheme.textPrimary, size: 24),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoiDragHandle() {
    final ctx = _pendingPoiEditorContext;
    if (ctx == null) {
      return const SizedBox.shrink();
    }
    final camera = CameraTransform(panOffset: _panOffset.value, zoomScale: _zoom.value);
    final worldPos = Offset((ctx['x'] as num).toDouble(), (ctx['y'] as num).toDouble());
    final screenPos = camera.worldToScreen(worldPos);

    return AnimatedBuilder(
      animation: _panelController,
      builder: (context, _) {
        final safeArea = _panelController.getSafeArea();
        final maxL = math.max(safeArea.left, MediaQuery.of(context).size.width - safeArea.right - 40);
        final maxT = math.max(safeArea.top, MediaQuery.of(context).size.height - safeArea.bottom - 40);

        return Positioned(
          left: (screenPos.dx - 20).clamp(safeArea.left, maxL), 
          top: (screenPos.dy - 55).clamp(safeArea.top, maxT), 
          child: MouseRegion(
            cursor: SystemMouseCursors.move,
            child: GestureDetector(
              onPanStart: (details) { 
                _poiDragStartWorldX = (ctx['x'] as num).toDouble(); 
                _poiDragStartWorldY = (ctx['y'] as num).toDouble(); 
                _poiDragStartFocal = details.globalPosition; 
              },
              onPanUpdate: (details) {
                if (_poiDragStartWorldX == null || _poiDragStartFocal == null) {
                  return;
                }
                final diff = details.globalPosition - _poiDragStartFocal!;
                setState(() { 
                  ctx['x'] = (_poiDragStartWorldX! + diff.dx / _zoom.value).round(); 
                  ctx['y'] = (_poiDragStartWorldY! + diff.dy / _zoom.value).round(); 
                });
              },
              onPanEnd: (details) async {
                _poiDragStartWorldX = null; 
                _poiDragStartWorldY = null; 
                _poiDragStartFocal = null;
                if (ctx['index'] != null) {
                  final session = _mapRepo.activeSession;
                  if (session != null) {
                    await session.invoke('poi_move', {'category': ctx['category'], 'index': ctx['index'], 'x': ctx['x'], 'y': ctx['y']});
                    _mapRepo.markPoiAction();
                    await _refreshMarkers(session);
                  }
                }
              },
              child: Container(
                width: 40, 
                height: 40, 
                decoration: BoxDecoration(
                  color: AppTheme.accent, 
                  shape: BoxShape.circle, 
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)], 
                  border: Border.all(color: Colors.white, width: 2),
                ), 
                child: const Icon(Icons.open_with, color: Colors.white, size: 20),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoxSelectionOverlay() {
    return Builder(builder: (context) {
      final start = _boxSelectStart.value; 
      final end = _boxSelectEnd.value;
      if (start == null || end == null) {
        return const SizedBox.shrink();
      }
      final rect = Rect.fromPoints(start, end);
      if (rect.width < 1 || rect.height < 1) {
        return const SizedBox.shrink();
      }

      return Positioned(
        left: rect.left, 
        top: rect.top, 
        width: rect.width, 
        height: rect.height, 
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.15), 
            border: Border.all(color: AppTheme.accent, width: 1.5),
          ),
        ),
      );
    });
  }

  Widget _buildPointActionMenuOverlay() {
    return Builder(builder: (context) {
      final camera = CameraTransform(panOffset: _panOffset.value, zoomScale: _zoom.value);
      final screenPos = camera.worldToScreen(Offset(_selectedPoints.last.worldX.toDouble(), _selectedPoints.last.worldY.toDouble()));

      VoidCallback? subdivideAction;
      if (_validEdgesToSubdivide.isNotEmpty) {
        subdivideAction = () { 
          _mapRepo.subdivideEdges(_validEdgesToSubdivide); 
          setState(() { 
            _selectedPoints.clear(); 
            _updateSubdivisionCache(); 
          }); 
        };
      }
      return Positioned(
        left: screenPos.dx + 32, 
        top: screenPos.dy - 64, 
        child: IgnorePointer(
          ignoring: false, 
          child: PointActionMenu(
            lang: _lang, 
            onSubdivide: subdivideAction, 
            onDelete: _handleDelete, 
            onCancel: _cancelPointMoves,
          ),
        ),
      );
    });
  }

  Widget _buildPoiEditorOverlay(BuildContext context) {
    final editorContext = _pendingPoiEditorContext;
    final session = _mapRepo.activeSession;
    if (editorContext == null || session == null) {
      return const SizedBox.shrink();
    }

    final camera = CameraTransform(panOffset: _panOffset.value, zoomScale: _zoom.value);
    final worldPos = Offset((editorContext['x'] as num).toDouble(), (editorContext['y'] as num).toDouble());
    final screenPos = camera.worldToScreen(worldPos);

    return AnimatedBuilder(
      animation: _panelController,
      builder: (context, _) {
        final safeArea = _panelController.getSafeArea();
        final maxL = math.max(safeArea.left, MediaQuery.of(context).size.width - safeArea.right - 240.0);
        final maxT = math.max(safeArea.top, MediaQuery.of(context).size.height - safeArea.bottom - 180.0);

        return Positioned(
          left: (screenPos.dx + 16).clamp(safeArea.left, maxL).toDouble(), 
          top: (screenPos.dy).clamp(safeArea.top, maxT).toDouble(), 
          child: Container(
            width: 220, 
            padding: const EdgeInsets.all(10), 
            decoration: BoxDecoration(
              color: AppTheme.bg2, 
              borderRadius: BorderRadius.circular(AppTheme.radiusMd), 
              border: Border.all(color: AppTheme.accent), 
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12)], 
            ), 
            child: LuaRenderedPanel(
              session: session, 
              slot: 'poi_quick_editor', 
              context: editorContext, 
              storage: _mapRepo.storage, 
              onClose: _closePoiEditor, 
              onChanged: _onPoiPanelChanged,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawingActionButtons() {
    return AnimatedBuilder(
      animation: _panelController,
      builder: (context, _) {
        final safeArea = _panelController.getSafeArea();
        return Positioned(
          bottom: 24 + safeArea.bottom, 
          right: 24 + safeArea.right,
          child: Row(
            children: [
              FloatingActionButton.extended(
                heroTag: 'discard', 
                onPressed: () => setState(() => _pointsInProgress.clear()), 
                backgroundColor: AppTheme.danger, 
                icon: const Icon(Icons.close), 
                label: Text(_lang.get('drawing_discard')),
              ),
              const SizedBox(width: 12),
              FloatingActionButton.extended(
                heroTag: 'commit', 
                backgroundColor: AppTheme.accent, 
                onPressed: _pointsInProgress.length >= 3 ? _commitCurrentProvince : null, 
                icon: const Icon(Icons.check), 
                label: Text(_lang.get('drawing_save').replaceAll('{count}', _pointsInProgress.length.toString())),
              ),
            ],
          ),
        );
      },
    );
  }
}