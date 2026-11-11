import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../core/app_preferences.dart';
import '../../core/engine_context.dart';
import '../../core/language_controller.dart';
import '../../engine/engine_storage.dart';
import '../../models/converter_display.dart';
import '../../theme/app_theme.dart';
import '../project_dashboard/dashboard_menu.dart';
import '../project_dashboard/pending_changes_bar.dart';
import '../project_dashboard/tab_converters.dart';
import '../project_dashboard/tab_new_project.dart';
import '../project_dashboard/tab_procedural.dart';
import '../project_dashboard/tab_scenario.dart';
import 'disclaimer_dialog.dart';

class ProjectDashboardDialog extends StatefulWidget {
  final LanguageController lang;
  final AppPreferences prefs;
  final EngineStorageManager storage;
  final VoidCallback onClearWorkspace;
  final void Function(String path) onLoadMap;
  final void Function(String path) onLoadNativeCache;
  final void Function(String path) onLoadBackground;

  const ProjectDashboardDialog({
    super.key, required this.lang, required this.prefs, required this.storage,
    required this.onClearWorkspace, required this.onLoadMap, required this.onLoadNativeCache, required this.onLoadBackground,
  });

  @override
  State<ProjectDashboardDialog> createState() => _ProjectDashboardDialogState();
}

class _ProjectDashboardDialogState extends State<ProjectDashboardDialog> {
  int _activeTab = 0;
  List<ConverterDisplayModel>? _convertersList;

  String? _initialConverter;
  String? _pendingConverter;
  String? _pendingMapPath;
  String? _pendingNativeCachePath;
  String? _pendingBgPath;
  
  bool _isImportingConverter = false;

  bool get _hasPendingChanges => _pendingMapPath != null || _pendingNativeCachePath != null || _pendingBgPath != null || (_pendingConverter != _initialConverter);

  @override
  void initState() {
    super.initState();
    _initialConverter = widget.prefs.selectedConverter;
    _pendingConverter = _initialConverter;
    _loadAndCheckConverters();
  }

  Future<void> _loadAndCheckConverters() async {
    final list = await widget.storage.getConvertersDisplayInfo();
    if (mounted) {
      setState(() {
        _convertersList = list;
        if (list.length == 1 && _initialConverter == null) {
          _pendingConverter = list.first.folderName;
        }
      });
    }
  }

  void _revertChanges() => setState(() { 
    _pendingConverter = _initialConverter; 
    _pendingMapPath = null; 
    _pendingNativeCachePath = null;
    _pendingBgPath = null; 
  });

  void _confirmChanges() {
    if (_pendingConverter != _initialConverter) {
      widget.prefs.setSelectedConverter(_pendingConverter);
      _initialConverter = _pendingConverter;
    }
    
    // Executa ou o Binário ou o Mapa Tradicional (para evitar sobrescritas conflitantes simultâneas)
    if (_pendingNativeCachePath != null) { 
      widget.onLoadNativeCache(_pendingNativeCachePath!); 
      _pendingNativeCachePath = null; 
    } else if (_pendingMapPath != null) { 
      widget.onLoadMap(_pendingMapPath!); 
      _pendingMapPath = null; 
    }
    
    if (_pendingBgPath != null) { 
      widget.onLoadBackground(_pendingBgPath!); 
      _pendingBgPath = null; 
    }
    
    setState(() {});
  }

  Future<void> _importNewConverter() async {
    final agreed = await showDisclaimerDialog(context, widget.lang);
    if (agreed != true) return;

    final res = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['zip']);
    if (res == null || res.path == null) return;

