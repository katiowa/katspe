import 'package:flutter/widgets.dart';

/// "How to build a column" — lays out pre-built children vertically
/// with a gap between them. Same reasoning as `row_render.dart`.
Widget buildColumnRender(Map<String, dynamic> params) {
  final children = (params['children'] as List?)?.cast<Widget>() ?? const <Widget>[];
  final double gap = (params['gap'] as num?)?.toDouble() ?? 8;

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (int i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(height: gap),
        children[i],
      ],
    ],
  );
}
