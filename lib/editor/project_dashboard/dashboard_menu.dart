import 'package:flutter/material.dart';
import '../../core/language_controller.dart';
import '../../theme/app_theme.dart';

class DashboardMenu extends StatelessWidget {
  final LanguageController lang;
  final int activeTab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onCancel;
  final bool hasPendingChanges;
  final bool isNarrow;

  const DashboardMenu({
    super.key, required this.lang, required this.activeTab,
    required this.onTabChanged, required this.onCancel, required this.hasPendingChanges,
    this.isNarrow = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isNarrow) {
      return Container(
        color: AppTheme.bg2,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                primary: false,
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _narrowItem(0, Icons.create_new_folder_outlined, lang.get('topbar_new_project')),
                    _narrowItem(1, Icons.map_outlined, lang.get('topbar_scenario')),
                    // Desativamos apenas este botão passando isDisabled: true
                    _narrowItem(2, Icons.auto_fix_high, lang.get('opengs_title'), isDisabled: true),
                    _narrowItem(3, Icons.extension_outlined, lang.get('dashboard_converters_title')),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: hasPendingChanges ? null : onCancel,
              icon: const Icon(Icons.close, size: 20),
              tooltip: lang.get('dialog_cancel'),
              color: hasPendingChanges ? AppTheme.textDisabled : AppTheme.textSecondary,
            ),
          ],
        ),
      );
    }

    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: AppTheme.bg2,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(AppTheme.radiusMd), bottomLeft: Radius.circular(AppTheme.radiusMd)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.dashboard_customize, color: AppTheme.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang.get('dashboard_title'), 
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Área de itens com rolagem independente para nunca estourar a tela em modo paisagem
          Expanded(
            child: SingleChildScrollView(
              primary: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _menuItem(0, Icons.create_new_folder_outlined, lang.get('topbar_new_project')),
                  _menuItem(1, Icons.map_outlined, lang.get('topbar_scenario')),
                  // Desativamos apenas este botão passando isDisabled: true
                  _menuItem(2, Icons.auto_fix_high, lang.get('opengs_title'), isDisabled: true),
                  _menuItem(3, Icons.extension_outlined, lang.get('dashboard_converters_title')),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextButton.icon(
              onPressed: hasPendingChanges ? null : onCancel,
              icon: const Icon(Icons.close, size: 16),
              label: Text(lang.get('dialog_cancel')),
              style: TextButton.styleFrom(
                foregroundColor: hasPendingChanges ? AppTheme.textDisabled : AppTheme.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _narrowItem(int index, IconData icon, String title, {bool isDisabled = false}) {
    final isActive = activeTab == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: title,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: isDisabled ? null : () => onTabChanged(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? AppTheme.accentMuted : Colors.transparent,
              border: isActive ? Border.all(color: AppTheme.accent) : Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: isDisabled ? AppTheme.textDisabled : (isActive ? AppTheme.accent : AppTheme.textSecondary)),
                const SizedBox(width: 6),
                Text(
                  title, 
                  style: TextStyle(
                    color: isDisabled ? AppTheme.textDisabled : (isActive ? AppTheme.accent : AppTheme.textPrimary), 
                    fontSize: 12, 
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal
                  )
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuItem(int index, IconData icon, String title, {bool isDisabled = false}) {
    final isActive = activeTab == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: isActive ? AppTheme.accentMuted : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: isDisabled ? null : () => onTabChanged(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: isActive ? Border.all(color: AppTheme.accent.withValues(alpha: 0.5)) : null, 
              borderRadius: BorderRadius.circular(AppTheme.radiusSm)
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: isDisabled ? AppTheme.textDisabled : (isActive ? AppTheme.accent : AppTheme.textSecondary)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title, 
                    style: TextStyle(
                      color: isDisabled ? AppTheme.textDisabled : (isActive ? AppTheme.accent : AppTheme.textPrimary), 
                      fontSize: 13, 
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal
                    ), 
                    overflow: TextOverflow.ellipsis
                  )
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}