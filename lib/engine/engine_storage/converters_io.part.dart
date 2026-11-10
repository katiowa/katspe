part of '../engine_storage.dart';

mixin _ConvertersIO on _EngineStorageBase, _PathsIO {
  List<String>? _availableConvertersCache;

  void invalidateConvertersCache() {
    _availableConvertersCache = null;
  }

  Future<List<String>> getAvailableConverters() async {
    if (_availableConvertersCache != null) return _availableConvertersCache!;
    
    final dir = await _convertersDir;
    final converters = <String>[];

    if (await dir.exists()) {
      final entities = await dir.list().toList();
      for (final entity in entities) {
        if (entity is Directory) {
          final name = p.basename(entity.path);
          if (name != 'map-editor') {
            converters.add(name);
          }
        }
      }
    }

    converters.sort();
    _availableConvertersCache = converters;
    return converters;
  }

  Future<String?> resolveActiveConverter(String? savedConverter) async {
    if (savedConverter == '__none__') return null;

    final available = await getAvailableConverters();
    if (savedConverter != null && available.contains(savedConverter)) {
      return savedConverter;
    }
    
    if (savedConverter == null && available.length == 1) return available.first;
    return null;
  }

  Future<List<ConverterDisplayModel>> getConvertersDisplayInfo() async {
    final dir = await _convertersDir;
    final list = <ConverterDisplayModel>[];

    if (await dir.exists()) {
      for (final entity in await dir.list().toList()) {
        if (entity is Directory) {
          final folderName = p.basename(entity.path);
          if (folderName == 'map-editor') continue;

          final widgetDir = Directory('${entity.path}${Platform.pathSeparator}widget');
          final displayFile = File('${widgetDir.path}${Platform.pathSeparator}display.json');

          if (await displayFile.exists()) {
            try {
              final jsonContent = await displayFile.readAsString();
              final map = jsonDecode(jsonContent) as Map<String, dynamic>;

              final imageName = map['image']?.toString() ?? 'default.png';
              final imagePath = '${widgetDir.path}${Platform.pathSeparator}images${Platform.pathSeparator}$imageName';

              list.add(ConverterDisplayModel.fromJson(folderName, imagePath, map));
            // ignore: empty_catches
            } catch (e) {
            }
          }
        }
      }
    }
    list.sort((a, b) => a.title.compareTo(b.title));
    return list;
  }

  Future<ConverterDisplayModel?> getConverterDisplayInfo(String folderName) async {
    final list = await getConvertersDisplayInfo();
    for (final c in list) {
      if (c.folderName == folderName) return c;
    }
    return null;
  }

  Future<ConverterEntryPoint?> loadConverterEntryPoint(String converterName) async {
    final dir = await _convertersDir;

    final mainFile = File('${dir.path}${Platform.pathSeparator}$converterName${Platform.pathSeparator}main.lua');
    if (!await mainFile.exists()) return null;

    final coreFile = File('${dir.path}${Platform.pathSeparator}map-editor${Platform.pathSeparator}core.lua');
    String coreText = await coreFile.exists() ? await coreFile.readAsString() : '';
    String mainText = await mainFile.readAsString();

    coreText = coreText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    mainText = mainText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (coreText.startsWith('\uFEFF')) coreText = coreText.substring(1);
    if (mainText.startsWith('\uFEFF')) mainText = mainText.substring(1);

    final buffer = StringBuffer();
    if (coreText.trim().isNotEmpty) {
      buffer.writeln(coreText);
      buffer.writeln();
    }
    buffer.writeln(mainText);

    return ConverterEntryPoint(
      script: buffer.toString(),
      rootPath: '${dir.path}${Platform.pathSeparator}$converterName',
    );
  }

  /// Remove permanentemente a pasta do conversor e invalida o cache da engine.
  Future<void> deleteConverter(String folderName) async {
    if (folderName.isEmpty || folderName == 'map-editor') return;
    final dir = await _convertersDir;
    final target = Directory('${dir.path}${Platform.pathSeparator}$folderName');
    if (await target.exists()) {
      await target.delete(recursive: true);
    }
    invalidateConvertersCache();
  }
}