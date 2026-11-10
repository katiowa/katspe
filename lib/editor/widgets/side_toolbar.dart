import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/language_controller.dart';
import '../../theme/app_theme.dart';
import '../editor_tool.dart';
import 'common/tool_icon_button.dart';
import '../layout/panel_state.dart';

class SideToolbar extends StatefulWidget {
  final LanguageController lang;
  final EditorTool activeTool;
  final ValueChanged<EditorTool> onToolSelected;

  final List<Map<String, dynamic>> poiCategories;
  final String? activePoiCategory;
  final ValueChanged<String> onPoiCategorySelected;
  
  final DockPosition dock;

  const SideToolbar({
    super.key,
    required this.lang,
    required this.activeTool,
    required this.onToolSelected,
    required this.poiCategories,
    required this.activePoiCategory,
    required this.onPoiCategorySelected,
    required this.dock,
  });

  @override
  State<SideToolbar> createState() => _SideToolbarState();
}

class _SideToolbarState extends State<SideToolbar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildDivider(bool isHorz) {
    return Container(
      width: isHorz ? 1 : 24,
      height: isHorz ? 24 : 1,
      color: AppTheme.borderSubtle,
      margin: const EdgeInsets.all(8),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0.0) return const SizedBox.shrink();

        final isHorz = constraints.maxWidth > constraints.maxHeight;
        final isPanelOnRight = widget.dock == DockPosition.right || (constraints.maxWidth < screenSize.width / 2 && widget.dock != DockPosition.left);

        final CrossAxisAlignment crossAlign = !isHorz
            ? (isPanelOnRight ? CrossAxisAlignment.end : CrossAxisAlignment.start)
            : (widget.dock == DockPosition.bottom ? CrossAxisAlignment.end : CrossAxisAlignment.start);

        final items = <Widget>[
          _tool(EditorTool.select, Icons.near_me_outlined, widget.lang.get('tool_select')),
          _tool(EditorTool.moveProvince, Icons.open_with, widget.lang.get('tool_move')),
          _buildDivider(isHorz),
          _tool(EditorTool.createProvincePoint, Icons.polyline_outlined, widget.lang.get('tool_create_province')),
          _tool(EditorTool.editPoint, Icons.control_point_outlined, widget.lang.get('tool_edit_point')),
          if (widget.poiCategories.isNotEmpty) ...[
            _buildDivider(isHorz),
            for (final category in widget.poiCategories) _poiCategoryButton(category),
          ],
        ];

        final safeContentWidth = math.max(0.0, constraints.maxWidth - 16);

        return Directionality(
          textDirection: !isHorz && !isPanelOnRight ? TextDirection.rtl : TextDirection.ltr,
          child: Scrollbar(
            controller: _scrollController,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: isHorz ? Axis.horizontal : Axis.vertical,
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  width: isHorz ? null : safeContentWidth,
                  child: Flex(
                    direction: isHorz ? Axis.horizontal : Axis.vertical,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: crossAlign,
                    children: items,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tool(EditorTool tool, IconData icon, String tooltip) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: ToolIconButton(
        icon: icon,
        tooltip: tooltip,
        selected: widget.activeTool == tool,
        onPressed: () => widget.onToolSelected(tool),
      ),
    );
  }

  Widget _poiCategoryButton(Map<String, dynamic> category) {
    final id = category['id']?.toString() ?? '';
    final label = category['label']?.toString() ?? id;
    final colorValue = (category['marker_color'] as num?)?.toInt();
    final selected = widget.activeTool == EditorTool.placePoi && widget.activePoiCategory == id;

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: () => widget.onPoiCategorySelected(id),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppTheme.accentMuted : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.place_outlined, size: 20, color: selected ? AppTheme.accent : AppTheme.textPrimary),
                if (colorValue != null)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: Color(colorValue),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.bg2, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}