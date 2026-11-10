import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// "How to build a text field" — a bordered input driven entirely by
/// [params]. `numeric` just picks a keyboard type; it never validates
/// or interprets what's typed — that stays the caller's job.
///
/// Accepts an external [TextEditingController] via `controller` (used
/// by the Lua descriptor interpreter to track live typing locally,
/// without reporting every keystroke as an action) — falls back to a
/// plain `initialValue` for callers that don't need that.
Widget buildTextFieldRender(Map<String, dynamic> params) {
  final TextEditingController? controller = params['controller'] as TextEditingController?;
  final String? label = params['label'] as String?;
  final bool numeric = params['numeric'] as bool? ?? false;
  final ValueChanged<String>? onChanged = params['onChanged'] as ValueChanged<String>?;

  return TextFormField(
    controller: controller,
    initialValue: controller == null ? (params['value']?.toString() ?? '') : null,
    keyboardType: numeric ? TextInputType.number : TextInputType.text,
    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      filled: true,
      fillColor: AppTheme.bg1,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    onChanged: onChanged,
  );
}
