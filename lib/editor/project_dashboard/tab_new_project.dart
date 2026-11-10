import 'package:flutter/material.dart';
import '../../core/language_controller.dart';
import '../../theme/app_theme.dart';

class TabNewProject extends StatelessWidget {
  final LanguageController lang;
  final VoidCallback onClear;
  final bool isNarrow;

  const TabNewProject({super.key, required this.lang, required this.onClear, this.isNarrow = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(isNarrow ? 14.0 : 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.get('dialog_new_project_title'), 
            style: TextStyle(
              color: AppTheme.textPrimary, 
              fontSize: isNarrow ? 18 : 22, 
              fontWeight: FontWeight.bold
            )
          ),
          const SizedBox(height: 12),
          Text(lang.get('dialog_new_project_desc'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.danger, 
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
              ),
              onPressed: onClear,
              icon: const Icon(Icons.delete_forever, size: 18),
              label: Text(lang.get('dialog_new_project_confirm'), style: const TextStyle(fontSize: 12)),
            ),
          )
        ],
      ),
    );
  }
}