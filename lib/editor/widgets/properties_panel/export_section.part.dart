part of '../properties_panel.dart';

class _ExportSection extends StatelessWidget {
  final LanguageController lang;
  final ExportOptions exportOptions;
  final bool hasSelection;
  final List<Map<String, dynamic>> poiCategories;
  final ValueChanged<ExportOptions> onChanged;
  final VoidCallback onRunExport;
  final bool isExporting;
  final EngineStorageManager storage;
  final List<String> lastExportedFiles;

  const _ExportSection({
    required this.lang,
    required this.exportOptions,
    required this.hasSelection,
    required this.poiCategories,
    required this.onChanged,
    required this.onRunExport,
    required this.isExporting,
    required this.storage,
    required this.lastExportedFiles,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelSectionLabel(lang.get('panel_export')),
        _ExportPanel(
          lang: lang, 
          options: exportOptions,
          hasSelection: hasSelection,
          poiCategories: poiCategories,
          onChanged: onChanged, 
          onRunExport: onRunExport,
          isExporting: isExporting, 
          storage: storage,
        ),
        if (lastExportedFiles.isNotEmpty) ...[
          PanelSectionLabel(lang.get('panel_last_export')),
          ...lastExportedFiles.map((f) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(f, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
          )),
        ],
      ],
    );
  }
}

class _ExportPanel extends StatefulWidget {
  final LanguageController lang;
  final ExportOptions options;
  final bool hasSelection;
  final List<Map<String, dynamic>> poiCategories;
  final ValueChanged<ExportOptions> onChanged;
  final VoidCallback onRunExport;
  final bool isExporting;
  final EngineStorageManager storage;

  const _ExportPanel({
    required this.lang,
    required this.options,
    required this.hasSelection,
    required this.poiCategories,
    required this.onChanged,
    required this.onRunExport,
    required this.isExporting,
    required this.storage,
  });

  @override
  State<_ExportPanel> createState() => _ExportPanelState();
}

class _ExportPanelState extends State<_ExportPanel> {
  List<String> _converters = [];

  @override
  void initState() {
    super.initState();
    widget.storage.getAvailableConverters().then((list) {
      if (list.isNotEmpty && mounted) {
        setState(() => _converters = list);
        if (!list.contains(widget.options.converterName)) {
           widget.onChanged(widget.options.copyWith(converterName: list.first));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasConverters = _converters.isNotEmpty;
    final dropdownValue = _converters.contains(widget.options.converterName)
        ? widget.options.converterName
        : (hasConverters ? _converters.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: AppTheme.bg1, border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                dropdownColor: AppTheme.bg1,
                isExpanded: true,
                isDense: true,
                value: dropdownValue,
                hint: Text(widget.lang.get('dialog_load_none'), style: const TextStyle(color: AppTheme.textDisabled, fontSize: 12)),
                icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
                onChanged: hasConverters
                    ? (String? newValue) {
                        if (newValue != null) {
                          widget.onChanged(widget.options.copyWith(converterName: newValue));
                        }
                      }
                    : null,
                items: _converters.map((c) => DropdownMenuItem<String>(value: c, child: Text(c.toUpperCase(), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)))).toList(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _toggle(widget.lang.get('export_map'), widget.options.exportFullMap, (v) => widget.onChanged(widget.options.copyWith(exportFullMap: v))),
        _toggle(widget.lang.get('export_provinces_zip'), widget.options.exportProvincesZip, (v) => widget.onChanged(widget.options.copyWith(exportProvincesZip: v))),
        _toggle(widget.lang.get('export_target_only'), widget.options.exportTargetProvinceOnly, widget.hasSelection ? (v) => widget.onChanged(widget.options.copyWith(exportTargetProvinceOnly: v)) : null),
        for (final category in widget.poiCategories)
          _toggle(
            category['label']?.toString() ?? category['id']?.toString() ?? '',
            widget.options.exportPoiCategories.contains(category['id']),
            (v) {
              final updated = Set<String>.from(widget.options.exportPoiCategories);
              final id = category['id']?.toString() ?? '';
              if (v) {
                updated.add(id);
              } else {
                updated.remove(id);
              }
              widget.onChanged(widget.options.copyWith(exportPoiCategories: updated));
            },
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: widget.options.hasAnythingSelected && !widget.isExporting ? widget.onRunExport : null,
            icon: widget.isExporting ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_outlined, size: 16),
            label: Text(widget.isExporting ? widget.lang.get('export_btn_exporting') : widget.lang.get('export_btn_export')),
          ),
        ),
      ],
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool>? onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, color: onChanged == null ? AppTheme.textDisabled : AppTheme.textPrimary))),
          Transform.scale(scale: 0.75, child: Switch(value: value, onChanged: onChanged)),
        ],
      ),
    );
  }
}