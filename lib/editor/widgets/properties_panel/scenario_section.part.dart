part of '../properties_panel.dart';

class _ScenarioSection extends StatelessWidget {
  final LanguageController lang;
  final EngineMapData mapData;
  final List<Map<String, dynamic>> poiCategories;
  final List<MapMarker> markers;
  final VoidCallback onImportProvince;

  const _ScenarioSection({
    required this.lang,
    required this.mapData,
    required this.poiCategories,
    required this.markers,
    required this.onImportProvince,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelSectionLabel(lang.get('panel_scenario')),
        _StatRow(label: lang.get('panel_provinces'), value: '${mapData.provinces.length}'),
        for (final category in poiCategories)
          _StatRow(
            label: category['label']?.toString() ?? category['id']?.toString() ?? '',
            value: '${markers.where((m) => m.category == category['id']).length}',
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onImportProvince,
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: Text(lang.get('panel_btn_import_prov')),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.bg3),
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 40) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}