import 'package:flutter/material.dart';
import '../../core/language_controller.dart';
import '../../theme/app_theme.dart';

class PendingChangesBar extends StatelessWidget {
  final LanguageController lang;
  final bool hasPendingChanges;
  final VoidCallback onRevert;
  final VoidCallback onConfirm;

  const PendingChangesBar({
    super.key, required this.lang, required this.hasPendingChanges,
    required this.onRevert, required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: !hasPendingChanges
          ? const SizedBox.shrink()
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: AppTheme.bg3, 
                border: Border(top: BorderSide(color: AppTheme.accent, width: 2))
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Se a tela for estreita (Mobile Portrait), quebramos os botões para baixo
                  // garantindo que o texto não seja esmagado (o que causava o overflow vertical e horizontal)
                  if (constraints.maxWidth < 450) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppTheme.accent),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                lang.get('dashboard_pending_changes'), 
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)
                              )
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: onConfirm,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.success, 
                            foregroundColor: AppTheme.bg0
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(
                            lang.get('dashboard_confirm'), 
                            style: const TextStyle(fontWeight: FontWeight.bold)
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: onRevert,
                          style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                          child: Text(lang.get('dashboard_revert')),
                        ),
                      ],
                    );
                  }

                  // Layout clássico (Desktop/Tablet) com espaço de sobra para renderizar em linha
                  return Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          lang.get('dashboard_pending_changes'), 
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)
                        )
                      ),
                      TextButton(
                        onPressed: onRevert,
                        style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                        child: Text(lang.get('dashboard_revert')),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: onConfirm,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.success, 
                          foregroundColor: AppTheme.bg0
                        ),
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(
                          lang.get('dashboard_confirm'), 
                          style: const TextStyle(fontWeight: FontWeight.bold)
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}