    setState(() => _isImportingConverter = true);
    try {
      final newConverterName = await widget.storage.importConverterZip(res.path!);
      
      widget.storage.invalidateConvertersCache();
      await _loadAndCheckConverters();
      
      if (mounted) {
        setState(() {
          _pendingConverter = newConverterName;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.lang.get('import_success')), 
          backgroundColor: AppTheme.success
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.lang.get('import_error').replaceAll('{error}', e.toString())), 
          backgroundColor: AppTheme.danger
        ));
      }
    } finally {
      if (mounted) setState(() => _isImportingConverter = false);
    }
  }

  Future<void> _deleteConverter(ConverterDisplayModel converter) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: AppTheme.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.lang.get('converter_delete_confirm_title'),
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          widget.lang.get('converter_delete_confirm_desc').replaceAll('{name}', converter.title),
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(widget.lang.get('dialog_cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(widget.lang.get('btn_delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (EngineContext.instance.api.lua.activeConverterName == converter.folderName) {
        EngineContext.instance.api.lua.deactivateConverter();
      }

      await widget.storage.deleteConverter(converter.folderName);
      
      if (_pendingConverter == converter.folderName) {
        _pendingConverter = '__none__';
      }

      await _loadAndCheckConverters();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.lang.get('delete_success')), 
          backgroundColor: AppTheme.success
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasPendingChanges && !_isImportingConverter,
      onPopInvokedWithResult: (didPop, result) {},
      child: Dialog(
        backgroundColor: AppTheme.bg1,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd), side: const BorderSide(color: AppTheme.border)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenSize = MediaQuery.of(context).size;
            final isNarrow = constraints.maxWidth < 620 || screenSize.width < 620;

            final Widget detailContent = Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildDetailContent(isNarrow),
              ),
            );

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 1000, 
                maxHeight: math.min(650, screenSize.height * 0.95),
              ),
              child: isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DashboardMenu(
                          lang: widget.lang, 
                          activeTab: _activeTab, 
                          hasPendingChanges: _hasPendingChanges,
                          isNarrow: true,
                          onTabChanged: _isImportingConverter ? (idx) {} : (idx) => setState(() => _activeTab = idx),
                          onCancel: () => Navigator.of(context).pop(),
                        ),
                        const Divider(height: 1, color: AppTheme.border),
                        detailContent,
                        PendingChangesBar(lang: widget.lang, hasPendingChanges: _hasPendingChanges, onRevert: _revertChanges, onConfirm: _confirmChanges),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DashboardMenu(
                          lang: widget.lang, 
                          activeTab: _activeTab, 
                          hasPendingChanges: _hasPendingChanges,
                          isNarrow: false,
                          onTabChanged: _isImportingConverter ? (idx) {} : (idx) => setState(() => _activeTab = idx),
                          onCancel: () => Navigator.of(context).pop(),
                        ),
                        const VerticalDivider(width: 1, color: AppTheme.border),
                        Expanded(
                          child: Column(
                            children: [
                              detailContent,
                              PendingChangesBar(lang: widget.lang, hasPendingChanges: _hasPendingChanges, onRevert: _revertChanges, onConfirm: _confirmChanges),
                            ],
                          ),
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailContent(bool isNarrow) {
    switch (_activeTab) {
      case 0: return TabNewProject(key: const ValueKey(0), lang: widget.lang, isNarrow: isNarrow, onClear: () { widget.onClearWorkspace(); Navigator.of(context).pop(); });
      case 1: 
        List<String> exts = [];
        if (_convertersList != null && _pendingConverter != null && _pendingConverter != '__none__') {
          ConverterDisplayModel? info;
          try {
            info = _convertersList!.firstWhere((c) => c.folderName == _pendingConverter);
          } catch (_) {}
          if (info != null) exts = info.supportedExtensions;
        }
        return TabScenario(
          key: const ValueKey(1), lang: widget.lang, 
          pendingMapPath: _pendingMapPath, 
          pendingNativeCachePath: _pendingNativeCachePath,
          pendingBgPath: _pendingBgPath, 
          allowedExtensions: exts,
          isNarrow: isNarrow,
          // Ao selecionar um, remove o outro, para não confundir o commit state
          onMapSelected: (p) => setState(() { _pendingMapPath = p; _pendingNativeCachePath = null; }), 
          onNativeCacheSelected: (p) => setState(() { _pendingNativeCachePath = p; _pendingMapPath = null; }),
          onBgSelected: (p) => setState(() => _pendingBgPath = p)
        );
      case 2: return TabProcedural(key: const ValueKey(2), lang: widget.lang, isNarrow: isNarrow);
      case 3: return TabConverters(
        key: const ValueKey(3), lang: widget.lang, 
        convertersList: _convertersList, 
        currentSelection: _pendingConverter,
        isImporting: _isImportingConverter,
        isNarrow: isNarrow,
        onImport: _importNewConverter,
        onDelete: _deleteConverter,
        onSelect: (c) => setState(() => _pendingConverter = c)
      );
      default: return const SizedBox.shrink();
    }
  }
}