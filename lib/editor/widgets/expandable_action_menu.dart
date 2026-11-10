import 'package:flutter/material.dart';
import '../../core/language_controller.dart';
import '../../theme/app_theme.dart';

// O elo corrigido para a pasta correta:
part 'expandable_menu/settings_pill.part.dart';
part 'expandable_menu/menu_layout_builder.part.dart';

enum ActionExpandDirection { up, right, down, left }

class ExpandableActionMenu extends StatefulWidget {
  final List<Widget> actions;
  final IconData mainIcon;
  final ValueChanged<Offset> onPositionChanged;
  final ValueChanged<bool> onDragStateChanged;
  final void Function(bool isOpen, ActionExpandDirection direction) onStateChanged;
  final EdgeInsets safeArea;
  final LanguageController lang;
  final ActionExpandDirection direction;

  const ExpandableActionMenu({
    super.key,
    required this.actions,
    required this.onPositionChanged,
    required this.onDragStateChanged,
    required this.onStateChanged,
    required this.safeArea,
    required this.lang,
    required this.direction,
    this.mainIcon = Icons.handyman_outlined,
  });

  @override
  State<ExpandableActionMenu> createState() => _ExpandableActionMenuState();
}

abstract class _ExpandableActionMenuStateBase extends State<ExpandableActionMenu> {
  bool _isOpen = false;
  bool _showSettings = false;
  bool _isResizing = false;
  double _scale = 1.0;

  void _notifyState() {
    widget.onStateChanged(_isOpen, widget.direction);
  }

  void _cycleDirection() {
    ActionExpandDirection newDir;
    switch (widget.direction) {
      case ActionExpandDirection.left:
        newDir = ActionExpandDirection.up;
        break;
      case ActionExpandDirection.up:
        newDir = ActionExpandDirection.right;
        break;
      case ActionExpandDirection.right:
        newDir = ActionExpandDirection.down;
        break;
      case ActionExpandDirection.down:
        newDir = ActionExpandDirection.left;
        break;
    }
    widget.onStateChanged(_isOpen, newDir);
  }

  IconData _getDirectionIcon() {
    switch (widget.direction) {
      case ActionExpandDirection.up:
        return Icons.arrow_upward;
      case ActionExpandDirection.right:
        return Icons.arrow_forward;
      case ActionExpandDirection.down:
        return Icons.arrow_downward;
      case ActionExpandDirection.left:
        return Icons.arrow_back;
    }
  }

  String _getDirectionName() {
    switch (widget.direction) {
      case ActionExpandDirection.up:
        return widget.lang.get('direction_up');
      case ActionExpandDirection.right:
        return widget.lang.get('direction_right');
      case ActionExpandDirection.down:
        return widget.lang.get('direction_down');
      case ActionExpandDirection.left:
        return widget.lang.get('direction_left');
    }
  }
}

class _ExpandableActionMenuState extends _ExpandableActionMenuStateBase
    with _SettingsPillBuilder, _MenuLayoutBuilder {
      
  @override
  Widget build(BuildContext context) {
    return _buildMenuLayout(context);
  }
}