import 'package:flutter/material.dart';
import '../../core/language_controller.dart';
import '../../theme/app_theme.dart';

/// Exibe o aviso crítico de segurança antes de permitir qualquer importação 
/// de conteúdo de terceiros (Conversores e Idiomas). Retorna [true] se consentido.
Future<bool> showDisclaimerDialog(BuildContext context, LanguageController lang) async {
  bool accepted = false;
  
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          backgroundColor: AppTheme.bg2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: const BorderSide(color: AppTheme.border),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  lang.get('disclaimer_title'),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lang.get('disclaimer_desc'),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bg3,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: accepted ? AppTheme.accent : AppTheme.border),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      title: Text(
                        lang.get('disclaimer_accept'),
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                      ),
                      value: accepted,
                      activeColor: AppTheme.accent,
                      onChanged: (val) {
                        setState(() => accepted = val ?? false);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(lang.get('dialog_cancel')),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: accepted ? AppTheme.success : AppTheme.bg3,
                foregroundColor: accepted ? AppTheme.bg0 : AppTheme.textDisabled,
              ),
              onPressed: accepted ? () => Navigator.of(ctx).pop(true) : null,
              icon: const Icon(Icons.folder_zip_outlined, size: 16),
              label: Text(lang.get('disclaimer_confirm')),
            )
          ],
        );
      }
    ),
  );
  
  return result ?? false;
}