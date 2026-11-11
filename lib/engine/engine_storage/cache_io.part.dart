part of '../engine_storage.dart';

mixin _CacheIO on _EngineStorageBase, _PathsIO {
  Timer? _saveDebounceTimer;
  EngineMapData? _pendingSaveData;
  List<Completer<void>> _pendingSaveCompleters = [];

  Future<void> saveMapCache(EngineMapData data) {
    _pendingSaveData = data;
    final completer = Completer<void>();
    _pendingSaveCompleters.add(completer);

    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 800), () async {
      final dataToSave = _pendingSaveData;
      final completers = _pendingSaveCompleters;
      _pendingSaveData = null;
      _pendingSaveCompleters = [];
      if (dataToSave == null) return;
      try {
        await _writeMapCache(dataToSave);
        for (final c in completers) {
          if (!c.isCompleted) c.complete();
        }
      } catch (e, st) {
        for (final c in completers) {
          if (!c.isCompleted) c.completeError(e, st);
        }
      }
    });

    return completer.future;
  }

  Future<void> flushMapCache() async {
    _saveDebounceTimer?.cancel();
    final dataToSave = _pendingSaveData;
    final completers = _pendingSaveCompleters;
    _pendingSaveData = null;
    _pendingSaveCompleters = [];
    if (dataToSave == null) return;
    try {
      await _writeMapCache(dataToSave);
      for (final c in completers) {
        if (!c.isCompleted) c.complete();
      }
    } catch (e, st) {
      for (final c in completers) {
        if (!c.isCompleted) c.completeError(e, st);
      }
    }
  }

  Future<void> _writeMapCache(EngineMapData data) async {
    final file = await _mapCacheFile;
    final Uint8List bytes = await Isolate.run(() => _buildFlatBuffer(data));

    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsBytes(bytes, flush: true);
    await tempFile.rename(file.path);
  }

  Future<EngineMapData?> loadMapCache() async {
    final file = await _mapCacheFile;
    if (!await file.exists()) return null;

    try {
      final bytes = await file.readAsBytes();
      return await Isolate.run(() => _parseFlatBuffer(bytes));
    } catch (e) {
      return null;
    }
  }

  /// NOVO: Importação Nativa do Binário usando Swap Atômico (A/B)
  Future<EngineMapData> importNativeMapCache(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception("Source file does not exist.");
    }
    
    // 1. Lemos e validamos os bytes numa Isolate.
    // Se não for um cache gerado pelo FlatBuffers, o parser (_parseFlatBuffer) falhará
    // estourando uma exception antes de chegarmos a encostar no arquivo final.
    final bytes = await sourceFile.readAsBytes();
    final parsedData = await Isolate.run(() => _parseFlatBuffer(bytes));

    final destFile = await _mapCacheFile;
    // O nome do arquivo backup usará .old.bin, mantendo a extensão segura pro Windows
    final backupFile = File('${destFile.path}.old.bin');

    if (!await destFile.parent.exists()) {
      await destFile.parent.create(recursive: true);
    }

    bool backupCreated = false;
    try {
      // 2. Criação do backup caso já exista o arquivo oficial
      if (await destFile.exists()) {
        await destFile.rename(backupFile.path);
        backupCreated = true;
      }
      
      // 3. Efetivação
      await sourceFile.copy(destFile.path);

      // 4. Sucesso: Deleta backup
      if (backupCreated && await backupFile.exists()) {
        await backupFile.delete();
      }

      return parsedData;
    } catch (e) {
      // Falha: Estratégia de Rollback
      if (await destFile.exists()) {
        await destFile.delete();
      }
      if (backupCreated && await backupFile.exists()) {
        await backupFile.rename(destFile.path);
      }
      throw Exception('Atomic swap failed: $e');
    }
  }

  static Uint8List _buildFlatBuffer(EngineMapData data) {
    final provincesFb = data.provinces.map((p) {
      return ProvinceFbObjectBuilder(
        id: p.id,
        pointsX: p.pointsX.toList(),
        pointsY: p.pointsY.toList(),
        bbox: BoundingBoxFbObjectBuilder(
          minX: p.boundingBox.minX,
          minY: p.boundingBox.minY,
          maxX: p.boundingBox.maxX,
          maxY: p.boundingBox.maxY,
        ),
        colorValue: p.colorValue,
      );
    }).toList();

    final mapDataFb = MapDataFbObjectBuilder(
      formatVersion: data.formatVersion,
      generatedAtMs: data.generatedAt.millisecondsSinceEpoch,
      provinces: provincesFb,
      worldBbox: BoundingBoxFbObjectBuilder(
        minX: data.worldBounds.minX,
        minY: data.worldBounds.minY,
        maxX: data.worldBounds.maxX,
        maxY: data.worldBounds.maxY,
      ),
    );

    return mapDataFb.toBytes();
  }

  static EngineMapData _parseFlatBuffer(Uint8List bytes) {
    final mapDataFb = MapDataFb(bytes);

    final provincesFb = mapDataFb.provinces ?? [];
    final provinces = provincesFb.map((p) {
      final pointsX = Int32List.fromList(p.pointsX ?? []);
      final pointsY = Int32List.fromList(p.pointsY ?? []);
      final bboxFb = p.bbox;
      final boundingBox = bboxFb != null
          ? BoundingBox(minX: bboxFb.minX, minY: bboxFb.minY, maxX: bboxFb.maxX, maxY: bboxFb.maxY)
          : BoundingBox.fromPoints(pointsX, pointsY);
      return ProvinceModel(
        id: p.id,
        pointsX: pointsX,
        pointsY: pointsY,
        boundingBox: boundingBox,
        colorValue: p.colorValue,
      );
    }).toList();

    final wBboxFb = mapDataFb.worldBbox;
    final worldBounds = wBboxFb != null
        ? BoundingBox(minX: wBboxFb.minX, minY: wBboxFb.minY, maxX: wBboxFb.maxX, maxY: wBboxFb.maxY)
        : EngineMapData.computeWorldBounds(provinces);

    return EngineMapData(
      formatVersion: mapDataFb.formatVersion,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(mapDataFb.generatedAtMs),
      provinces: provinces,
      worldBounds: worldBounds,
    );
  }
}