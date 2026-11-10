part of 'editor_screen.dart';

mixin _PoiPlacementLogic on _MapEditorScreenStateBase {
  
  void _tapPlacePoi(Offset localPosition, MapPainter painter) {
    final category = _activePoiCategory;
    if (category == null) return; 
    _openPoiEditor(category: category, index: null, worldPos: painter.screenToWorld(localPosition));
  }

  Future<String?> _resolveConverterNameForPoi() {
    return _mapRepo.storage.resolveActiveConverter(_prefs.selectedConverter);
  }

  Future<void> _openPoiEditor({
    required String category,
    required int? index,
    required Offset worldPos,
  }) async {
    if (!mounted) return;
    setState(() {
      _pendingPoiEditorContext = {
        'category': category,
        'index': index,
        'x': worldPos.dx.round(),
        'y': worldPos.dy.round(),
      };
    });
  }

  void _closePoiEditor() {
    if (!mounted) return;
    setState(() {
      _pendingPoiEditorContext = null;
    });
  }

  Future<void> _onPoiPanelChanged() async {
    _mapRepo.markPoiAction();
    final converterName = await _resolveConverterNameForPoi();
    if (converterName == null) return;
    final session = await _mapRepo.ensureActiveSession(converterName);
    await _refreshMarkers(session);
    await _syncImportedFilesManifest(session);
  }

  Future<void> _refreshMarkers(LuaConverterSession session) async {
    final result = await session.invoke('list_markers', {});
    final rawMarkers = asLuaList(result?['markers']);
    final markers = rawMarkers.whereType<Map>().map((m) => MapMarker.fromMap(m.cast<String, dynamic>())).toList();
    if (!mounted) return;
    setState(() {
      _markers = markers;
      _markerIndex = MarkerSpatialIndex(markers);
    });
  }

  Future<void> _refreshPoiCategories(LuaConverterSession session) async {
    final result = await session.invoke('poi_categories', {});
    final rawCategories = asLuaList(result?['categories']);
    final categories = rawCategories.whereType<Map>().map((c) => c.cast<String, dynamic>()).toList();
    if (!mounted) return;
    setState(() => _poiCategories = categories);
  }

  Future<void> _syncImportedFilesManifest(LuaConverterSession session) async {
    final manifest = await session.invoke('get_import_manifest', {});
    if (manifest == null) return;
    await _mapRepo.storage.saveImportedFilesManifest(manifest);
  }
}