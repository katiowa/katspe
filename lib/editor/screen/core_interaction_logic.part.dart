part of 'editor_screen.dart';

mixin _CoreInteractionLogic on 
    _MapEditorScreenStateBase, 
    _SelectionLogic, 
    _PoiPlacementLogic, 
    _PointManipulationLogic, 
    _ProvinceDrawingLogic {

  late final Map<EditorTool, void Function(Offset, MapPainter)> _tapDispatch = {
    EditorTool.select: _tapSelectOrMove,
    EditorTool.moveProvince: _tapSelectOrMove,
    EditorTool.createProvincePoint: _tapCreateProvincePoint,
    EditorTool.editPoint: _tapEditPoint,
    EditorTool.placePoi: _tapPlacePoi,
  };

  MapPainter _buildPainter(Size size) {
    return MapPainter(
      provinces: _mapRepo.mapData.provinces,
      spatialIndex: _mapRepo.spatialIndex,
      panOffset: _panOffset.value,
      zoomScale: _zoom.value,
      config: _config,
      cache: _painterCache,
      selectedProvinceIds: Set<int>.of(_selectedProvinceIds),
      provinceInProgress: _pointsInProgress.isEmpty ? null : List<Offset>.of(_pointsInProgress),
      provinceInProgressColor: Color(_pendingProvinceColor),
      backgroundImage: _background.image,
      markers: _markers,
      markerIndex: _markerIndex,
      hiddenCategories: _hiddenPoiCategories.value,
      pendingPoiContext: _pendingPoiEditorContext,
      poiCategories: _poiCategories,
      selectedPoints: List<SelectedPointRef>.of(_selectedPoints),
      fastSelectedPoints: _fastSelectedPoints,
      enableFrustumCulling: _enableFrustumCulling.value,
      cullingMargin: _cullingMargin.value,
      showAllPoints: _showAllPoints.value,
      showProvinces: _showProvinces.value,
      showXRay: _showXRay.value,
      showBackground: _showBg.value,
      draggingPoint: _draggingPoint.value,
      dragWorldPosition: _dragWorldPosition.value,
      provinceDragDelta: _provinceDragDelta.value,
      props: _propsController.props,
      propImages: {
        for (final p in _propsController.props)
          if (_propsController.getImage(p.id) != null) p.id: _propsController.getImage(p.id)!
      },
      selectedPropId: _selectedPropId,
    );
  }

  void _handleTap(Offset localPosition, MapPainter painter) {
    if (_islandCorrectionCompleter != null) return;

    if (_isDeselectModeActive.value) {
      _handleRightClick(localPosition, painter);
      return;
    }

    final hit = painter.resolvePoiAt(localPosition);
    if (hit != null && (_tool == EditorTool.select || _tool == EditorTool.placePoi)) {
      _openPoiEditor(category: hit.category, index: hit.index, worldPos: hit.worldPosition);
      return;
    }

    _tapDispatch[_tool]?.call(localPosition, painter);
  }

  void _performUndo() {
    _mapRepo.undo().then((domain) {
      if (domain == HistoryDomain.poi && _mapRepo.activeSession != null) {
        _refreshMarkers(_mapRepo.activeSession!);
      } else if (domain == HistoryDomain.prop) {
        _propsController.undo();
      }
    });
  }

  void _performRedo() {
    _mapRepo.redo().then((domain) {
      if (domain == HistoryDomain.poi && _mapRepo.activeSession != null) {
        _refreshMarkers(_mapRepo.activeSession!);
      } else if (domain == HistoryDomain.prop) {
        _propsController.redo();
      }
    });
  }
}