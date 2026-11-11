import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/language_controller.dart';
import '../../theme/app_theme.dart';

class TabScenario extends StatelessWidget {
  final LanguageController lang;
  final String? pendingMapPath;
  final String? pendingNativeCachePath;
  final String? pendingBgPath;
  final List<String> allowedExtensions;
  final ValueChanged<String> onMapSelected;
  final ValueChanged<String> onNativeCacheSelected;
  final ValueChanged<String> onBgSelected;
  final bool isNarrow;

  const TabScenario({
    super.key, 
    required this.lang, 
    required this.pendingMapPath, 
    required this.pendingNativeCachePath,
    required this.pendingBgPath,
    required this.allowedExtensions, 
    required this.onMapSelected, 
    required this.onNativeCacheSelected,
    required this.onBgSelected,
    this.isNarrow = false,
  });

  @override
  Widget build(BuildContext context) {
    String mapFileLabel = lang.get('dialog_load_map_file');
    if (allowedExtensions.isNotEmpty) {
      mapFileLabel += ' (.${allowedExtensions.join(', .')})';
    }

    return SingleChildScrollView(
      primary: false,
      padding: EdgeInsets.all(isNarrow ? 14.0 : 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.get('topbar_scenario'), 
            style: TextStyle(
              color: AppTheme.textPrimary, 
              fontSize: isNarrow ? 18 : 22, 
              fontWeight: FontWeight.bold
            )
          ),
          const SizedBox(height: 16),
          
          // IMPORTAÇÃO DE MAPA VIA CONVERSOR
          _buildCard(
            title: mapFileLabel, 
            icon: Icons.map, 
            pendingPath: pendingMapPath, 
            buttonText: lang.get('dialog_load_browse'), 
            onPressed: () async {
              final res = await FilePicker.pickFile(type: FileType.any);
              
              if (res != null && res.path != null) {
                final path = res.path!;
                final fileName = path.split(Platform.pathSeparator).last;
                final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
                
                final isValid = ext.isEmpty || allowedExtensions.isEmpty || allowedExtensions.contains(ext);
                
                if (isValid) {
                  onMapSelected(path);
                }
              }
            }
          ),
          const SizedBox(height: 12),
          
          // IMPORTAÇÃO DE CACHE NATIVO BINÁRIO (NOVO)
          _buildCard(
            title: lang.get('dialog_load_native_cache'), 
            icon: Icons.memory, 
            pendingPath: pendingNativeCachePath, 
            buttonText: lang.get('dialog_load_native_cache_btn'), 
            onPressed: () async {
              // Binário puro, qualquer formato de arquivo, validação por conteúdo
              final res = await FilePicker.pickFile(type: FileType.any);
              if (res != null && res.path != null) {
                onNativeCacheSelected(res.path!);
              }
            }
          ),
          const SizedBox(height: 12),
          
          // IMAGEM DE FUNDO
          _buildCard(
            title: lang.get('dialog_load_bg_file'), 
            icon: Icons.image_outlined, 
            pendingPath: pendingBgPath, 
            buttonText: lang.get('dialog_load_browse'), 
            onPressed: () async {
              final res = await FilePicker.pickFile(type: FileType.image);
              if (res != null && res.path != null) onBgSelected(res.path!);
            }
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, String? pendingPath, required String buttonText, required VoidCallback onPressed}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.bg3, borderRadius: BorderRadius.circular(AppTheme.radiusMd), border: Border.all(color: pendingPath != null ? AppTheme.success : AppTheme.border)),
      child: Row(
        children: [
          Icon(icon, size: 28, color: pendingPath != null ? AppTheme.success : AppTheme.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                if (pendingPath != null) ...[const SizedBox(height: 4), Text(pendingPath, style: const TextStyle(color: AppTheme.success, fontSize: 11), overflow: TextOverflow.ellipsis)]
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onPressed, 
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Text(buttonText, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}