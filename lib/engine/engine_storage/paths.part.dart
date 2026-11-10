part of '../engine_storage.dart';

mixin _PathsIO on _EngineStorageBase {
  Future<Directory> get _preferencesDir async {
    final engineDir = await getEngineDirectory();
    final dir = Directory('${engineDir.path}${Platform.pathSeparator}preferences');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> get _mapDir async {
    final prefDir = await _preferencesDir;
    final dir = Directory('${prefDir.path}${Platform.pathSeparator}map');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> getImportedFilesDir() async {
    final mapDir = await _mapDir;
    final dir = Directory('${mapDir.path}${Platform.pathSeparator}imported');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> get propsDir async {
    final prefDir = await _preferencesDir;
    final dir = Directory('${prefDir.path}${Platform.pathSeparator}props');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> get propsImagesDir async {
    final rootProps = await propsDir;
    final imgDir = Directory('${rootProps.path}${Platform.pathSeparator}images');
    if (!await imgDir.exists()) await imgDir.create(recursive: true);
    return imgDir;
  }

  Future<Directory> get _cacheDir async {
    final mapDir = await _mapDir;
    final dir = Directory('${mapDir.path}${Platform.pathSeparator}${config.cacheDirectoryName}');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> get _mapCacheFile async {
    final dir = await _cacheDir;
    return File('${dir.path}${Platform.pathSeparator}${config.cacheFileName}');
  }

  Future<Directory> get _convertersDir async {
    final engineDir = await getEngineDirectory();
    final dir = Directory('${engineDir.path}${Platform.pathSeparator}converters');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}