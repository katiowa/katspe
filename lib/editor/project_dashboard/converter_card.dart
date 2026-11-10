import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/converter_display.dart';
import '../../theme/app_theme.dart';

class ConverterCardWidget extends StatefulWidget {
  final ConverterDisplayModel converter;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onUnselect; 
  final String unselectLabel; 
  final VoidCallback onDelete; 
  final String deleteLabel; 
  final bool canDelete; 

  const ConverterCardWidget({
    super.key, 
    required this.converter, 
    required this.isSelected, 
    required this.onTap, 
    required this.onUnselect,
    required this.unselectLabel,
    required this.onDelete,
    required this.deleteLabel,
    this.canDelete = true,
  });

  @override
  State<ConverterCardWidget> createState() => _ConverterCardWidgetState();
}

class _ConverterCardWidgetState extends State<ConverterCardWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Identifica quando o card está estreito (ex: celular em modo retrato)
        final isNarrow = constraints.maxWidth < 450;
        final double titleFontSize = isNarrow ? 20.0 : 28.0;
        final double titleRight = isNarrow 
            ? (widget.isSelected ? 84.0 : 50.0) 
            : (widget.isSelected ? 220.0 : 70.0);

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: widget.isSelected ? AppTheme.success : AppTheme.border, 
                  width: widget.isSelected ? 3.0 : 1.0,
                ),
                boxShadow: widget.isSelected || _isHovered 
                    ? [
                        BoxShadow(
                          color: (widget.isSelected ? AppTheme.success : AppTheme.accent).withValues(alpha: 0.3), 
                          blurRadius: 16, 
                          offset: const Offset(0, 4),
                        )
                      ] 
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd - 2),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedScale(
                      scale: _isHovered ? 1.08 : 1.0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      child: Image.file(
                        File(widget.converter.imagePath),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        cacheWidth: (950 * MediaQuery.of(context).devicePixelRatio).round(),
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppTheme.bg3,
                          padding: const EdgeInsets.all(48),
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 48, color: AppTheme.textDisabled),
                          ),
                        ),
                      ),
                    ),

                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter, 
                            end: Alignment.topCenter,
                            colors: [
                              AppTheme.bg0.withValues(alpha: 0.95), 
                              AppTheme.bg0.withValues(alpha: 0.25),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Título e Data com margem adaptativa para não achatar o texto
                    Positioned(
                      top: isNarrow ? 14 : 24, 
                      left: isNarrow ? 14 : 24,
                      right: titleRight,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.converter.title, 
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white, 
                              fontSize: titleFontSize, 
                              fontWeight: FontWeight.bold, 
                              shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
                            ),
                          ),
                          if (widget.converter.date.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.converter.date, 
                              style: TextStyle(
                                color: AppTheme.accent, 
                                fontSize: isNarrow ? 12 : 14, 
                                fontWeight: FontWeight.bold, 
                                letterSpacing: 1.1, 
                                shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Grupo de botões no topo direito (em cards compactos, vira botão de energia circular)
                    Positioned(
                      top: isNarrow ? 12 : 20, 
                      right: isNarrow ? 12 : 20,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.isSelected) ...[
                            if (isNarrow)
                              Tooltip(
                                message: widget.unselectLabel,
                                child: Material(
                                  color: AppTheme.danger,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: widget.onUnselect,
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(Icons.power_settings_new, color: AppTheme.bg0, size: 16),
                                    ),
                                  ),
                                ),
                              )
                            else
                              ActionChip(
                                label: Text(
                                  widget.unselectLabel, 
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.bg0),
                                ),
                                backgroundColor: AppTheme.danger,
                                side: BorderSide.none,
                                avatar: const Icon(Icons.power_settings_new, color: AppTheme.bg0, size: 16),
                                onPressed: widget.onUnselect,
                              ),
                            const SizedBox(width: 8),
                          ],
                          if (widget.canDelete)
                            Tooltip(
                              message: widget.deleteLabel,
                              child: Material(
                                color: AppTheme.bg3.withValues(alpha: 0.85),
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: widget.onDelete,
                                  child: Padding(
                                    padding: EdgeInsets.all(isNarrow ? 7 : 8),
                                    child: const Icon(Icons.delete_outline, size: 16, color: AppTheme.danger),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Links externos
                    if (widget.converter.links.isNotEmpty)
                      Positioned(
                        bottom: isNarrow ? 12 : 24, 
                        right: isNarrow ? 12 : 24,
                        child: Wrap(
                          spacing: isNarrow ? 6 : 12, 
                          runSpacing: isNarrow ? 6 : 12,
                          children: widget.converter.links.map((link) {
                            return ActionChip(
                              label: Text(link.name, style: TextStyle(fontSize: isNarrow ? 11 : 12, fontWeight: FontWeight.bold)),
                              backgroundColor: AppTheme.bg3.withValues(alpha: 0.85),
                              side: BorderSide.none, 
                              padding: EdgeInsets.symmetric(horizontal: isNarrow ? 6 : 8, vertical: isNarrow ? 2 : 4),
                              onPressed: () async {
                                final url = Uri.parse(link.url);
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}