part of 'editor_screen.dart';

mixin _WorkspaceLogic on _MapEditorScreenStateBase, _PoiPlacementLogic {
  Future<void> _initializeEngine() async {
    await Future.wait([
      _prefs.load(), 
      _lang.init(), 
      _propsController.loadAll()
    ]);

    final isMobile = defaultTargetPlatform == TargetPlatform.android || 
                     defaultTargetPlatform == TargetPlatform.iOS;
                     
    _uiScale.value = _prefs.uiScale ?? (isMobile ? 1.10 : 1.0);
    _applyUiScale(); // Força a aplicação imediata logo após ler os dados do disco

    _enableFrustumCulling.value = _prefs.cullingEnabled ?? true;
    _cullingMargin.value = _prefs.cullingMargin ?? 0.5;

    final results = await Future.wait([
      _mapRepo.loadFromCache(),
      _mapRepo.storage.getBackgroundPath(),
    ]);
    final bgPath = results[1] as String?;
    if (bgPath != null) {
      try { await _background.loadFromFile(bgPath); } catch (_) {}
    }

    final converterName = await _mapRepo.storage.resolveActiveConverter(_prefs.selectedConverter);
    if (converterName == null) return;

    try {
      final session = await _mapRepo.ensureActiveSession(converterName);
      await _refreshPoiCategories(session);

      final manifest = await _mapRepo.storage.loadImportedFilesManifest();
      if (manifest != null) {
        final importedDir = await _mapRepo.storage.getImportedFilesDir();
        final base = '${importedDir.path}${Platform.pathSeparator}';

        for (final entry in manifest.entries) {
          final category = entry.key;
          final files = (entry.value as List?) ?? const [];
          for (final fileName in files) {
            try {
              var rawText = await File('$base$fileName').readAsString();
              
              rawText = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
              if (rawText.startsWith('\uFEFF')) rawText = rawText.substring(1);
              
              await session.invoke('poi_import_batch', {
                'category': category,
                'raw_text': rawText,
                'file_name': fileName,
              });
            } catch (_) {}
          }
        }
      }

      await _refreshMarkers(session);
    } catch (_) {}
  }

  void _saveWorkspace() {
    final session = _mapRepo.activeSession;
    if (session == null) return;
    _syncImportedFilesManifest(session);
  }
}