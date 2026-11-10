part of '../engine_storage.dart';

mixin _PropsIO on _EngineStorageBase, _PathsIO {
  Future<String?> savePropImage(String sourcePath) async {
    try {
      final file = File(sourcePath);
      if (!await file.exists()) return null;

      final dir = await propsImagesDir;
      final basename = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
      final dest = File('${dir.path}${Platform.pathSeparator}$basename');

      await file.copy(dest.path);
      return basename;
    } catch (e) {
      return null;
    }
  }

  Future<void> deletePropImage(String fileName) async {
    try {
      final dir = await propsImagesDir;
      final dest = File('${dir.path}${Platform.pathSeparator}$fileName');
      if (await dest.exists()) await dest.delete();
    } catch (_) {}
  }

  Future<void> savePropsManifest(List<Map<String, dynamic>> manifest) async {
    final dir = await propsDir;
    final file = File('${dir.path}${Platform.pathSeparator}props.json');
    await file.writeAsString(jsonEncode(manifest));
  }

  Future<List<Map<String, dynamic>>?> loadPropsManifest() async {
    final dir = await propsDir;
    final file = File('${dir.path}${Platform.pathSeparator}props.json');
    if (!await file.exists()) return null;
    
    try {
      final json = jsonDecode(await file.readAsString());
      if (json is List) return json.cast<Map<String, dynamic>>();
    } catch (_) {}
    return null;
  }
}