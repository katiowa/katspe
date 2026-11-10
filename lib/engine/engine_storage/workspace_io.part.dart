part of '../engine_storage.dart';

mixin _WorkspaceIO on _EngineStorageBase, _PathsIO {
  Future<String?> getBackgroundPath() async {
    final dir = await _mapDir;
    if (await dir.exists()) {
      final files = await dir.list().toList();
      for (var file in files) {
        if (file is File && p.basename(file.path).startsWith('background.')) {
          return file.path;
        }
      }
    }
    return null;
  }

  Future<String?> saveBackground(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return null;

      final ext = p.extension(sourcePath).toLowerCase();
      final dir = await _mapDir;
      final destFile = File('${dir.path}${Platform.pathSeparator}background$ext');

      final files = await dir.list().toList();
      await Future.wait([
        for (final file in files)
          if (file is File && p.basename(file.path).startsWith('background.')) file.delete(),
      ]);

      final copied = await sourceFile.copy(destFile.path);
      return copied.path;
    } catch (e) {
      return null;
    }
  }

  Future<String?> cloneImportedFile(String sourcePath) async {
    try {
      final file = File(sourcePath);
      if (!await file.exists()) return null;

      final dir = await getImportedFilesDir();
      final basename = p.basename(sourcePath);
      final dest = File('${dir.path}${Platform.pathSeparator}$basename');

      await file.copy(dest.path);
      return dest.path;
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteImportedFile(String fileName) async {
    try {
      final dir = await getImportedFilesDir();
      final dest = File('${dir.path}${Platform.pathSeparator}$fileName');
      if (await dest.exists()) await dest.delete();
    } catch (_) {}
  }

  Future<void> saveImportedFilesManifest(Map<String, dynamic> manifest) async {
    final dir = await _mapDir;
    final file = File('${dir.path}${Platform.pathSeparator}imported_files.json');
    await file.writeAsString(jsonEncode(manifest));
  }

  Future<Map<String, dynamic>?> loadImportedFilesManifest() async {
    final dir = await _mapDir;
    final file = File('${dir.path}${Platform.pathSeparator}imported_files.json');
    if (!await file.exists()) return null;
    return jsonDecode(await file.readAsString());
  }

  Future<void> clearWorkspace() async {
    final mapDir = await _mapDir;
    final propsDirectory = await propsDir;

    final deletions = <Future<void>>[];

    if (await mapDir.exists()) {
      for (var file in await mapDir.list().toList()) {
        if (file is File) {
          deletions.add(file.delete());
        } else if (file is Directory && p.basename(file.path) == 'imported') {
          deletions.add(file.delete(recursive: true)); 
        }
      }
    }

    if (await propsDirectory.exists()) {
      for (var file in await propsDirectory.list().toList()) {
        if (file is File) deletions.add(file.delete());
      }
      final imgDir = Directory('${propsDirectory.path}${Platform.pathSeparator}images');
      if (await imgDir.exists()) {
        for (var file in await imgDir.list().toList()) {
          if (file is File) deletions.add(file.delete());
        }
      }
    }

    await Future.wait(deletions);
  }
}