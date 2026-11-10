import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'app_preferences.dart';

class LanguageItem {
  final String fileName;    // ex: "english.json"
  final String displayName; // ex: "English"
  final String? flagPath;   // null se não encontrar bandeira nem genérica

  LanguageItem({
    required this.fileName,
    required this.displayName,
    this.flagPath,
  });
}

class LanguageController extends ChangeNotifier {
  final AppPreferences preferences;
  
  Map<String, String> _translations = {};
  List<LanguageItem> availableLanguages = [];
  LanguageItem? currentLanguage;

  LanguageController({required this.preferences});

  /// Retorna o texto traduzido ou a chave literal se não existir.
  String get(String key) {
    return _translations[key] ?? key;
  }

  /// Inicializa o sistema varrendo os arquivos e aplicando a lógica pragmática e extensível.
  Future<void> init() async {
    final engineDir = await getEngineDirectory();
    final langDir = Directory('${engineDir.path}${Platform.pathSeparator}languages');
    if (!await langDir.exists()) await langDir.create(recursive: true);
    
    final flagsDir = Directory('${langDir.path}${Platform.pathSeparator}flags');
    if (!await flagsDir.exists()) await flagsDir.create(recursive: true);

    // 1. Mapear IMAGENS disponíveis de forma agnóstica a extensões (.png, .webp, .gif, etc)
    final flagMap = <String, String>{};
    final flagEntities = await flagsDir.list().toList();
    for (final entity in flagEntities) {
      if (entity is File) {
        final baseName = p.basenameWithoutExtension(entity.path);
        flagMap[baseName] = entity.path; // Último sobrescreve em caso de duplicata (seguro)
      }
    }

    // 2. Montar lista de idiomas disponíveis
    final langs = <LanguageItem>[];
    final entries = await langDir.list().toList();
    final files = entries.whereType<File>().where((f) => f.path.endsWith('.json'));

    for (final file in files) {
      final fileName = p.basename(file.path);
      final nameWithoutExt = p.basenameWithoutExtension(fileName);
      
      // Primeira letra maiúscula
      final displayName = nameWithoutExt.isEmpty 
          ? 'Unknown' 
          : nameWithoutExt[0].toUpperCase() + nameWithoutExt.substring(1).toLowerCase();

      // Resolver lógica de bandeiras sem hardcoding de extensões
      String? flagPath = flagMap[nameWithoutExt] ?? flagMap['generic'];

      langs.add(LanguageItem(
        fileName: fileName,
        displayName: displayName,
        flagPath: flagPath,
      ));
    }

    availableLanguages = langs;
    if (langs.isEmpty) return;

    // 3. Lógica de Seleção (Fallbacks)
    bool isLoaded = false;
    final savedLang = preferences.language;

    // Prioridade 1: Preferência salva do usuário
    if (savedLang != null) {
      isLoaded = await _tryLoadLanguage(savedLang, langDir.path);
    }

    // Prioridade 2: english.json num try-catch isolado
    if (!isLoaded) {
      try {
        isLoaded = await _tryLoadLanguage('english.json', langDir.path);
      } catch (e) {
        debugPrint('Erro ao tentar carregar o fallback english.json: $e');
      }
    }

    // Prioridade 3: Pegar o primeiro arquivo disponível na pasta (Aleatório/Fallback final)
    if (!isLoaded && availableLanguages.isNotEmpty) {
      await _tryLoadLanguage(availableLanguages.first.fileName, langDir.path);
    }
  }

  /// Troca o idioma a partir da UI (Menu de configurações)
  Future<void> setLanguage(String fileName) async {
    final engineDir = await getEngineDirectory();
    final langDir = Directory('${engineDir.path}${Platform.pathSeparator}languages');
    
    final success = await _tryLoadLanguage(fileName, langDir.path);
    if (success) {
      await preferences.setLanguage(fileName);
    }
  }

  /// Remove o arquivo do idioma e sua bandeira associada.
  Future<bool> deleteLanguage(String fileName) async {
    // english.json é o fallback central e nunca deve ser removido, nem se for o único idioma restante
    if (fileName == 'english.json' || availableLanguages.length <= 1) return false;

    final engineDir = await getEngineDirectory();
    final langDir = Directory('${engineDir.path}${Platform.pathSeparator}languages');
    final file = File('${langDir.path}${Platform.pathSeparator}$fileName');
    if (await file.exists()) {
      await file.delete();
    }

    // Apaga também a imagem da bandeira correspondente se existir
    final nameWithoutExt = p.basenameWithoutExtension(fileName);
    final flagsDir = Directory('${langDir.path}${Platform.pathSeparator}flags');
    if (await flagsDir.exists()) {
      final flagEntities = await flagsDir.list().toList();
      for (final entity in flagEntities) {
        if (entity is File && p.basenameWithoutExtension(entity.path) == nameWithoutExt) {
          await entity.delete();
        }
      }
    }

    // Se o idioma apagado for o atualmente ativo, faz fallback seguro
    if (currentLanguage?.fileName == fileName) {
      final fallback = availableLanguages.firstWhere(
        (l) => l.fileName != fileName,
        orElse: () => LanguageItem(fileName: 'english.json', displayName: 'English'),
      );
      await setLanguage(fallback.fileName);
    }

    await init();
    return true;
  }

  /// Realiza a leitura física do JSON e aplica no mapa de memória
  Future<bool> _tryLoadLanguage(String fileName, String folderPath) async {
    final file = File('$folderPath${Platform.pathSeparator}$fileName');
    if (!await file.exists()) return false;

    try {
      final content = await file.readAsString();
      final Map<String, dynamic> json = jsonDecode(content);
      
      _translations = json.map((key, value) => MapEntry(key, value.toString()));
      
      // Atualiza o marcador do idioma atual
      currentLanguage = availableLanguages.firstWhere(
        (l) => l.fileName == fileName, 
        orElse: () => LanguageItem(fileName: fileName, displayName: 'Unknown'),
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Erro no parser do arquivo $fileName: $e');
      return false;
    }
  }
}