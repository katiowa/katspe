part of '../map_repository.dart';

mixin _LuaInterop on ChangeNotifier, _HistoryManager {
  String? _lastImportWarning;
  String? get lastImportWarning => _lastImportWarning;

  LuaConverterSession? get activeSession => EngineContext.instance.api.lua.active;

  Future<LuaConverterSession> ensureActiveSession(String converterName) async {
    final storage = (this as MapRepository).storage;
    final api = EngineContext.instance.api;
    
    if (api.lua.activeConverterName != converterName) {
      final entry = await storage.loadConverterEntryPoint(converterName);
      if (entry == null) {
        throw Exception('Converter "$converterName" has no main.lua entry point.');
      }
      await api.lua.activateConverter(converterName, entry.script, entry.rootPath);
    }
    final session = api.lua.active;
    if (session == null) {
      throw Exception('Converter "$converterName" could not be activated.');
    }
    return session;
  }

  /// NOVO: Aplica o binário (já validado pela storage) diretamente no estado em memória
  Future<void> importNativeCache(String filePath) async {
    final repo = this as MapRepository;
    repo._setBusy(true);
    try {
      final newData = await repo.storage.importNativeMapCache(filePath);
      
      // Limpa histórico de undo/redo e o SpatialGrid antigo
      repo.clearMap(); 
      
      repo._mapData = newData;
      repo._rebuildSpatialIndex();
      
      notifyListeners();
    } finally {
      repo._setBusy(false);
    }
  }

  Future<void> importMapFile(String filePath, String converterName) async {
    final repo = this as MapRepository;
    repo._setBusy(true);
    try {
      final rawText = await File(filePath).readAsString();
      final session = await ensureActiveSession(converterName);

      _pushMapHistory(repo._mapData);

      final parsedMap = await session.invoke('import', {'raw_text': rawText});
      if (parsedMap == null) {
        throw Exception('Converter "$converterName" does not support import.');
      }

      final rawProvData = parsedMap['provinces'];
      final Iterable rawProvinces = rawProvData is List ? rawProvData : (rawProvData is Map ? rawProvData.values : []);
      final provinces = <ProvinceModel>[];
      int skippedInvalid = 0;
      
      for (final p in rawProvinces) {
        if (p is! Map) continue;
        
        final rawX = p['x'];
        final rawY = p['y'];
        final Iterable iterX = rawX is List ? rawX : (rawX is Map ? rawX.values : []);
        final Iterable iterY = rawY is List ? rawY : (rawY is Map ? rawY.values : []);
        final xs = iterX.map((e) => (e as num).toInt()).toList();
        final ys = iterY.map((e) => (e as num).toInt()).toList();

        if (xs.length < 3 || ys.length < 3 || xs.length != ys.length) {
          skippedInvalid++;
          continue;
        }

        provinces.add(ProvinceModel.fromPoints(
          id: (p['id'] as num).toInt(),
          xs: xs,
          ys: ys,
          colorValue: p['color'] != null ? (p['color'] as num).toInt() : null,
        ));
      }

      _lastImportWarning = skippedInvalid > 0 ? '$skippedInvalid província(s) inválida(s) ignoradas.' : null;
      
      repo._mapData = EngineMapData(
        formatVersion: (parsedMap['formatVersion'] ?? parsedMap['format_version'] ?? 1) as int,
        generatedAt: DateTime.now(),
        provinces: provinces,
        worldBounds: EngineMapData.computeWorldBounds(provinces),
      );
      
      repo._rebuildSpatialIndex();
      notifyListeners();
      await repo.storage.saveMapCache(repo._mapData);
    } finally {
      repo._setBusy(false);
    }
  }

  Future<String?> exportMapFile(String converterName) async {
    final repo = this as MapRepository;
    repo._setBusy(true);
    try {
      final session = await ensureActiveSession(converterName);
      final result = await session.invoke('export', {'map_data': repo._mapData.toJson()});
      return result?['text'] as String?;
    } finally {
      repo._setBusy(false);
    }
  }

  Future<String?> exportSingleProvinceFile(int provinceId, String converterName) async {
    final repo = this as MapRepository;
    final province = repo._mapData.findById(provinceId);
    if (province == null) return null;
    
    repo._setBusy(true);
    try {
      final session = await ensureActiveSession(converterName);

      final result = await session.invoke('export_province', {
        'xs': province.pointsX.toList(),
        'ys': province.pointsY.toList(),
      });
      return result?['text'] as String?;
    } finally {
      repo._setBusy(false);
    }
  }

  Future<({int success, int failed})> importMultipleProvinces(List<String> filePaths, String converterName) async {
    final repo = this as MapRepository;
    repo._setBusy(true);
    int success = 0;
    int failed = 0;
    
    try {
      final session = await ensureActiveSession(converterName);
      final newProvinces = <ProvinceModel>[];
      int nextId = repo._nextAvailableId();
      
      Future<void> processContent(String rawText) async {
        try {
          final trimmed = rawText.trim();
          if (trimmed.isEmpty) {
            failed++;
            return;
          }

          List<int>? xs;
          List<int>? ys;

          try {
            final result = await session.invoke('import_province', {'raw_text': trimmed});
            if (result != null && result['ok'] == true) {
              final rawXs = result['xs'];
              final rawYs = result['ys'];
              if (rawXs is List && rawYs is List) {
                xs = rawXs.map((e) => (e as num).toInt()).toList();
                ys = rawYs.map((e) => (e as num).toInt()).toList();
              }
            }
          } catch (_) {}

          if (xs == null || ys == null || xs.isEmpty || ys.isEmpty) {
            if (trimmed.contains(';')) {
              final parts = trimmed.split(';');
              if (parts.length >= 2) {
                final rawXList = parts[0].replaceAll(RegExp(r'[\r\n]'), '').split(',');
                final rawYList = parts[1].replaceAll(RegExp(r'[\r\n]'), '').split(',');
                
                final parsedXs = <int>[];
                for (final s in rawXList) {
                  final n = int.tryParse(s.trim());
                  if (n != null) parsedXs.add(n);
                }

                final parsedYs = <int>[];
                for (final s in rawYList) {
                  final n = int.tryParse(s.trim());
                  if (n != null) parsedYs.add(n);
                }

                if (parsedXs.length >= 3 && parsedXs.length == parsedYs.length) {
                  xs = parsedXs;
                  ys = parsedYs;
                }
              }
            } else {
              final lines = trimmed.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
              if (lines.length >= 2) {
                final rawXList = lines[0].split(',');
                final rawYList = lines[1].split(',');

                final parsedXs = <int>[];
                for (final s in rawXList) {
                  final n = int.tryParse(s.trim());
                  if (n != null) parsedXs.add(n);
                }

                final parsedYs = <int>[];
                for (final s in rawYList) {
                  final n = int.tryParse(s.trim());
                  if (n != null) parsedYs.add(n);
                }

                if (parsedXs.length >= 3 && parsedXs.length == parsedYs.length) {
                  xs = parsedXs;
                  ys = parsedYs;
                }
              }
            }
          }

          if (xs != null && ys != null && xs.length >= 3 && xs.length == ys.length) {
            newProvinces.add(ProvinceModel.fromPoints(
              id: nextId++,
              xs: xs,
              ys: ys,
            ));
            success++;
          } else {
            failed++;
          }
        } catch (_) {
          failed++;
        }
      }

      for (final path in filePaths) {
        final fileName = path.split(Platform.pathSeparator).last;
        final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
        
        if (ext == 'zip') {
          try {
            final contents = await repo.storage.extractTextFilesFromZip(path);
            for (final content in contents) {
              await processContent(content);
            }
          } catch (_) {
            failed++;
          }
        } else {
          try {
            final bytes = await File(path).readAsBytes();
            final content = utf8.decode(bytes, allowMalformed: true);
            await processContent(content);
          } catch (_) {
            failed++;
          }
        }
      }

      if (newProvinces.isNotEmpty) {
        _pushMapHistory(repo._mapData);
        repo._mapData = repo._mapData.upsertMany(newProvinces);
        repo._rebuildSpatialIndex();
        notifyListeners();
        await repo.storage.saveMapCache(repo._mapData);
      }
    } finally {
      repo._setBusy(false);
    }
    
    return (success: success, failed: failed);
  }
}