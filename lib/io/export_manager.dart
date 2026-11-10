import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../data/map_repository.dart';

class ExportOptions {
  final bool exportFullMap;
  final bool exportTargetProvinceOnly;
  final bool exportProvincesZip;
  final int? targetProvinceId;

  /// Which POI category ids (whatever the active converter's Lua
  /// declared via `poi_categories`) to also export as a batch file.
  /// Replaces the old fixed `exportCities`/`exportMountains`/
  /// `exportWonders` — the engine has no idea how many categories exist
  /// or what they're called, so this can't be three named booleans.
  final Set<String> exportPoiCategories;

  /// Which converter to use for every export above. Nullable on
  /// purpose: the engine has no default converter to assume — this stays
  /// null until the UI resolves it dynamically against whatever converters
  /// actually exist on disk (see `EngineStorageManager.resolveActiveConverter`
  /// and `_ExportPanelState.initState`).
  final String? converterName;

  const ExportOptions({
    this.exportFullMap = true,
    this.exportTargetProvinceOnly = false,
    this.exportProvincesZip = false,
    this.targetProvinceId,
    this.exportPoiCategories = const {},
    this.converterName,
  });

  ExportOptions copyWith({
    bool? exportFullMap,
    bool? exportTargetProvinceOnly,
    bool? exportProvincesZip,
    int? targetProvinceId,
    Set<String>? exportPoiCategories,
    String? converterName,
  }) =>
      ExportOptions(
        exportFullMap: exportFullMap ?? this.exportFullMap,
        exportTargetProvinceOnly:
            exportTargetProvinceOnly ?? this.exportTargetProvinceOnly,
        exportProvincesZip: exportProvincesZip ?? this.exportProvincesZip,
        targetProvinceId: targetProvinceId ?? this.targetProvinceId,
        exportPoiCategories: exportPoiCategories ?? this.exportPoiCategories,
        converterName: converterName ?? this.converterName,
      );

  bool get hasAnythingSelected =>
      exportFullMap || exportTargetProvinceOnly || exportProvincesZip || exportPoiCategories.isNotEmpty;
}

class ExportResult {
  final List<String> writtenFiles;
  const ExportResult(this.writtenFiles);
}

Future<ExportResult> runExport({
  required ExportOptions options,
  required MapRepository mapRepository,
  required Future<String?> Function(String suggestedFileName, Uint8List bytes) saveFile,
}) async {
  final written = <String>[];

  if (options.converterName == null) return ExportResult(written);
  
  // Resolve qual é a extensão preferida do formato atual de forma nativa e sem hardcode
  final info = await mapRepository.storage.getConverterDisplayInfo(options.converterName!);
  final ext = info?.supportedExtensions.isNotEmpty == true ? info!.supportedExtensions.first : 'txt';

  if (options.exportFullMap) {
    final text = await mapRepository.exportMapFile(options.converterName!);
    if (text != null) {
      final path = await saveFile('map.$ext', Uint8List.fromList(utf8.encode(text)));
      if (path != null) written.add(path);
    }
  }

  if (options.exportTargetProvinceOnly && options.targetProvinceId != null) {
    var text = await mapRepository.exportSingleProvinceFile(options.targetProvinceId!, options.converterName!);
    
    if (text == null) {
      final p = mapRepository.mapData.findById(options.targetProvinceId!);
      if (p != null) {
        text = '${p.pointsX.join(',')};${p.pointsY.join(',')}';
      }
    }

    if (text != null) {
      final path = await saveFile('${options.targetProvinceId}.$ext', Uint8List.fromList(utf8.encode(text)));
      if (path != null) written.add(path);
    }
  }

  if (options.exportProvincesZip) {
    final session = await mapRepository.ensureActiveSession(options.converterName!);
    final filesToZip = <Map<String, dynamic>>[];

    for (final prov in mapRepository.mapData.provinces) {
      String? text;
      try {
        final result = await session.invoke('export_province', {
          'xs': prov.pointsX.toList(),
          'ys': prov.pointsY.toList(),
        });
        text = result?['text'] as String?;
      } catch (_) {}

      text ??= '${prov.pointsX.join(',')};${prov.pointsY.join(',')}';

      filesToZip.add({
        'name': '${prov.id}.$ext',
        'bytes': utf8.encode(text),
      });
    }

    final zipBytes = await Isolate.run(() {
      final archive = Archive();
      for (final f in filesToZip) {
        final name = f['name'] as String;
        final bytes = f['bytes'] as List<int>;
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }
      return Uint8List.fromList(ZipEncoder().encode(archive));
    });

    final path = await saveFile('provinces.zip', zipBytes);
    if (path != null) written.add(path);
  }

  if (options.exportPoiCategories.isNotEmpty) {
    final session = await mapRepository.ensureActiveSession(options.converterName!);
    for (final category in options.exportPoiCategories) {
      final result = await session.invoke('poi_export_batch', {'category': category});
      final text = result?['text'] as String?;
      if (text == null) continue;

      final path = await saveFile('$category.json', Uint8List.fromList(utf8.encode(text)));
      if (path != null) written.add(path);
    }
  }

  return ExportResult(written);
}