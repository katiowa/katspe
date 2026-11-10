import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../core/app_preferences.dart';
import '../core/engine_context.dart';
import '../engine/engine_config.dart';
import '../engine/engine_storage.dart';
import 'initializer_contract.dart';

class StorageInitializer implements InitializerContract {
  @override
  String get name => 'Storage';

  @override
  String get loadingKey => 'boot_step_storage';

  @override
  Future<InitializerResult> run() async {
    try {
      final ctx = EngineContext.instance;
      ctx.preferences = AppPreferences();
      await ctx.preferences.load();
      ctx.config = const MapEngineConfig();
      ctx.storage = EngineStorageManager(config: ctx.config);
      
      final engineDir = await getEngineDirectory();
      
      // Auto-extrai os assets empacotados de fábrica se a pasta física estiver vazia (ex: primeiro boot no Android)
      await _seedEngineAssetsIfEmpty(engineDir);

      return const InitializerResult.ok('Preferences loaded and engine folder tree is ready.');
    } catch (e) {
      return InitializerResult.failure('Could not bring up storage: $e');
    }
  }

  /// Verifica se os arquivos base da engine existem fisicamente no disco.
  /// Se a pasta de idiomas estiver vazia, descompacta os templates padrão de fábrica embutidos no app.
  Future<void> _seedEngineAssetsIfEmpty(Directory engineDir) async {
    final langDir = Directory('${engineDir.path}${Platform.pathSeparator}languages');
    bool hasLanguages = false;

    if (await langDir.exists()) {
      final files = await langDir.list().toList();
      hasLanguages = files.any((f) => f is File && f.path.endsWith('.json'));
    }

    if (!hasLanguages) {
      List<String> assetPaths = [];

      // Compatibilidade universal para listagem de assets (Flutter 3.10+ e versões anteriores)
      try {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        assetPaths = manifest.listAssets();
      } catch (_) {
        try {
          final manifestContent = await rootBundle.loadString('AssetManifest.json');
          final Map<String, dynamic> manifestMap = jsonDecode(manifestContent);
          assetPaths = manifestMap.keys.toList();
        } catch (_) {}
      }

      // Filtra apenas os arquivos pertencentes à engine
      final engineAssets = assetPaths.where((path) => path.startsWith('engine/')).toList();

      for (final assetPath in engineAssets) {
        try {
          final byteData = await rootBundle.load(assetPath);
          final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

          // Remove o prefixo 'engine/' para manter a estrutura relativa
          final relativePath = assetPath.substring('engine/'.length);
          final targetFile = File('${engineDir.path}${Platform.pathSeparator}${p.normalize(relativePath)}');

          if (!await targetFile.parent.exists()) {
            await targetFile.parent.create(recursive: true);
          }

          await targetFile.writeAsBytes(bytes, flush: true);
        } catch (_) {
          // Arquivos ilegíveis ou diretórios vazios ignorados com segurança
        }
      }
    }
  }
}