part of '../engine_storage.dart';

mixin _ImportIO on _EngineStorageBase, _PathsIO {
  /// Extrai, valida pragmática e seguramente um pacote .zip de Idioma.
  Future<void> importLanguageZip(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    int totalSize = 0;
    const int maxSizeBytes = 5 * 1024 * 1024; // 5 MB de limite de segurança

    final validFiles = <ArchiveFile>[];

    for (final file in archive) {
      if (file.isFile) {
        final name = p.basename(file.name);
        // Ignora metadados gerados nativamente por SOs e diretórios invisíveis
        if (file.name.contains('__MACOSX') || name.startsWith('._') || name == '.DS_Store' || name == 'Thumbs.db') {
          continue;
        }

        // Validação 1: Anti-Zip Slip e Path Traversal
        final normalizedName = p.normalize(file.name);
        if (normalizedName.startsWith('/') || normalizedName.startsWith('\\') || normalizedName.contains('..')) {
          throw Exception('Security Error: Malicious path traversal detected inside ZIP.');
        }

        // Validação 2: Anti-Zip Bomb
        totalSize += file.size;
        if (totalSize > maxSizeBytes) {
          throw Exception('Security Error: The extracted size exceeds the 5MB safe limit.');
        }

        validFiles.add(file);
      }
    }

    // Validação Pragmática de Estrutura
    if (validFiles.length != 2) {
      throw Exception('Invalid format: The package must contain exactly 2 files (1 .json and 1 image).');
    }

    final jsonFiles = validFiles.where((f) => f.name.toLowerCase().endsWith('.json')).toList();
    if (jsonFiles.length != 1) {
      throw Exception('Invalid format: Expected exactly one .json file inside the package.');
    }

    final jsonFile = jsonFiles.first;
    final imageFile = validFiles.firstWhere((f) => f != jsonFile);

    // Garante que o Basename de ambos seja idêntico (ex: "pt-BR.json" e "pt-BR.webp")
    final jsonBasename = p.basenameWithoutExtension(p.basename(jsonFile.name));
    final imageBasename = p.basenameWithoutExtension(p.basename(imageFile.name));

    if (jsonBasename != imageBasename) {
      throw Exception('Invalid format: The image name ("$imageBasename") must perfectly match the .json name ("$jsonBasename").');
    }

    // Passou por todas as validações, podemos escrever no disco com segurança
    final engineDir = await getEngineDirectory();
    final langDir = Directory('${engineDir.path}${Platform.pathSeparator}languages');
    final flagsDir = Directory('${langDir.path}${Platform.pathSeparator}flags');

    if (!await flagsDir.exists()) await flagsDir.create(recursive: true);

    final jsonDest = File('${langDir.path}${Platform.pathSeparator}${p.basename(jsonFile.name)}');
    final imageDest = File('${flagsDir.path}${Platform.pathSeparator}${p.basename(imageFile.name)}');

    // Ao invocar writeAsBytes aqui, garantimos que um idioma importado com nome
    // igual a um já existente fará a substituição de forma silenciosa e limpa (Overwrite).
    await jsonDest.writeAsBytes(jsonFile.content as List<int>, flush: true);
    await imageDest.writeAsBytes(imageFile.content as List<int>, flush: true);
  }

  /// Extrai, valida pragmática e seguramente um pacote .zip de Conversor.
  /// Retorna o nome da pasta do conversor criado, para que a UI possa auto-selecioná-lo.
  Future<String> importConverterZip(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    int totalSize = 0;
    const int maxSizeBytes = 50 * 1024 * 1024; // 50 MB (conversores podem ter imagens de UI)

    final validFiles = <ArchiveFile>[];
    ArchiveFile? mainLuaFile;
    String? mainLuaPrefix;

    for (final file in archive) {
      if (file.isFile) {
        final name = p.basename(file.name);
        if (file.name.contains('__MACOSX') || name.startsWith('._') || name == '.DS_Store' || name == 'Thumbs.db') {
          continue;
        }

        final normalizedName = p.normalize(file.name);
        if (normalizedName.startsWith('/') || normalizedName.startsWith('\\') || normalizedName.contains('..')) {
          throw Exception('Security Error: Malicious path traversal detected inside ZIP.');
        }

        totalSize += file.size;
        if (totalSize > maxSizeBytes) {
          throw Exception('Security Error: The extracted size exceeds the 50MB safe limit.');
        }

        validFiles.add(file);
        
        // Procuramos o main.lua mais raso possível na hierarquia do zip
        if (name == 'main.lua') {
          if (mainLuaFile == null || file.name.length < mainLuaFile.name.length) {
            mainLuaFile = file;
            // Se file.name for "meu_mod/main.lua", o dir será "meu_mod" e o prefixo "meu_mod/"
            final dir = p.dirname(file.name);
            mainLuaPrefix = (dir == '.' || dir == '') ? '' : '$dir/';
          }
        }
      }
    }

    // Validação Pragmática de Estrutura
    if (mainLuaFile == null || mainLuaPrefix == null) {
      throw Exception('Invalid format: No "main.lua" found. A valid converter must contain a main.lua entry point.');
    }

    // Determina o nome do conversor (da pasta raiz ou do nome do zip)
    String converterName;
    if (mainLuaPrefix.isEmpty) {
      converterName = p.basenameWithoutExtension(zipPath);
    } else {
      final parts = mainLuaPrefix.split('/');
      converterName = parts.lastWhere((s) => s.isNotEmpty, orElse: () => p.basenameWithoutExtension(zipPath));
    }

    // Sanitiza o nome final da pasta para evitar caracteres inválidos
    converterName = converterName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (converterName.isEmpty || converterName == 'map-editor') {
      converterName = 'imported_converter_${DateTime.now().millisecondsSinceEpoch}';
    }

    final engineDir = await getEngineDirectory();
    final targetDir = Directory('${engineDir.path}${Platform.pathSeparator}converters${Platform.pathSeparator}$converterName');
    if (!await targetDir.exists()) await targetDir.create(recursive: true);

    // Salva apenas os arquivos que pertencem à pasta do conversor
    for (final file in validFiles) {
      if (file.name.startsWith(mainLuaPrefix)) {
        final relativePath = file.name.substring(mainLuaPrefix.length);
        if (relativePath.isEmpty) continue;

        final destFile = File('${targetDir.path}${Platform.pathSeparator}${p.normalize(relativePath)}');
        
        if (!await destFile.parent.exists()) {
          await destFile.parent.create(recursive: true);
        }
        await destFile.writeAsBytes(file.content as List<int>, flush: true);
      }
    }

    return converterName;
  }
}