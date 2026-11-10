import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/language_controller.dart';
import '../../theme/app_theme.dart';

Future<void> showOpenGsDialog(BuildContext context, {required LanguageController langController}) async {
  bool consentGiven = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) {
        return AlertDialog(
          backgroundColor: AppTheme.bg2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: const BorderSide(color: AppTheme.border),
          ),
          title: Row(
            children: [
              const Icon(Icons.auto_fix_high, color: AppTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  langController.get('opengs_title'),
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
                  langController.get('opengs_desc'),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bg3,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: consentGiven ? AppTheme.accent : AppTheme.border),
                  ),
                  child: Material( // Envolto em Material transparente para evitar o erro do ListTile
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      title: Text(
                        langController.get('opengs_consent'),
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                      ),
                      value: consentGiven,
                      activeColor: AppTheme.accent,
                      onChanged: (val) {
                        setModalState(() => consentGiven = val ?? false);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(langController.get('dialog_cancel')),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: consentGiven ? AppTheme.success : AppTheme.bg3,
                foregroundColor: consentGiven ? AppTheme.bg0 : AppTheme.textDisabled,
              ),
              onPressed: consentGiven
                  ? () async {
                      final url = Uri.parse('https://github.com/Thomas-Holtvedt/opengs-maptool');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                      if (context.mounted) Navigator.of(ctx).pop();
                    }
                  : null,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(langController.get('opengs_btn')),
            )
          ],
        );
      }
    ),
  );
}