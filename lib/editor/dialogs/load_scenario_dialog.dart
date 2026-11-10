import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/language_controller.dart';
import '../../engine/engine_storage.dart';
import '../../theme/app_theme.dart';

Future<({String mapPath, String? bgPath, String converterName})?> showLoadScenarioDialog(
  BuildContext context, {
  required LanguageController langController,
  required EngineStorageManager storage,
}) async {
  String? mapPath;
  String? bgPath;

  // Busca agora a lista completa (com suporte a extensões e nomes amigáveis)
  final converters = await storage.getConvertersDisplayInfo();
  
  String? selectedConverter = converters.isNotEmpty ? converters.first.folderName : null;

  final confirmed = await showDialog<bool>(
    // ignore: use_build_context_synchronously
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) {
        
        // Constrói a Label dinamicamente com base nas extensões suportadas pelo conversor selecionado
        String mapFileLabel = langController.get('dialog_load_map_file');
        if (selectedConverter != null) {
          final info = converters.firstWhere((c) => c.folderName == selectedConverter);
          if (info.supportedExtensions.isNotEmpty) {
            mapFileLabel += ' (.${info.supportedExtensions.join(', .')})';
          }
        }

        return AlertDialog(
          backgroundColor: AppTheme.bg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd), side: const BorderSide(color: AppTheme.border)),
          title: Text(langController.get('dialog_load_title'), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(langController.get('dialog_load_format'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: AppTheme.bg1, border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    dropdownColor: AppTheme.bg1,
                    isExpanded: true,
                    value: selectedConverter,
                    hint: Text(langController.get('dialog_load_none'), style: const TextStyle(color: AppTheme.textDisabled, fontSize: 13)),
                    icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
                    onChanged: converters.isEmpty
                        ? null
                        : (String? newValue) {
                            if (newValue != null) setModalState(() => selectedConverter = newValue);
                          },
                    items: converters.map((c) => DropdownMenuItem<String>(
                      value: c.folderName,
                      child: Text(c.title.toUpperCase(), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(mapFileLabel, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: Text(mapPath ?? langController.get('dialog_load_none'), style: TextStyle(color: mapPath != null ? AppTheme.success : AppTheme.textDisabled, fontSize: 12), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () async {
                      List<String> exts = [];
                      if (selectedConverter != null) {
                        final info = converters.firstWhere((c) => c.folderName == selectedConverter);
                        exts = info.supportedExtensions;
                      }
                      
                      // Sempre abre FileType.any para que arquivos sem extensão sejam visíveis
                      final res = await FilePicker.pickFile(type: FileType.any);
                      
                      if (res != null && res.path != null) {
                        final path = res.path!;
                        final fileName = path.split(Platform.pathSeparator).last;
                        final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
                        
                        // Aceita se não tiver extensão OU se estiver na lista permitida
                        final isValid = ext.isEmpty || exts.isEmpty || exts.contains(ext);
                        
                        if (isValid) {
                          setModalState(() => mapPath = path);
                        }
                      }
                    },
                    child: Text(langController.get('dialog_load_browse')),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(langController.get('dialog_load_bg_file'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: Text(bgPath ?? langController.get('dialog_load_none'), style: TextStyle(color: bgPath != null ? AppTheme.info : AppTheme.textDisabled, fontSize: 12), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () async {
                      final res = await FilePicker.pickFile(type: FileType.image);
                      if (res != null) setModalState(() => bgPath = res.path);
                    },
                    child: Text(langController.get('dialog_load_browse')),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(langController.get('dialog_cancel'))),
            FilledButton(
              onPressed: (mapPath != null && selectedConverter != null) ? () => Navigator.of(ctx).pop(true) : null,
              child: Text(langController.get('dialog_load_confirm')),
            )
          ],
        );
      }
    ),
  );

  if (confirmed == true && mapPath != null && selectedConverter != null) {
    return (mapPath: mapPath!, bgPath: bgPath, converterName: selectedConverter!);
  }
  return null;
}