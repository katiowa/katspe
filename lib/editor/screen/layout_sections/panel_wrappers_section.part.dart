part of '../editor_screen.dart';

mixin _PanelWrappersSection on 
    _MapEditorScreenStateBase, 
    _DialogHandlersSection, 
    _SelectionLogic, 
    _CoreInteractionLogic {

  Future<void> _handleMergeProvinces() async {
    if (_selectedProvinceIds.length < 2) return;

    final originalIds = Set<int>.from(_selectedProvinceIds);
    
    final contoursData = await _mapRepo.calculateMergeContours(originalIds);

    if (!mounted || contoursData == null) return;

    if (contoursData.islandCount == 1) {
      int currentPath = 1;
      var resultProvince = _mapRepo.buildMergeProvince(contoursData, currentPath);

      final size = MediaQuery.of(context).size;
      _islandCorrectionPosition.value = Offset(math.max(16.0, (size.width - 480) / 2), 80);

      setState(() {
        _pointsInProgress.clear();
        for (int i = 0; i < resultProvince.pointCount; i++) {
          _pointsInProgress.add(Offset(resultProvince.pointsX[i].toDouble(), resultProvince.pointsY[i].toDouble()));
        }

        _islandCorrectionCurrentPath = currentPath;
        _onIslandCorrectionPathChanged = (newPath) {
          currentPath = newPath;
          resultProvince = _mapRepo.buildMergeProvince(contoursData, currentPath);
          
          if (mounted) {
            setState(() {
              _islandCorrectionCurrentPath = newPath;
              _pointsInProgress.clear();
              for (int i = 0; i < resultProvince.pointCount; i++) {
                _pointsInProgress.add(Offset(resultProvince.pointsX[i].toDouble(), resultProvince.pointsY[i].toDouble()));
              }
            });
          }
        };
      });

      _islandCorrectionCompleter = Completer<IslandCorrectionResult>();
      final dialogResult = await _islandCorrectionCompleter!.future;

      setState(() {
        _islandCorrectionCompleter = null;
        _onIslandCorrectionPathChanged = null;
      });

      if (dialogResult == IslandCorrectionResult.confirm) {
        
      } else if (dialogResult == IslandCorrectionResult.ignore) {
        resultProvince = _mapRepo.buildMergeProvince(contoursData, 0);
      } else {
        if (mounted) {
          setState(() {
            _pointsInProgress.clear();
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _pointsInProgress.clear();
        });
      }
      
      await _mapRepo.applyMerge(resultProvince, originalIds);
      if (mounted) {
        setState(() => _selectedProvinceIds.clear());
      }
      
    } else {
      final resultProvince = _mapRepo.buildMergeProvince(contoursData, 1);
      
      await _mapRepo.applyMerge(resultProvince, originalIds);
      if (mounted) {
        setState(() => _selectedProvinceIds.clear());
      }
    }
  }

  Widget _buildTopBarWrapper() {
    return AnimatedBuilder(
      // Incluímos o _uiScale para forçar a renderização do Wrapper quando o slider for movido!
      animation: Listenable.merge([_panelController, _uiScale]),
      builder: (context, _) => DraggablePanelWrapper(
        id: 'topbar',
        controller: _panelController,
        lang: _lang,
        uiScale: _uiScale.value,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _mapRepo, _showProvinces, _showXRay, _showBg, _hiddenPoiCategories, _enableSnapping, _showAllPoints, _propsController
          ]),
          builder: (context, _) => TopBar(
            lang: _lang,
            provinceCount: _mapRepo.mapData.provinces.length,
            isBusy: _mapRepo.isBusy,
            canUndo: _mapRepo.canUndo,
            canRedo: _mapRepo.canRedo,
            enableSnapping: _enableSnapping.value,
            showAllPoints: _showAllPoints.value,
            showProvinces: _showProvinces.value,
            showXRay: _showXRay.value,
            showBg: _showBg.value,
            poiCategories: _poiCategories,
            hiddenCategories: _hiddenPoiCategories.value,
            propsController: _propsController,
            dock: _panelController.getPanel('topbar').dock,
            onUndo: _performUndo,
            onRedo: _performRedo,
            onToggleSnapping: () => _enableSnapping.value = !_enableSnapping.value,
            onToggleAllPoints: () => _showAllPoints.value = !_showAllPoints.value,
            onToggleProvinces: () => _showProvinces.value = !_showProvinces.value,
            onToggleXRay: () => _showXRay.value = !_showXRay.value,
            onToggleBg: () => _showBg.value = !_showBg.value,
            onToggleCategory: (id) {
              final updated = Set<String>.from(_hiddenPoiCategories.value);
              if (updated.contains(id)) {
                updated.remove(id);
              } else {
                updated.add(id);
              }
              _hiddenPoiCategories.value = updated;
            },
            onSettings: _showSettingsModal,
            onManageProject: _showProjectDashboard,
            onManagePoiCategory: _showPoiManagerModal,
            onImportProp: () async {
              final size = MediaQuery.of(context).size;
              final res = await FilePicker.pickFile(type: FileType.image);
              if (!mounted) return;
              if (res != null && res.path != null) {
                final centerScreen = Offset(size.width / 2, size.height / 2);
                final camera = CameraTransform(panOffset: _panOffset.value, zoomScale: _zoom.value);
                final worldCenter = camera.screenToWorld(centerScreen);
                await _propsController.addProp(res.path!, worldCenter);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSideBarWrapper() {
    return AnimatedBuilder(
      animation: Listenable.merge([_panelController, _uiScale]),
      builder: (context, _) => DraggablePanelWrapper(
        id: 'sidebar',
        controller: _panelController,
        lang: _lang,
        uiScale: _uiScale.value,
        child: RepaintBoundary(
          child: SideToolbar(
            lang: _lang,
            activeTool: _tool,
            poiCategories: _poiCategories,
            activePoiCategory: _activePoiCategory,
            dock: _panelController.getPanel('sidebar').dock,
            onToolSelected: (tool) {
              setState(() {
                _tool = tool;
                _selectedPoints.clear();
                _updateSubdivisionCache();
                _syncFastSelectedPoints();
                _pendingPoiEditorContext = null;
                _currentHitPoints.clear();
              });
            },
            onPoiCategorySelected: (categoryId) {
              setState(() {
                _tool = EditorTool.placePoi;
                _activePoiCategory = categoryId;
                _selectedPoints.clear();
                _updateSubdivisionCache();
                _syncFastSelectedPoints();
                _currentHitPoints.clear();
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPropertiesWrapper() {
    return AnimatedBuilder(
      animation: Listenable.merge([_panelController, _uiScale]),
      builder: (context, _) => DraggablePanelWrapper(
        id: 'properties',
        controller: _panelController,
        lang: _lang,
        uiScale: _uiScale.value,
        child: RepaintBoundary(
          child: PropertiesPanel(
            lang: _lang, 
            mapData: _mapRepo.mapData,
            markers: _markers,
            poiCategories: _poiCategories,
            selectedProvinceIds: _selectedProvinceIds,
            exportOptions: _exportOptions,
            storage: _mapRepo.storage,
            dock: _panelController.getPanel('properties').dock,
            onExportOptionsChanged: (opts) => setState(() => _exportOptions = opts),
            onRunExport: () async {
              setState(() => _isExporting = true);
              try {
                final tgt = _selectedProvinceIds.length == 1 ? _selectedProvinceIds.first : null;
                final result = await runExport(
                  options: _exportOptions.copyWith(targetProvinceId: tgt), 
                  mapRepository: _mapRepo, 
                  saveFile: (name, bytes) async {
                    final uri = await FilePicker.saveFile(dialogTitle: _lang.get('export_dialog_title'), fileName: name, bytes: bytes);
                    if (uri == null) {
                      return null;
                    }
                    if (uri.scheme == 'file') {
                      return uri.toFilePath();
                    }
                    return uri.toString();
                  },
                ); 
                setState(() => _lastExportedFiles = result.writtenFiles);
              } finally { 
                setState(() => _isExporting = false); 
              }
            },
            isExporting: _isExporting,
            lastExportedFiles: _lastExportedFiles,
            onDeleteProvinces: _handleDelete,
            onMergeProvinces: _handleMergeProvinces,
            onImportProvince: () async {
              final converterName = await _mapRepo.storage.resolveActiveConverter(_prefs.selectedConverter);
              if (converterName != null) {
                final info = await _mapRepo.storage.getConverterDisplayInfo(converterName);
                final exts = info?.supportedExtensions ?? [];
                final res = await FilePicker.pickFile(type: FileType.any);
                if (res != null && res.path != null) {
                  final path = res.path!;
                  final fileName = path.split(Platform.pathSeparator).last;
                  final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
                  if (ext.isEmpty || exts.isEmpty || exts.contains(ext)) {
                    await _mapRepo.importSingleProvinceFile(path, converterName);
                  }
                }
              }
            },
          ),
        ),
      ),
    );
  }
}