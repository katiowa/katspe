part of '../expandable_action_menu.dart';

mixin _SettingsPillBuilder on _ExpandableActionMenuStateBase {

  Widget _buildSettingsSubmenu() {
    if (!_showSettings) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.bg3,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accent),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: widget.lang.get('quick_actions_resize'),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => _isResizing = !_isResizing),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.aspect_ratio, color: _isResizing ? AppTheme.accent : AppTheme.textPrimary, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: widget.lang.get('quick_actions_direction').replaceAll('{dir}', _getDirectionName()),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _cycleDirection,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(_getDirectionIcon(), color: AppTheme.accent, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: widget.lang.get('quick_actions_move'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => widget.onDragStateChanged(true),
              onPanUpdate: (details) => widget.onPositionChanged(details.delta),
              onPanEnd: (_) => widget.onDragStateChanged(false),
              child: const MouseRegion(
                cursor: SystemMouseCursors.move,
                child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.open_with, color: AppTheme.textPrimary, size: 20)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFabStack() {
    return SizedBox(
      width: 56, height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: FloatingActionButton(
              heroTag: 'main_expandable_fab',
              backgroundColor: AppTheme.bg3,
              foregroundColor: AppTheme.accent,
              onPressed: () => setState(() {
                _isOpen = !_isOpen;
                if (!_isOpen) {
                  _showSettings = false;
                  _isResizing = false;
                }
                _notifyState();
              }),
              tooltip: widget.lang.get('quick_actions_title'),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(_isOpen ? Icons.close : widget.mainIcon, key: ValueKey(_isOpen)),
              ),
            ),
          ),
          if (_isOpen)
            Positioned(
              bottom: -6, right: -6,
              child: Tooltip(
                message: widget.lang.get('quick_actions_options'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _showSettings = !_showSettings),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: _showSettings ? AppTheme.accent : AppTheme.bg4,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.border, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                    ),
                    child: Icon(Icons.tune, size: 14, color: _showSettings ? AppTheme.bg0 : AppTheme.textPrimary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}