import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Variável estática em cache para garantir que a engine NUNCA mude de pasta no meio da execução
Directory? _cachedEngineDir;

/// Central utility for locating the user-visible `engine` folder.
Future<Directory> getEngineDirectory() async {
  if (_cachedEngineDir != null) return _cachedEngineDir!;

  if (Platform.isAndroid) {
    final dir = await getExternalStorageDirectory();
    final baseDir = dir ?? await getApplicationDocumentsDirectory();
    _cachedEngineDir = Directory('${baseDir.path}${Platform.pathSeparator}engine');
  } else {
    // 1. TENTA A RAIZ DO WORKSPACE (Desenvolvimento no VS Code)
    try {
      final devEngine = Directory('${Directory.current.path}${Platform.pathSeparator}engine');
      if (await devEngine.exists()) {
        final testFile = File('${devEngine.path}${Platform.pathSeparator}.writable_test');
        await testFile.writeAsString('test', flush: true);
        await testFile.delete();
        _cachedEngineDir = devEngine;
        return _cachedEngineDir!;
      }
    } catch (_) {}

    // 2. TENTA A PASTA AO LADDO DO EXECUTÁVEL (Produção / Versão Portátil)
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final localEngine = Directory('$exeDir${Platform.pathSeparator}engine');
      
      if (!await localEngine.exists()) {
        await localEngine.create(recursive: true);
      }
      
      final testFile = File('${localEngine.path}${Platform.pathSeparator}.writable_test');
      await testFile.writeAsString('test', flush: true);
      await testFile.delete();

      _cachedEngineDir = localEngine;
      return _cachedEngineDir!;
    } catch (_) {
      // 3. FALLBACK DE SEGURANÇA (Caso esteja travado em Program Files)
      final docsDir = await getApplicationDocumentsDirectory();
      _cachedEngineDir = Directory('${docsDir.path}${Platform.pathSeparator}engine');
    }
  }

  if (!await _cachedEngineDir!.exists()) {
    await _cachedEngineDir!.create(recursive: true);
  }
  return _cachedEngineDir!;
}

class AppPreferences {
  Map<String, dynamic> _config = {};
  bool _isLoaded = false;

  Future<File> get _configFile async {
    final dir = await getEngineDirectory();
    final prefDir = Directory('${dir.path}${Platform.pathSeparator}preferences');
    if (!await prefDir.exists()) {
      await prefDir.create(recursive: true);
    }
    return File('${prefDir.path}${Platform.pathSeparator}configs.json');
  }

  /// Loads preferences from disk (or leaves them empty if none exist yet).
  Future<void> load() async {
    if (_isLoaded) return;

    final file = await _configFile;
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        _config = jsonDecode(content) as Map<String, dynamic>;
      } catch (e) {
        // If the JSON is corrupted, reset the config instead of crashing.
        _config = {};
      }
    }
    _isLoaded = true;
  }

  /// The saved language file name.
  String? get language => _config['language'] as String?;

  Future<void> setLanguage(String fileName) async {
    _config['language'] = fileName;
    await _save();
  }

  bool? get cullingEnabled => _config['cullingEnabled'] as bool?;

  Future<void> setCullingEnabled(bool value) async {
    _config['cullingEnabled'] = value;
    await _save();
  }

  double? get cullingMargin => (_config['cullingMargin'] as num?)?.toDouble();

  Future<void> setCullingMargin(double value) async {
    _config['cullingMargin'] = value;
    await _save();
  }
  
  double? get uiScale => (_config['uiScale'] as num?)?.toDouble();

  Future<void> setUiScale(double value) async {
    _config['uiScale'] = value;
    await _save();
  }

  Future<void> _save() async {
    final file = await _configFile;
    await file.writeAsString(jsonEncode(_config));
  }

  /// Reads the persisted converter choice. Converters are external,
  /// user-supplied content identified by their own folder name (e.g.
  /// `aoh2`) — the engine never rewrites or assumes that name, it only
  /// reads back whatever was saved.
  String? get selectedConverter => _config['selectedConverter'] as String?;

  /// Pode ser anulado (unselect) definindo converterName como nulo
  Future<void> setSelectedConverter(String? converterName) async {
    if (converterName == null) {
      _config.remove('selectedConverter');
    } else {
      _config['selectedConverter'] = converterName;
    }
    await _save();
  }
}