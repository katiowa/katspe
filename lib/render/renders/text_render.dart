import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// "How to build text" — the Core's default label. Carries zero
/// business logic: content, size and weight all come from [params].
Widget buildTextRender(Map<String, dynamic> params) {
  final String text = params['text']?.toString() ?? '';
  final double size = (params['size'] as num?)?.toDouble() ?? 13;
  final bool bold = params['bold'] as bool? ?? false;
  final bool muted = params['muted'] as bool? ?? false;

  return Text(
    text,
    style: TextStyle(
      color: muted ? AppTheme.textSecondary : AppTheme.textPrimary,
      fontSize: size,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    ),
  );
}
