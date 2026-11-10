import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Botão de ferramenta quadrado da barra lateral (estilo Blender):
/// ícone centralizado, destaque de acento quando [selected].
class ToolIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback? onPressed;

  const ToolIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: selected ? AppTheme.accentMuted : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: onPressed,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: selected
                  ? Border.all(color: AppTheme.accent, width: 1)
                  : null,
            ),
            child: Icon(
              icon,
              color: selected ? AppTheme.accent : AppTheme.textSecondary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
