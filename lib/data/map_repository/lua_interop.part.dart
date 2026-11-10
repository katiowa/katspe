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

  Future<void> importSingleProvinceFile(String filePath, String converterName) async {
    final repo = this as MapRepository;
    repo._setBusy(true);
    try {
      final rawText = await File(filePath).readAsString();
      final session = await ensureActiveSession(converterName);

      final result = await session.invoke('import_province', {'raw_text': rawText});
      if (result == null || result['ok'] != true) {
        throw Exception('Converter "$converterName" não suporta importar província individual.');
      }

      final xs = (result['xs'] as List).cast<int>();
      final ys = (result['ys'] as List).cast<int>();

      final newId = repo._nextAvailableId();

      final newProv = ProvinceModel.fromPoints(
        id: newId,
        xs: xs,
        ys: ys,
      );

      _pushMapHistory(repo._mapData);
      repo._mapData = repo._mapData.upsertProvince(newProv);
      repo._rebuildSpatialIndex();
      notifyListeners();
      await repo.storage.saveMapCache(repo._mapData);
    } finally {
      repo._setBusy(false);
    }
  }
}