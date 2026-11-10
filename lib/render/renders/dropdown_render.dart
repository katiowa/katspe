import 'package:flutter/material.dart';

import '../../api/lua/lua_value_utils.dart';
import '../../theme/app_theme.dart';

/// "How to build a dropdown" — a bordered, single-select dropdown driven
/// entirely by [params]. `options` is a list of `{value, label}` maps so
/// callers never need to know this template is, under the hood, a
/// Flutter [DropdownButton].
Widget buildDropdownRender(Map<String, dynamic> params) {
  final List options = asLuaList(params['options']);
  final String? value = params['value'] as String?;
  final ValueChanged<String?>? onChanged = params['onChanged'] as ValueChanged<String?>?;

  return Container(
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
        value: value,
        icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
        onChanged: onChanged,
        items: [
          for (final opt in options.whereType<Map>())
            DropdownMenuItem<String>(
              value: opt['value'] as String?,
              child: Text(
                (opt['label'] as String?) ?? (opt['value'] as String? ?? ''),
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
            ),
        ],
      ),
    ),
  );
}
