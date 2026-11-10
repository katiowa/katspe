import 'package:flutter/widgets.dart';

/// "How to build a row" — lays out pre-built children horizontally with
/// a gap between them, wrapping to a new line instead of overflowing
/// when they don't all fit. Carries zero business logic: what the
/// children actually are comes from whoever asked for this template (a
/// Plugin, or the Lua descriptor interpreter resolving a converter's UI
/// tree) — this template has no idea how much horizontal room its
/// parent actually has (a Lua-rendered panel can be as narrow as a
/// quick-editor popup), so it can't assume everything fits on one line.
Widget buildRowRender(Map<String, dynamic> params) {
  final children = (params['children'] as List?)?.cast<Widget>() ?? const <Widget>[];
  final double gap = (params['gap'] as num?)?.toDouble() ?? 8;

  return Wrap(
    spacing: gap,
    runSpacing: gap,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: children,
  );
}
