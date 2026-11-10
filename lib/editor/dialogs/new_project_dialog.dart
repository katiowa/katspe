import 'package:flutter/material.dart';
import '../../core/language_controller.dart';
import '../../theme/app_theme.dart';

Future<bool> showNewProjectDialog(BuildContext context, {required LanguageController langController}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: const BorderSide(color: AppTheme.border),
      ),
      title: Text(langController.get('dialog_new_project_title'), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
      content: Text(
        langController.get('dialog_new_project_desc'),
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(langController.get('dialog_cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(langController.get('dialog_new_project_confirm')),
        )
      ],
    ),
  );
  return result ?? false;
}
