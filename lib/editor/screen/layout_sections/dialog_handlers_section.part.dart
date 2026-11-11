part of '../editor_screen.dart';

mixin _DialogHandlersSection on 
    _MapEditorScreenStateBase, 
    _WorkspaceLogic, 
    _PoiPlacementLogic, 
    _SelectionLogic {

  Future<void> _showSettingsModal() async {
    await showSettingsDialog(
      context, 
      langController: _lang, 
      storage: _mapRepo.storage,
      enableFrustumCulling: _enableFrustumCulling, 
      cullingMargin: _cullingMargin,
      uiScale: _uiScale,
    );
    await _prefs.setCullingEnabled(_enableFrustumCulling.value);
    await _prefs.setCullingMargin(_cullingMargin.value);
    await _prefs.setUiScale(_uiScale.value);
  }

  Future<void> _showPoiManagerModal(String categoryId) async {
    final converterName = await _resolveConverterNameForPoi();
    if (converterName == null || !mounted) {
      return;
    }
    final session = await _mapRepo.ensureActiveSession(converterName);
    if (!mounted) {
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.bg2,
        content: SizedBox(
          width: 320, 
          child: LuaRenderedPanel(
            session: session, 
            slot: 'poi_manager', 
            context: {'category': categoryId}, 
            storage: _mapRepo.storage, 
            onClose: () => Navigator.of(dialogCtx).pop(), 
            onChanged: _onPoiPanelChanged,
          ),
        ),
      ),
    );
  }

  Future<void> _showProjectDashboard() async {
    final oldConverter = _prefs.selectedConverter;

    await showDialog(
      context: context, 
      barrierDismissible: true,
      builder: (ctx) => ProjectDashboardDialog(
        lang: _lang, 
        prefs: _prefs, 
        storage: _mapRepo.storage,
        onClearWorkspace: () async {
          await _mapRepo.storage.clearWorkspace(); 
          _mapRepo.clearMap(); 
          _background.clear();
          final converterName = await _resolveConverterNameForPoi();
          if (converterName != null) { 
            final session = await _mapRepo.ensureActiveSession(converterName); 
            await session.invoke('poi_clear_all', {}); 
          }
          setState(() { 
            _selectedProvinceIds.clear(); 
            _selectedPoints.clear(); 
            _updateSubdivisionCache(); 
            _syncFastSelectedPoints();
            _pointsInProgress.clear(); 
            _draggingPoint.value = null; 
            _markers.clear(); 
            _markerIndex = null; 
          });
          _saveWorkspace();
        },
        onLoadMap: (path) async {
          final converter = await _mapRepo.storage.resolveActiveConverter(_prefs.selectedConverter);
          if (converter == null) {
            return;
          }
          await _mapRepo.importMapFile(path, converter);
          final session = await _mapRepo.ensureActiveSession(converter);
          await _refreshPoiCategories(session);
          _saveWorkspace();
        },
        onLoadNativeCache: (path) async {
          try {
            await _mapRepo.importNativeCache(path);
            _saveWorkspace(); 
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(_lang.get('import_native_success')), 
                backgroundColor: AppTheme.success
              ));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(_lang.get('import_native_error').replaceAll('{error}', e.toString())), 
                backgroundColor: AppTheme.danger
              ));
            }
          }
        },
        onLoadBackground: (path) async {
          final copiedPath = await _mapRepo.storage.saveBackground(path);
          if (copiedPath != null) {
            await _background.loadFromFile(copiedPath);
          }
          _saveWorkspace();
        },
      ),
    );

    if (oldConverter != _prefs.selectedConverter) {
      final newConv = await _resolveConverterNameForPoi();
      if (newConv == null) {
        EngineContext.instance.api.lua.deactivateConverter();
        setState(() { 
          _poiCategories.clear(); 
          _activePoiCategory = null; 
          _markers.clear(); 
          _markerIndex = null; 
          _pendingPoiEditorContext = null; 
          if (_tool == EditorTool.placePoi) {
            _tool = EditorTool.select;
          } 
        });
      } else {
        final session = await _mapRepo.ensureActiveSession(newConv);
        await _refreshPoiCategories(session); 
        await _refreshMarkers(session);
      }
    }
  }
}