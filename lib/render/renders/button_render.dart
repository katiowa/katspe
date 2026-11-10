import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// "How to build a button" — the Core's default flat, bordered button.
///
/// Carries zero business logic: the label, icon, enabled state and what
/// happens on tap all come from [params], supplied by whichever Plugin or
/// API call asked for this template. This file never imports a Plugin and
/// never decides when it should be shown.
Widget buildButtonRender(Map<String, dynamic> params) {
  final String label = params['label'] as String? ?? '';
  final IconData? icon = params['icon'] as IconData?;
  final VoidCallback? onPressed = params['onPressed'] as VoidCallback?;
  final bool selected = params['selected'] as bool? ?? false;
  final String? tooltip = params['tooltip'] as String?;

  final button = FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon ?? Icons.circle, size: icon == null ? 0 : 16),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: selected ? AppTheme.accentMuted : AppTheme.bg3,
      foregroundColor: selected ? AppTheme.accent : AppTheme.textPrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        side: const BorderSide(color: AppTheme.border),
      ),
    ),
  );

  if (tooltip == null || tooltip.isEmpty) return button;
  return Tooltip(message: tooltip, child: button);
}
