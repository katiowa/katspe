import 'package:flutter/material.dart';

import '../../core/language_controller.dart';
import '../../theme/app_theme.dart';

class PointActionMenu extends StatelessWidget {
  final LanguageController lang;
  final VoidCallback onDelete;
  final VoidCallback onCancel;
  final VoidCallback? onSubdivide; 

  const PointActionMenu({
    super.key,
    required this.lang,
    required this.onDelete,
    required this.onCancel,
    this.onSubdivide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.bg2.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accent, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onSubdivide != null) ...[
            Tooltip(
              message: lang.get('point_menu_subdivide'),
              child: Material(
                color: AppTheme.success.withValues(alpha: 0.2),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSubdivide,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.call_split, size: 16, color: AppTheme.success),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Tooltip(
            message: lang.get('point_menu_delete'),
            child: Material(
              color: AppTheme.danger.withValues(alpha: 0.2),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.delete_outline, size: 16, color: AppTheme.danger),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: lang.get('point_menu_cancel'),
            child: Material(
              color: AppTheme.bg4,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onCancel,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close, size: 16, color: AppTheme.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
