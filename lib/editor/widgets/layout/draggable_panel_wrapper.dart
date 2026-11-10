import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/language_controller.dart';
import '../../../theme/app_theme.dart';
import '../../layout/panel_layout_controller.dart';
import '../../layout/panel_state.dart';

class DraggablePanelWrapper extends StatefulWidget {
  final String id;
  final PanelLayoutController controller;
  final LanguageController lang;
  final double uiScale; // Injeção da escala que ditará o tamanho interno do conteúdo
  final Widget child;

  const DraggablePanelWrapper({
    super.key,
    required this.id,
    required this.controller,
    required this.lang,
    this.uiScale = 1.0,
    required this.child,
  });

  @override
  State<DraggablePanelWrapper> createState() => _DraggablePanelWrapperState();
}

class _DraggablePanelWrapperState extends State<DraggablePanelWrapper> {
  bool _isHovered = false;
  Timer? _hoverTimer;
  int _tapCount = 0;
  DateTime _lastTapTime = DateTime.now();

  static const double earThickness = 32.0;
  static const double editControlsThickness = 96.0;

  void _onEnter() {
    _hoverTimer?.cancel();
    if (!_isHovered && mounted) {
      setState(() => _isHovered = true);
    }
  }

  void _onExit() {
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _isHovered = false);
      }
    });
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.getPanel(widget.id);
        final baseRect = widget.controller.getTargetRect(widget.id, screenSize);
        final duration = state.isActivelyDragging ? Duration.zero : const Duration(milliseconds: 200);

        final extraProtrusion = state.isEditMode ? editControlsThickness : earThickness;

        double wrapperLeft = baseRect.left;
        double wrapperTop = baseRect.top;
        double wrapperWidth = baseRect.width;
        double wrapperHeight = baseRect.height;

        double panelLeft = 0;
        double panelTop = 0;
        double panelWidth = baseRect.width;
        double panelHeight = baseRect.height;

        if (state.dock == DockPosition.top) {
          panelHeight = state.isCollapsed ? 0 : baseRect.height;
          wrapperHeight = panelHeight + extraProtrusion;
        } else if (state.dock == DockPosition.bottom) {
          panelHeight = state.isCollapsed ? 0 : baseRect.height;
          wrapperHeight = panelHeight + extraProtrusion;
          wrapperTop = screenSize.height - wrapperHeight;
          panelTop = extraProtrusion;
        } else if (state.dock == DockPosition.left) {
          panelWidth = state.isCollapsed ? 0 : baseRect.width;
          wrapperWidth = panelWidth + extraProtrusion;
        } else if (state.dock == DockPosition.right) {
          panelWidth = state.isCollapsed ? 0 : baseRect.width;
          wrapperWidth = panelWidth + extraProtrusion;
          wrapperLeft = screenSize.width - wrapperWidth;
          panelLeft = extraProtrusion;
        } else {
          if (state.isEditMode) {
            wrapperWidth = math.max(baseRect.width, 104.0);

            final bool placeAbove = baseRect.top >= 50.0;
            if (placeAbove) {
              wrapperTop = baseRect.top - 50.0;
              panelTop = 50.0;
              wrapperHeight = baseRect.height + 50.0;
            } else {
              wrapperTop = baseRect.top;
              panelTop = 0.0;
              wrapperHeight = baseRect.height + 50.0;
            }
          }
        }

        BorderRadiusGeometry radius = BorderRadius.circular(AppTheme.radiusMd);
        if (state.dock == DockPosition.top || state.dock == DockPosition.bottom) {
          radius = BorderRadius.zero;
        } else if (state.dock == DockPosition.left) {
          radius = const BorderRadius.horizontal(right: Radius.circular(AppTheme.radiusMd));
        } else if (state.dock == DockPosition.right) {
          radius = const BorderRadius.horizontal(left: Radius.circular(AppTheme.radiusMd));
        }

        return AnimatedPositioned(
          duration: duration,
          curve: Curves.easeOutCubic,
          left: wrapperLeft,
          top: wrapperTop,
          width: wrapperWidth,
          height: wrapperHeight,
          child: MouseRegion(
            onEnter: (_) => _onEnter(),
            onExit: (_) => _onExit(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: panelLeft,
                  top: panelTop,
                  width: panelWidth,
                  height: panelHeight,
                  child: GestureDetector(
                    onTap: () {
                      final now = DateTime.now();
                      if (now.difference(_lastTapTime).inMilliseconds > 400) {
                        _tapCount = 1;
                      } else {
                        _tapCount++;
                        if (_tapCount >= 4) {
                          widget.controller.toggleEditMode(widget.id);
                          _tapCount = 0;
                        }
                      }
                      _lastTapTime = now;
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.bg2,
                        borderRadius: radius,
                        border: Border.all(
                          color: state.isEditMode ? AppTheme.accent : AppTheme.border,
                          width: state.isEditMode ? 2.0 : 1.0,
                        ),
                        boxShadow: state.dock == DockPosition.none
                            ? [const BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 8))]
                            : [],
                      ),
                      child: Stack(
                        children: [
                          AnimatedOpacity(
                            opacity: state.isCollapsed ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: IgnorePointer(
                              ignoring: state.isEditMode || state.isCollapsed,
                              child: ClipRRect(
                                borderRadius: radius,
                                // Aqui está a mágica: O OverflowBox deixa o filho interno (widget.child) nascer no tamanho gigante base dele,
                                // e o Transform.scale esmaga ele visualmente para caber EXATAMENTE dentro da borda da caixa protetora, 
                                // prevenindo erros de layout (tiras amarelas e pretas).
                                child: OverflowBox(
                                  alignment: Alignment.topLeft,
                                  maxWidth: double.infinity,
                                  maxHeight: double.infinity,
                                  child: Transform.scale(
                                    scale: widget.uiScale,
                                    alignment: Alignment.topLeft,
                                    child: SizedBox(
                                      width: state.isCollapsed ? 0 : (panelWidth / widget.uiScale),
                                      height: state.isCollapsed ? 0 : (panelHeight / widget.uiScale),
                                      child: widget.child,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (state.isEditMode) ...[
                            _buildInternalEditOverlay(context, state),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                if (state.isEditMode) ...[
                  _buildExternalEditActionPill(state, panelLeft, panelTop, panelWidth, panelHeight, screenSize),
                ],

                if (state.dock != DockPosition.none && !state.isEditMode) ...[
                  _buildCenterFacingEar(context, state, panelWidth, panelHeight),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExternalEditActionPill(
    PanelState state,
    double panelLeft,
    double panelTop,
    double panelWidth,
    double panelHeight,
    Size screenSize,
  ) {
    double? left, top, right, bottom;

    if (state.dock == DockPosition.top) {
      top = panelTop + panelHeight + 6;
      left = panelLeft + math.max(0.0, (panelWidth - 90) / 2);
    } else if (state.dock == DockPosition.bottom) {
      top = panelTop - 46;
      left = panelLeft + math.max(0.0, (panelWidth - 90) / 2);
    } else if (state.dock == DockPosition.left) {
      left = panelLeft + panelWidth + 6;
      top = panelTop + math.max(0.0, (panelHeight - 44) / 2);
    } else if (state.dock == DockPosition.right) {
      left = panelLeft - 90;
      top = panelTop + math.max(0.0, (panelHeight - 44) / 2);
    } else {
      if (panelTop >= 44.0) {
        top = panelTop - 44.0;
      } else {
        top = panelTop + panelHeight + 6.0;
      }
      left = panelLeft + 6.0;
    }

    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: Material(
        color: AppTheme.bg3,
        elevation: 8,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.accent, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: widget.lang.get('tooltip_toggle_orientation'),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => widget.controller.toggleOrientation(widget.id, screenSize),
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        child: const Icon(Icons.rotate_90_degrees_ccw, size: 18, color: AppTheme.accent),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              Tooltip(
                message: widget.lang.get('tooltip_done'),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Material(
                    color: AppTheme.success,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => widget.controller.disableEditMode(widget.id, screenSize),
                      child: const SizedBox(
                        width: 34,
                        height: 34,
                        child: Center(
                          child: Icon(Icons.check, size: 20, color: AppTheme.bg0),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterFacingEar(
    BuildContext context,
    PanelState state,
    double panelW,
    double panelH,
  ) {
    final platform = Theme.of(context).platform;
    final isMobile = platform == TargetPlatform.android || 
                     platform == TargetPlatform.iOS ||
                     MediaQuery.of(context).size.shortestSide < 600;

    final isVisible = state.isCollapsed || _isHovered || isMobile;
    IconData icon;
    double? left, top, right, bottom;

    final isHorz = state.dock == DockPosition.top || state.dock == DockPosition.bottom;

    if (state.dock == DockPosition.top) {
      icon = state.isCollapsed ? Icons.expand_more : Icons.expand_less;
      top = panelH;
      left = math.max(0.0, (panelW - 64) / 2);
    } else if (state.dock == DockPosition.bottom) {
      icon = state.isCollapsed ? Icons.expand_less : Icons.expand_more;
      top = 0;
      left = math.max(0.0, (panelW - 64) / 2);
    } else if (state.dock == DockPosition.left) {
      icon = state.isCollapsed ? Icons.chevron_right : Icons.chevron_left;
      left = panelW;
      top = math.max(0.0, (panelH - 64) / 2);
    } else {
      icon = state.isCollapsed ? Icons.chevron_left : Icons.chevron_right;
      left = 0;
      top = math.max(0.0, (panelH - 64) / 2);
    }

    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: AnimatedOpacity(
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: IgnorePointer(
          ignoring: !isVisible,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.controller.toggleCollapse(widget.id),
            child: Container(
              width: isHorz ? 64 : earThickness,
              height: isHorz ? earThickness : 64,
              decoration: BoxDecoration(
                color: state.isCollapsed ? AppTheme.accent : AppTheme.bg3,
                border: Border.all(color: state.isCollapsed ? AppTheme.bg0 : AppTheme.border),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: state.isCollapsed ? AppTheme.bg0 : AppTheme.accent,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInternalEditOverlay(BuildContext context, PanelState state) {
    final screenSize = MediaQuery.of(context).size;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bg0.withValues(alpha: 0.65),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) => widget.controller.updatePanelPosition(widget.id, details.delta, screenSize),
              onPanEnd: (_) => widget.controller.endDrag(widget.id),
              child: const MouseRegion(
                cursor: SystemMouseCursors.move,
                child: Center(child: Icon(Icons.open_with, color: AppTheme.accent, size: 36)),
              ),
            ),
          ),
          _buildDirectionalResizeBar(state),
        ],
      ),
    );
  }

  Widget _buildDirectionalResizeBar(PanelState state) {
    if (state.dock == DockPosition.top) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) => widget.controller.updatePanelSize(widget.id, details.delta),
          onPanEnd: (_) => widget.controller.endDrag(widget.id),
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: Container(
              height: 20,
              width: double.infinity,
              color: AppTheme.accent.withValues(alpha: 0.2),
              child: const Center(child: Icon(Icons.drag_handle, color: AppTheme.accent, size: 16)),
            ),
          ),
        ),
      );
    }

    if (state.dock == DockPosition.bottom) {
      return Align(
        alignment: Alignment.topCenter,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) => widget.controller.updatePanelSize(widget.id, details.delta),
          onPanEnd: (_) => widget.controller.endDrag(widget.id),
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: Container(
              height: 20,
              width: double.infinity,
              color: AppTheme.accent.withValues(alpha: 0.2),
              child: const Center(child: Icon(Icons.drag_handle, color: AppTheme.accent, size: 16)),
            ),
          ),
        ),
      );
    }

    if (state.dock == DockPosition.left) {
      return Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) => widget.controller.updatePanelSize(widget.id, details.delta),
          onPanEnd: (_) => widget.controller.endDrag(widget.id),
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: Container(
              width: 20,
              height: double.infinity,
              color: AppTheme.accent.withValues(alpha: 0.2),
              child: const Center(child: Icon(Icons.drag_indicator, color: AppTheme.accent, size: 16)),
            ),
          ),
        ),
      );
    }

    if (state.dock == DockPosition.right) {
      return Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) => widget.controller.updatePanelSize(widget.id, details.delta),
          onPanEnd: (_) => widget.controller.endDrag(widget.id),
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: Container(
              width: 20,
              height: double.infinity,
              color: AppTheme.accent.withValues(alpha: 0.2),
              child: const Center(child: Icon(Icons.drag_indicator, color: AppTheme.accent, size: 16)),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.bottomRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) => widget.controller.updatePanelSize(widget.id, details.delta),
        onPanEnd: (_) => widget.controller.endDrag(widget.id),
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpLeftDownRight,
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.aspect_ratio, color: AppTheme.accent, size: 22),
          ),
        ),
      ),
    );
  }
}