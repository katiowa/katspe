part of '../expandable_action_menu.dart';

mixin _MenuLayoutBuilder on _ExpandableActionMenuStateBase, _SettingsPillBuilder {

  Widget _buildMenuLayout(BuildContext context) {
    final dir = widget.direction;
    final isVertical = dir == ActionExpandDirection.up || dir == ActionExpandDirection.down;

    final List<Widget> mappedActions = widget.actions.map((w) => Padding(padding: const EdgeInsets.all(4), child: w)).toList();
    
    final List<Widget> displayActions = (dir == ActionExpandDirection.up || dir == ActionExpandDirection.left) 
        ? mappedActions.reversed.toList() 
        : mappedActions;
        
    final Widget actionsList = isVertical
        ? Column(mainAxisSize: MainAxisSize.min, children: displayActions)
        : Row(mainAxisSize: MainAxisSize.min, children: displayActions);

    final settingsSubmenu = _buildSettingsSubmenu();
    final fabStack = _buildFabStack();

    Widget innerLayout;
    
    if (dir == ActionExpandDirection.up) {
      innerLayout = Row(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSize(duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic, child: _isOpen ? Padding(padding: const EdgeInsets.only(bottom: 8), child: actionsList) : const SizedBox.shrink()),
              fabStack,
            ]
          ),
          if (_showSettings) Padding(padding: const EdgeInsets.only(left: 12), child: settingsSubmenu),
        ],
      );
    } else if (dir == ActionExpandDirection.down) {
      innerLayout = Row(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fabStack,
              AnimatedSize(duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic, child: _isOpen ? Padding(padding: const EdgeInsets.only(top: 8), child: actionsList) : const SizedBox.shrink()),
            ]
          ),
          if (_showSettings) Padding(padding: const EdgeInsets.only(left: 12), child: settingsSubmenu),
        ],
      );
    } else if (dir == ActionExpandDirection.right) {
      innerLayout = Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showSettings) Padding(padding: const EdgeInsets.only(bottom: 12), child: settingsSubmenu),
          Row(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              fabStack,
              AnimatedSize(duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic, child: _isOpen ? Padding(padding: const EdgeInsets.only(left: 8), child: actionsList) : const SizedBox.shrink()),
            ]
          ),
        ],
      );
    } else {
      innerLayout = Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_showSettings) Padding(padding: const EdgeInsets.only(bottom: 12), child: settingsSubmenu),
          Row(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedSize(duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic, child: _isOpen ? Padding(padding: const EdgeInsets.only(right: 8), child: actionsList) : const SizedBox.shrink()),
              fabStack,
            ]
          ),
        ],
      );
    }

    return Transform.scale(
      scale: _scale,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          decoration: BoxDecoration(
            border: _isResizing ? Border.all(color: AppTheme.accent, width: 2) : null,
            borderRadius: BorderRadius.circular(16),
            color: _isResizing ? AppTheme.accent.withValues(alpha: 0.1) : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              innerLayout,
              
              if (_isResizing)
                Positioned(
                  top: -8, right: -8,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _scale = (_scale + details.delta.dx * 0.01).clamp(0.6, 1.5);
                      });
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpRightDownLeft,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.touch_app, size: 14, color: AppTheme.bg0),
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
}