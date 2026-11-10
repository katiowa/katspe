part of '../top_bar.dart';

extension _VisibilityMenuExtension on TopBar {
  Widget _buildVisibilityMenu() {
    return _VisibilityMenuWidget(topBar: this);
  }
}

class _VisibilityMenuWidget extends StatefulWidget {
  final TopBar topBar;

  const _VisibilityMenuWidget({required this.topBar});

  @override
  State<_VisibilityMenuWidget> createState() => _VisibilityMenuWidgetState();
}

class _VisibilityMenuWidgetState extends State<_VisibilityMenuWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topBar = widget.topBar;
    final screenSize = MediaQuery.of(context).size;
    // Garante que o menu respeite as margens da tela tanto no celular quanto no PC
    final maxMenuWidth = math.min(screenSize.width - 32.0, 520.0);

    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(AppTheme.bg2),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: const BorderSide(color: AppTheme.border),
          ),
        ),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
      ),
      builder: (context, controller, child) {
        return Tooltip(
          message: topBar.lang.get('topbar_visibility'), 
          child: IconButton(
            icon: const Icon(Icons.layers_outlined, size: 18, color: AppTheme.textPrimary), 
            onPressed: () { 
              if (controller.isOpen) { 
                controller.close(); 
              } else { 
                controller.open(); 
              } 
            },
          ),
        );
      },
      menuChildren: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxMenuWidth,
            maxHeight: 52,
          ),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              // Permite puxar com dedo, mouse, trackpad ou caneta
              dragDevices: {
                ui.PointerDeviceKind.touch,
                ui.PointerDeviceKind.mouse,
                ui.PointerDeviceKind.trackpad,
                ui.PointerDeviceKind.stylus,
              },
            ),
            child: Listener(
              // Converte o scroll da rodinha vertical do mouse em rolagem horizontal natural
              onPointerSignal: (pointerSignal) {
                if (pointerSignal is PointerScrollEvent && _scrollController.hasClients) {
                  final delta = pointerSignal.scrollDelta.dy != 0 
                      ? pointerSignal.scrollDelta.dy 
                      : pointerSignal.scrollDelta.dx;
                  final target = (_scrollController.offset + delta).clamp(
                    0.0,
                    _scrollController.position.maxScrollExtent,
                  );
                  _scrollController.jumpTo(target);
                }
              },
              child: SingleChildScrollView(
                controller: _scrollController,
                primary: false,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildVisItemDirect(topBar.lang.get('topbar_provinces'), topBar.showProvinces, topBar.onToggleProvinces),
                    _buildVisItemDirect(topBar.lang.get('topbar_xray'), topBar.showXRay, topBar.onToggleXRay),
                    _buildVisItemDirect(topBar.lang.get('topbar_background'), topBar.showBg, topBar.onToggleBg),
                    if (topBar.poiCategories.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: VerticalDivider(width: 1, color: AppTheme.border, indent: 4, endIndent: 4),
                      ),
                    ],
                    for (final category in topBar.poiCategories) ...[
                      _buildVisItemDirect(
                        category['label']?.toString() ?? category['id']?.toString() ?? '',
                        !topBar.hiddenCategories.contains(category['id']),
                        () => topBar.onToggleCategory(category['id']?.toString() ?? ''),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVisItemDirect(String label, bool value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: value ? AppTheme.accentMuted : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: value ? AppTheme.accent.withValues(alpha: 0.5) : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(value ? Icons.visibility : Icons.visibility_off, size: 14, color: value ? AppTheme.accent : AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: value ? AppTheme.accent : AppTheme.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}