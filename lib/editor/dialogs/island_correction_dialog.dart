import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/language_controller.dart';
import '../../theme/app_theme.dart';

enum IslandCorrectionResult { confirm, ignore, cancel }

class IslandCorrectionOverlayWidget extends StatelessWidget {
  final LanguageController lang;
  final VoidCallback onToggle;
  final VoidCallback onConfirm;
  final VoidCallback onIgnore;

  const IslandCorrectionOverlayWidget({
    super.key,
    required this.lang,
    required this.onToggle,
    required this.onConfirm,
    required this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = math.min(screenSize.width - 32.0, 500.0);

    return Material(
      color: AppTheme.bg2,
      elevation: 16,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        width: dialogWidth,
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5), width: 1.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 12))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lang.get('dialog_island_title'),
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Tooltip(
                    message: "Arraste para mover",
                    child: MouseRegion(
                      cursor: SystemMouseCursors.move,
                      child: Icon(Icons.open_with, color: AppTheme.textDisabled, size: 18),
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                lang.get('dialog_island_desc'),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: AppTheme.bg1,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.radiusMd)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: onIgnore,
                            child: Text(
                              lang.get('dialog_island_ignore'),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: onToggle,
                                icon: const Icon(Icons.swap_horiz, size: 15),
                                label: Text(
                                  lang.get('dialog_island_toggle'),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                  foregroundColor: AppTheme.bg0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: onConfirm,
                                child: Text(
                                  lang.get('dialog_island_confirm'),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}