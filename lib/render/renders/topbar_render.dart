import 'package:flutter/material.dart';

import '../../api/lua/lua_value_utils.dart';
import '../../theme/app_theme.dart';
import '../main.dart';

/// "How to build a topbar" — a flat horizontal strip that lays out
/// whatever it is handed. It never decides WHAT goes inside: the list of
/// slots comes from `params['slots']`, each one a small
/// `{template, params}` descriptor resolved back through [RenderService].
///
/// This is how a Plugin injects a button into the shell's topbar without
/// the shell ever importing that Plugin — the Plugin registers its own
/// template at boot, and whoever composes the topbar's slot list only
/// needs to know the template's id.
Widget buildTopbarRender(Map<String, dynamic> params) {
  final List slots = asLuaList(params['slots']);
  final double height = (params['height'] as num?)?.toDouble() ?? 44;

  return Container(
    height: height,
    color: AppTheme.bg2,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(
      children: [
        for (final slot in slots.whereType<Map>())
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RenderService.instance.build(
              slot['template'] as String? ?? '',
              (slot['params'] as Map?)?.cast<String, dynamic>() ?? const {},
            ),
          ),
      ],
    ),
  );
}
