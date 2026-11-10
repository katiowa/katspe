import 'package:flutter/material.dart';
import '../../core/language_controller.dart';
import '../../models/converter_display.dart';
import '../../theme/app_theme.dart';
import 'converter_card.dart';

class TabConverters extends StatelessWidget {
  final LanguageController lang;
  final List<ConverterDisplayModel>? convertersList;
  final String? currentSelection;
  final ValueChanged<String> onSelect;
  final bool isImporting;
  final VoidCallback onImport;
  final void Function(ConverterDisplayModel converter) onDelete;
  final bool isNarrow;

  const TabConverters({
    super.key, required this.lang, required this.convertersList,
    required this.currentSelection, required this.onSelect,
    required this.isImporting, required this.onImport,
    required this.onDelete,
    this.isNarrow = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (convertersList == null) {
      child = const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    } else if (convertersList!.isEmpty) {
      child = Center(child: Text(lang.get('dashboard_no_converters'), style: const TextStyle(color: AppTheme.textDisabled)));
    } else {
      child = _ConverterList(
        list: convertersList!, 
        currentSelection: currentSelection, 
        onSelect: onSelect,
        unselectLabel: lang.get('dashboard_disable_converter'),
        onDelete: onDelete,
        deleteLabel: lang.get('converter_delete'),
      );
    }

    return Padding(
      padding: EdgeInsets.all(isNarrow ? 12.0 : 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lang.get('dashboard_converters_title'), 
                    style: TextStyle(
                      color: AppTheme.textPrimary, 
                      fontSize: isNarrow ? 18 : 22, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lang.get('dashboard_converters_desc'), 
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)
                  ),
                ],
              ),
              if (isImporting)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: onImport,
                  icon: const Icon(Icons.folder_zip, size: 16),
                  label: Text(lang.get('import_converter_btn'), style: const TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: ClipRRect(child: child)),
        ],
      ),
    );
  }
}

class _ConverterList extends StatefulWidget {
  final List<ConverterDisplayModel> list;
  final String? currentSelection;
  final ValueChanged<String> onSelect;
  final String unselectLabel;
  final void Function(ConverterDisplayModel converter) onDelete;
  final String deleteLabel;

  const _ConverterList({
    required this.list, 
    required this.currentSelection, 
    required this.onSelect,
    required this.unselectLabel,
    required this.onDelete,
    required this.deleteLabel,
  });

  @override
  State<_ConverterList> createState() => _ConverterListState();
}

class _ConverterListState extends State<_ConverterList> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    _initializeKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  void _initializeKeys() {
    _itemKeys.clear();
    for (var c in widget.list) {
      _itemKeys[c.folderName] = GlobalKey();
    }
  }

  @override
  void didUpdateWidget(covariant _ConverterList oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    bool listChanged = widget.list.length != oldWidget.list.length;
    if (listChanged) {
      _initializeKeys();
    }

    if (listChanged || widget.currentSelection != oldWidget.currentSelection) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  void _scrollToSelected() {
    if (widget.currentSelection == null) return;
    final key = _itemKeys[widget.currentSelection];
    
    if (key != null && key.currentContext != null && mounted) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      primary: false,
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.list.map((c) {
          return Padding(
            key: _itemKeys[c.folderName],
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: ConverterCardWidget(
              converter: c,
              isSelected: widget.currentSelection == c.folderName,
              onTap: () => widget.onSelect(c.folderName),
              unselectLabel: widget.unselectLabel,
              onUnselect: () => widget.onSelect('__none__'),
              onDelete: () => widget.onDelete(c),
              deleteLabel: widget.deleteLabel,
              canDelete: c.folderName != 'map-editor',
            ),
          );
        }).toList(),
      ),
    );
  }
}