import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Cabeçalho pequeno em CAPS usado para separar seções dentro dos
/// painéis laterais (igual ao Blender: "TRANSFORM", "MODIFIERS"...).
class PanelSectionLabel extends StatelessWidget {
  final String text;
  const PanelSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textDisabled,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
