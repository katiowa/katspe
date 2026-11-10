import 'package:flutter/material.dart';

import '../../core/language_controller.dart';
import '../../theme/app_theme.dart';
import '../../io/export_manager.dart';
import '../../models/map_marker.dart';
import '../../models/province.dart';
import '../../engine/engine_storage.dart';
import '../layout/panel_state.dart';
import 'common/panel_section_label.dart';

part 'properties_panel/scenario_section.part.dart';
part 'properties_panel/province_section.part.dart';
part 'properties_panel/export_section.part.dart';

class PropertiesPanel extends StatelessWidget {
  final LanguageController lang;
  final EngineMapData mapData;
  final List<MapMarker> markers;
  final List<Map<String, dynamic>> poiCategories;

  final Set<int> selectedProvinceIds;
  final ExportOptions exportOptions;
  final ValueChanged<ExportOptions> onExportOptionsChanged;
  final VoidCallback onRunExport;
  final bool isExporting;
  final List<String> lastExportedFiles;
  final EngineStorageManager storage; 

  final VoidCallback onDeleteProvinces;
  final VoidCallback onMergeProvinces;
  final VoidCallback onImportProvince;
  final DockPosition dock;

  const PropertiesPanel({
    super.key,
    required this.lang,
    required this.mapData,
    required this.markers,
    required this.poiCategories,
    required this.selectedProvinceIds,
    required this.exportOptions,
    required this.onExportOptionsChanged,
    required this.onRunExport,
    required this.onDeleteProvinces,
    required this.onMergeProvinces,
    required this.onImportProvince,
    required this.storage,
    required this.dock,
    this.isExporting = false,
    this.lastExportedFiles = const [],
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 30.0) {
          return const SizedBox.shrink();
        }

        final isHorz = constraints.maxWidth > constraints.maxHeight;

        final sections = <Widget>[
          _ScenarioSection(
            lang: lang,
            mapData: mapData,
            poiCategories: poiCategories,
            markers: markers,
            onImportProvince: onImportProvince,
          ),
          if (selectedProvinceIds.length == 1) ...[
            _SingleProvinceSection(
              lang: lang,
              province: mapData.findById(selectedProvinceIds.first)!,
              onDeleteProvinces: onDeleteProvinces,
            ),
          ] else if (selectedProvinceIds.length > 1) ...[
            _MultiProvinceSection(
              lang: lang,
              count: selectedProvinceIds.length,
              onMergeProvinces: onMergeProvinces,
              onDeleteProvinces: onDeleteProvinces,
            ),
          ],
          _ExportSection(
            lang: lang,
            exportOptions: exportOptions,
            hasSelection: selectedProvinceIds.isNotEmpty,
            poiCategories: poiCategories,
            onChanged: onExportOptionsChanged,
            onRunExport: onRunExport,
            isExporting: isExporting,
            storage: storage,
            lastExportedFiles: lastExportedFiles,
          ),
        ];

        return ListView.separated(
          scrollDirection: isHorz ? Axis.horizontal : Axis.vertical,
          padding: const EdgeInsets.all(14),
          itemCount: sections.length,
          separatorBuilder: (context, index) {
            return isHorz 
                ? const VerticalDivider(width: 32, color: AppTheme.borderSubtle) 
                : const Divider(height: 32, color: AppTheme.borderSubtle);
          },
          itemBuilder: (context, index) {
            final child = sections[index];
            return isHorz 
                ? SizedBox(width: 260, child: SingleChildScrollView(child: child)) 
                : child;
          },
        );
      },
    );
  }
}