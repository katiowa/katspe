import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/language_controller.dart';
import '../../engine/engine_storage.dart';
import '../../theme/app_theme.dart';
import 'disclaimer_dialog.dart';

/// Diálogo de configurações da engine (culling e idioma).
Future<void> showSettingsDialog(
  BuildContext context, {
  required LanguageController langController,
  required EngineStorageManager storage,
  required ValueNotifier<bool> enableFrustumCulling,
  required ValueNotifier<double> cullingMargin,
  required ValueNotifier<double> uiScale,
}) {
  // Guarda a seleção temporária antes do usuário confirmar
  String? pendingLangFileName = langController.currentLanguage?.fileName;
  bool isImporting = false;
  
  // Segurança: se a lista estiver vazia ou não contiver a seleção, anula.
  if (!langController.availableLanguages.any((l) => l.fileName == pendingLangFileName)) {
    pendingLangFileName = null;
  }

  return showDialog(
    context: context,
    barrierDismissible: !isImporting, // Impede fechamento durante a extração
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) {
        Future<void> confirmAndDeleteLang(LanguageItem langToDelete) async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (dCtx) => AlertDialog(
              backgroundColor: AppTheme.bg2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                side: const BorderSide(color: AppTheme.border),
              ),
              title: Row(
                children: [
                  const Icon(Icons.delete_forever, color: AppTheme.danger),
                  const SizedBox(width: 10),
                  Text(
                    langController.get('lang_delete_confirm_title'),
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                  ),
                ],
              ),
              content: Text(
                langController.get('lang_delete_confirm_desc').replaceAll('{name}', langToDelete.displayName),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dCtx).pop(false),
                  child: Text(langController.get('dialog_cancel')),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
                  onPressed: () => Navigator.of(dCtx).pop(true),
                  child: Text(langController.get('btn_delete')),
                ),
              ],
            ),
          );

          if (confirm == true) {
            await langController.deleteLanguage(langToDelete.fileName);
            setModalState(() {
              if (pendingLangFileName == langToDelete.fileName) {
                pendingLangFileName = langController.currentLanguage?.fileName;
              }
            });
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(langController.get('delete_success')),
                backgroundColor: AppTheme.success,
              ));
            }
          }
        }

        return AlertDialog(
          backgroundColor: AppTheme.bg2,
          title: Text(langController.get('settings_title'), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- SEÇÃO DE IDIOMAS ---
                Text(langController.get('settings_language'), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.bg1,
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: AppTheme.bg1,
                      isExpanded: true,
                      value: pendingLangFileName,
                      icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
                      onChanged: isImporting ? null : (String? newValue) {
                        if (newValue != null) {
                          setModalState(() => pendingLangFileName = newValue);
                        }
                      },
                      items: langController.availableLanguages.map((lang) {
                        final canDelete = lang.fileName != 'english.json' && langController.availableLanguages.length > 1;
                        return DropdownMenuItem<String>(
                          value: lang.fileName,
                          child: Row(
                            children: [
                              _buildFlag(lang.flagPath),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(lang.displayName, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                              ),
                              if (canDelete)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 18),
                                  tooltip: langController.get('lang_delete'),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: isImporting ? null : () => confirmAndDeleteLang(lang),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Botão de importar idioma
                if (isImporting)
                  Row(
                    children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
                      const SizedBox(width: 12),
                      Text(langController.get('import_loading'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final agreed = await showDisclaimerDialog(context, langController);
                      if (agreed != true) return;

                      final res = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['zip']);
                      if (res == null || res.path == null) return;

                      setModalState(() => isImporting = true);
                      try {
                        await storage.importLanguageZip(res.path!);
                        await langController.init();
                        
                        if (!langController.availableLanguages.any((l) => l.fileName == pendingLangFileName)) {
                          pendingLangFileName = langController.currentLanguage?.fileName;
                        }
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(langController.get('import_success')), 
                            backgroundColor: AppTheme.success
                          ));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          final errorMsg = langController.get('import_error').replaceAll('{error}', e.toString());
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(errorMsg), 
                            backgroundColor: AppTheme.danger
                          ));
                        }
                      } finally {
                        setModalState(() => isImporting = false);
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(langController.get('import_lang_btn'), style: const TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                
                const SizedBox(height: 20),
                const Divider(color: AppTheme.borderSubtle),
                const SizedBox(height: 12),
                
                // --- SEÇÃO ENGINE (Culling) ---
                AnimatedBuilder(
                  animation: enableFrustumCulling,
                  builder: (ctx, _) => SwitchListTile(
                    title: Text(langController.get('settings_culling_title'), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    subtitle: Text(langController.get('settings_culling_subtitle'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    value: enableFrustumCulling.value,
                    activeThumbColor: AppTheme.accent,
                    onChanged: isImporting ? null : (v) => enableFrustumCulling.value = v,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 12),
                Text(langController.get('settings_culling_margin'), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                const SizedBox(height: 4),
                AnimatedBuilder(
                  animation: cullingMargin,
                  builder: (ctx, _) => Slider(
                    value: cullingMargin.value,
                    min: 0.0, max: 2.0, divisions: 20,
                    activeColor: AppTheme.accent,
                    label: cullingMargin.value == 0.0 
                        ? langController.get('settings_culling_extreme') 
                        : cullingMargin.value == 2.0 
                            ? langController.get('settings_culling_minimum') 
                            : langController.get('settings_culling_balanced'),
                    onChanged: isImporting ? null : (v) => cullingMargin.value = v,
                  ),
                ),
                const SizedBox(height: 12),
                
                // --- SEÇÃO ESCALA DA INTERFACE ---
                Text(
                  langController.get('settings_ui_scale'), 
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)
                ),
                const SizedBox(height: 4),
                AnimatedBuilder(
                  animation: uiScale,
                  builder: (ctx, _) => Slider(
                    value: uiScale.value,
                    min: 0.5, max: 1.5, divisions: 20,
                    activeColor: AppTheme.accent,
                    label: '${(uiScale.value * 100).round()}%',
                    onChanged: isImporting ? null : (v) => uiScale.value = v,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: isImporting ? null : () {
                if (pendingLangFileName != null && pendingLangFileName != langController.currentLanguage?.fileName) {
                  langController.setLanguage(pendingLangFileName!);
                }
                Navigator.of(ctx).pop();
              },
              child: Text(langController.get('settings_confirm')),
            )
          ],
        );
      }
    ),
  );
}

Widget _buildFlag(String? flagPath) {
  if (flagPath == null) {
    return const SizedBox(width: 30, height: 20); 
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(2), 
    child: Image.file(
      File(flagPath),
      width: 30,
      height: 20,
      cacheWidth: 30, 
      cacheHeight: 20, 
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 20, color: AppTheme.danger),
    ),
  );
}