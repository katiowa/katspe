import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_preferences.dart';
import '../../core/language_controller.dart';
import '../../theme/app_theme.dart';
import '../layout/panel_state.dart';
import '../../models/prop_model.dart';
import '../../data/props_controller.dart';

part 'top_bar/visibility_menu.part.dart';
part 'top_bar/props_menu.part.dart';
part 'top_bar/prop_card.part.dart';
part 'top_bar/prop_angle_control.part.dart';

class TopBar extends StatelessWidget {
  final LanguageController lang;
  final int provinceCount;
  final bool isBusy;

  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  final bool enableSnapping;
  final bool showAllPoints;
  final bool showProvinces;
  final bool showXRay;
  final bool showBg;

  final List<Map<String, dynamic>> poiCategories;
  final Set<String> hiddenCategories;

  final PropsController propsController;
  final VoidCallback onImportProp;

  final VoidCallback onToggleSnapping;
  final VoidCallback onToggleAllPoints;
  final VoidCallback onToggleProvinces;
  final VoidCallback onToggleXRay;
  final VoidCallback onToggleBg;
  final ValueChanged<String> onToggleCategory;

  final VoidCallback onSettings;
  final VoidCallback onManageProject;

  final ValueChanged<String> onManagePoiCategory;
  final DockPosition dock;

  const TopBar({
    super.key,
    required this.lang,
    required this.provinceCount,
    required this.isBusy,
    required this.canUndo,
    required this.canRedo,
    required this.enableSnapping,
    required this.showAllPoints,
    required this.showProvinces,
    required this.showXRay,
    required this.showBg,
    required this.poiCategories,
    required this.hiddenCategories,
    required this.propsController,
    required this.onImportProp,
    required this.onUndo,
    required this.onRedo,
    required this.onToggleSnapping,
    required this.onToggleAllPoints,
    required this.onToggleProvinces,
    required this.onToggleXRay,
    required this.onToggleBg,
    required this.onToggleCategory,
    required this.onSettings,
    required this.onManageProject,
    required this.onManagePoiCategory,
    required this.dock,
  });

  Widget _buildDivider(bool isHorz) {
    return Container(
      width: isHorz ? 1 : 24,
      height: isHorz ? 24 : 1,
      color: AppTheme.borderSubtle,
      margin: const EdgeInsets.all(8),
    );
  }

  Widget _smallAction(String label, IconData icon, VoidCallback onPressed) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isHorz = constraints.maxWidth >= constraints.maxHeight;
        final double minMainAxis = isHorz ? constraints.maxWidth : constraints.maxHeight;

        final leftGroup = Flex(
          direction: isHorz ? Axis.horizontal : Axis.vertical,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FutureBuilder<Directory>(
              future: getEngineDirectory(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final file = File('${snapshot.data!.path}${Platform.pathSeparator}logo${Platform.pathSeparator}icon-mapeditor.webp');
                  if (file.existsSync()) {
                    return Image.file(
                      file, 
                      width: 24, 
                      height: 24, 
                      filterQuality: FilterQuality.medium,
                    );
                  }
                }
                return const Icon(Icons.map_outlined, color: AppTheme.accent, size: 18);
              },
            ),
            
            SizedBox(width: isHorz ? 8 : 0, height: isHorz ? 0 : 8),
            Text(lang.get('topbar_title'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),

            SizedBox(width: isHorz ? 16 : 0, height: isHorz ? 0 : 16),
            Tooltip(message: lang.get('topbar_undo'), child: IconButton(icon: const Icon(Icons.undo, size: 18), onPressed: canUndo ? onUndo : null)),
            Tooltip(message: lang.get('topbar_redo'), child: IconButton(icon: const Icon(Icons.redo, size: 18), onPressed: canRedo ? onRedo : null)),

            _buildDivider(isHorz),

            Tooltip(message: lang.get('topbar_snapping'), child: IconButton(icon: Icon(Icons.zoom_in_map, size: 18, color: enableSnapping ? AppTheme.accent : AppTheme.textDisabled), onPressed: onToggleSnapping)),
            Tooltip(message: lang.get('topbar_all_points'), child: IconButton(icon: Icon(Icons.scatter_plot, size: 18, color: showAllPoints ? AppTheme.accent : AppTheme.textDisabled), onPressed: onToggleAllPoints)),
            
            _buildPropsMenu(context),

            _buildDivider(isHorz),

            _buildVisibilityMenu(),

            _buildDivider(isHorz),

            Tooltip(message: lang.get('topbar_settings'), child: IconButton(icon: const Icon(Icons.settings_outlined, size: 16), onPressed: onSettings)),
          ],
        );

        final rightGroup = Flex(
          direction: isHorz ? Axis.horizontal : Axis.vertical,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: onManageProject,
              style: FilledButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: AppTheme.bg0, padding: const EdgeInsets.symmetric(horizontal: 16)),
              icon: const Icon(Icons.dashboard_customize, size: 16),
              label: Text(lang.get('topbar_manage_project'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),

            SizedBox(width: isHorz ? 16 : 0, height: isHorz ? 0 : 16),
            for (final category in poiCategories) ...[
              _smallAction(category['label']?.toString() ?? category['id']?.toString() ?? '', Icons.list_alt, () => onManagePoiCategory(category['id']?.toString() ?? '')),
              SizedBox(width: isHorz ? 8 : 0, height: isHorz ? 0 : 8),
            ],

            SizedBox(width: isHorz ? 8 : 0, height: isHorz ? 0 : 8),
            Text(lang.get('topbar_provinces_count').replaceAll('{count}', provinceCount.toString()), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
        );

        return SingleChildScrollView(
          primary: false,
          scrollDirection: isHorz ? Axis.horizontal : Axis.vertical,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: isHorz ? minMainAxis : 0,
              minHeight: isHorz ? 0 : minMainAxis,
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Flex(
                direction: isHorz ? Axis.horizontal : Axis.vertical,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  leftGroup,
                  if (!isHorz) ...[
                    const SizedBox(height: 24),
                  ],
                  rightGroup,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}