part of '../properties_panel.dart';

class _SingleProvinceSection extends StatelessWidget {
  final LanguageController lang;
  final ProvinceModel province;
  final VoidCallback onDeleteProvinces;

  const _SingleProvinceSection({
    required this.lang,
    required this.province,
    required this.onDeleteProvinces,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelSectionLabel(lang.get('panel_selected_province')),
        _ProvinceCard(
          lang: lang,
          province: province,
          onDelete: onDeleteProvinces,
        ),
      ],
    );
  }
}

class _MultiProvinceSection extends StatelessWidget {
  final LanguageController lang;
  final int count;
  final VoidCallback onMergeProvinces;
  final VoidCallback onDeleteProvinces;

  const _MultiProvinceSection({
    required this.lang,
    required this.count,
    required this.onMergeProvinces,
    required this.onDeleteProvinces,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelSectionLabel(lang.get('panel_multi_select')),
        _MultiSelectCard(
          lang: lang,
          count: count,
          onMerge: onMergeProvinces,
          onDelete: onDeleteProvinces,
        ),
      ],
    );
  }
}

class _ProvinceCard extends StatelessWidget {
  final LanguageController lang;
  final ProvinceModel province;
  final VoidCallback onDelete;

  const _ProvinceCard({required this.lang, required this.province, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 50) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppTheme.bg3, borderRadius: BorderRadius.circular(AppTheme.radiusSm), border: Border.all(color: AppTheme.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 14, height: 14, decoration: BoxDecoration(color: province.color, borderRadius: BorderRadius.circular(3), border: Border.all(color: AppTheme.border))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lang.get('panel_province_id').replaceAll('{id}', province.id.toString()),
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Tooltip(message: lang.get('panel_tooltip_delete'), child: IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints()))
                ],
              ),
              const SizedBox(height: 6),
              Text(lang.get('panel_vertices_count').replaceAll('{count}', province.pointCount.toString()), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              Text(lang.get('panel_bbox').replaceAll('{w}', province.boundingBox.width.toString()).replaceAll('{h}', province.boundingBox.height.toString()), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        );
      },
    );
  }
}

class _MultiSelectCard extends StatelessWidget {
  final LanguageController lang;
  final int count;
  final VoidCallback onMerge;
  final VoidCallback onDelete;

  const _MultiSelectCard({required this.lang, required this.count, required this.onMerge, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 50) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppTheme.bg3, borderRadius: BorderRadius.circular(AppTheme.radiusSm), border: Border.all(color: AppTheme.border)),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      lang.get('panel_multi_count').replaceAll('{count}', count.toString()),
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Tooltip(message: lang.get('panel_tooltip_delete_all'), child: IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline, color: AppTheme.danger, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints()))
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onMerge,
                  icon: const Icon(Icons.merge_type, size: 16),
                  label: Text(lang.get('panel_btn_merge')),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.info),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}