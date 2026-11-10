import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'panel_state.dart';

class PanelLayoutController extends ChangeNotifier {
  final Map<String, PanelState> _panels = {};

  static const double snapThreshold = 20.0;

  PanelState getPanel(String id) {
    return _panels[id] ?? PanelState(id: id, rect: Rect.zero);
  }

  void initPanel(String id, Rect initialRect, {DockPosition initialDock = DockPosition.none, int slotIndex = 0, bool isCollapsed = false}) {
    if (!_panels.containsKey(id)) {
      _panels[id] = PanelState(
        id: id,
        rect: initialRect,
        dock: initialDock,
        slotIndex: slotIndex,
        isCollapsed: isCollapsed,
        floatingWidth: initialRect.width > 600 ? 400 : initialRect.width,
        floatingHeight: initialRect.height > 600 ? 300 : initialRect.height,
      );
      notifyListeners();
    }
  }

  void updatePanelSizeDirect(String id, {double? width, double? height}) {
    final state = getPanel(id);
    if (_panels.containsKey(id)) {
      final w = width ?? state.rect.width;
      final h = height ?? state.rect.height;
      _panels[id] = state.copyWith(
        rect: Rect.fromLTWH(state.rect.left, state.rect.top, w, h),
      );
      notifyListeners();
    }
  }

  void toggleEditMode(String id) {
    final state = getPanel(id);
    if (!state.isCollapsed) {
      _panels[id] = state.copyWith(isEditMode: !state.isEditMode);
      notifyListeners();
    }
  }

  void disableEditMode(String id, Size screenSize) {
    final state = getPanel(id);
    if (state.isEditMode) {
      final targetRect = getTargetRect(id, screenSize);
      _panels[id] = state.copyWith(
        rect: targetRect,
        isEditMode: false,
        isActivelyDragging: false,
      );
      notifyListeners();
    }
  }

  void toggleCollapse(String id) {
    final state = getPanel(id);
    if (state.dock != DockPosition.none) {
      _panels[id] = state.copyWith(isCollapsed: !state.isCollapsed);
      notifyListeners();
    }
  }

  void toggleOrientation(String id, Size screenSize) {
    final state = getPanel(id);
    DockPosition newDock = state.dock;
    double newW = state.floatingHeight;
    double newH = state.floatingWidth;

    if (state.dock == DockPosition.top) {
      newDock = DockPosition.left;
    } else if (state.dock == DockPosition.bottom) {
      newDock = DockPosition.right;
    } else if (state.dock == DockPosition.left) {
      newDock = DockPosition.top;
    } else if (state.dock == DockPosition.right) {
      newDock = DockPosition.bottom;
    }

    _panels[id] = state.copyWith(
      dock: newDock,
      floatingWidth: newW,
      floatingHeight: newH,
      rect: Rect.fromLTWH(state.rect.left, state.rect.top, newW, newH),
    );
    notifyListeners();
  }

  void updatePanelPosition(String id, Offset delta, Size screenSize) {
    final state = getPanel(id);

    double currentW = state.rect.width;
    double currentH = state.rect.height;

    if (state.dock != DockPosition.none) {
      currentW = state.floatingWidth;
      currentH = state.floatingHeight;
    }

    final maxW = math.max(40.0, screenSize.width);
    final maxH = math.max(40.0, screenSize.height);
    final w = currentW.clamp(40.0, maxW);
    final h = currentH.clamp(40.0, maxH);

    final maxL = math.max(0.0, screenSize.width - w);
    final maxT = math.max(0.0, screenSize.height - h);

    final shifted = state.rect.shift(delta);
    final newLeft = shifted.left.clamp(0.0, maxL);
    final newTop = shifted.top.clamp(0.0, maxT);
    final newRect = Rect.fromLTWH(newLeft, newTop, w, h);

    DockPosition newDock = DockPosition.none;
    int newSlot = 0;

    if (newTop <= snapThreshold) {
      newDock = DockPosition.top;
      final otherPanels = _panels.values.where((p) => p.id != id && p.dock == DockPosition.top).toList();
      if (otherPanels.isNotEmpty) {
        newSlot = newLeft < (screenSize.width / 2) ? 0 : 1;
      }
    } else if (newTop >= (screenSize.height - h - snapThreshold)) {
      newDock = DockPosition.bottom;
      final otherPanels = _panels.values.where((p) => p.id != id && p.dock == DockPosition.bottom).toList();
      if (otherPanels.isNotEmpty) {
        newSlot = newLeft < (screenSize.width / 2) ? 0 : 1;
      }
    } else if (newLeft <= snapThreshold) {
      newDock = DockPosition.left;
      final otherPanels = _panels.values.where((p) => p.id != id && p.dock == DockPosition.left).toList();
      if (otherPanels.isNotEmpty) {
        newSlot = newTop < (screenSize.height / 2) ? 0 : 1;
      }
    } else if (newLeft >= (screenSize.width - w - snapThreshold)) {
      newDock = DockPosition.right;
      final otherPanels = _panels.values.where((p) => p.id != id && p.dock == DockPosition.right).toList();
      if (otherPanels.isNotEmpty) {
        newSlot = newTop < (screenSize.height / 2) ? 0 : 1;
      }
    }

    _panels[id] = state.copyWith(
      rect: newRect,
      dock: newDock,
      slotIndex: newSlot,
      isActivelyDragging: true,
      isCollapsed: newDock == DockPosition.none ? false : state.isCollapsed,
    );
    notifyListeners();
  }

  void endDrag(String id) {
    final state = getPanel(id);
    _panels[id] = state.copyWith(isActivelyDragging: false);
    notifyListeners();
  }

  void updatePanelSize(String id, Offset delta) {
    final state = getPanel(id);
    double w = state.rect.width;
    double h = state.rect.height;

    if (state.dock == DockPosition.top) {
      h = (h + delta.dy).clamp(36.0, 600.0);
    } else if (state.dock == DockPosition.bottom) {
      h = (h - delta.dy).clamp(36.0, 600.0);
    } else if (state.dock == DockPosition.left) {
      w = (w + delta.dx).clamp(40.0, 800.0);
    } else if (state.dock == DockPosition.right) {
      w = (w - delta.dx).clamp(40.0, 800.0);
    } else {
      w = (w + delta.dx).clamp(40.0, 1200.0);
      h = (h + delta.dy).clamp(40.0, 1000.0);
    }

    _panels[id] = state.copyWith(
      rect: Rect.fromLTWH(state.rect.left, state.rect.top, w, h),
      floatingWidth: state.dock == DockPosition.none ? w : state.floatingWidth,
      floatingHeight: state.dock == DockPosition.none ? h : state.floatingHeight,
      isActivelyDragging: true,
    );
    notifyListeners();
  }

  EdgeInsets getSafeArea() {
    double top = 0, bottom = 0, left = 0, right = 0;
    for (final p in _panels.values) {
      if (p.dock == DockPosition.none || p.isCollapsed) {
        continue;
      }
      if (p.dock == DockPosition.top && p.rect.height > top) {
        top = p.rect.height;
      }
      if (p.dock == DockPosition.bottom && p.rect.height > bottom) {
        bottom = p.rect.height;
      }
      if (p.dock == DockPosition.left && p.rect.width > left) {
        left = p.rect.width;
      }
      if (p.dock == DockPosition.right && p.rect.width > right) {
        right = p.rect.width;
      }
    }
    return EdgeInsets.fromLTRB(left, top, right, bottom);
  }

  Rect getTargetRect(String id, Size screenSize) {
    double topBarH = 0;
    double bottomBarH = 0;

    for (final p in _panels.values) {
      if (p.dock == DockPosition.none || p.isCollapsed) {
        continue;
      }
      if (p.dock == DockPosition.top && p.rect.height > topBarH) {
        topBarH = p.rect.height;
      }
      if (p.dock == DockPosition.bottom && p.rect.height > bottomBarH) {
        bottomBarH = p.rect.height;
      }
    }

    final state = getPanel(id);

    final siblings = _panels.values.where((p) => p.dock == state.dock).toList();
    siblings.sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    final siblingCount = math.max(1, siblings.length);
    final myIndex = math.max(0, siblings.indexWhere((p) => p.id == id));

    if (state.dock == DockPosition.top) {
      final slotWidth = screenSize.width / siblingCount;
      final h = state.isCollapsed ? 0.0 : state.rect.height.clamp(36.0, screenSize.height * 0.8);
      return Rect.fromLTWH(myIndex * slotWidth, 0, slotWidth, h);
    }

    if (state.dock == DockPosition.bottom) {
      final slotWidth = screenSize.width / siblingCount;
      final h = state.isCollapsed ? 0.0 : state.rect.height.clamp(36.0, screenSize.height * 0.8);
      return Rect.fromLTWH(myIndex * slotWidth, screenSize.height - h, slotWidth, h);
    }

    final sideH = math.max(0.0, screenSize.height - topBarH - bottomBarH);
    final slotHeight = sideH / siblingCount;

    if (state.dock == DockPosition.left) {
      final w = state.isCollapsed ? 0.0 : state.rect.width.clamp(40.0, screenSize.width * 0.7);
      return Rect.fromLTWH(0, topBarH + (myIndex * slotHeight), w, slotHeight);
    }

    // Painel direito: trava para colar EXATAMENTE na borda direita da tela física
    if (state.dock == DockPosition.right) {
      final w = state.isCollapsed ? 0.0 : state.rect.width.clamp(40.0, screenSize.width * 0.7);
      return Rect.fromLTWH(screenSize.width - w, topBarH + (myIndex * slotHeight), w, slotHeight);
    }

    final maxW = math.max(40.0, screenSize.width);
    final maxH = math.max(40.0, screenSize.height);
    final w = state.rect.width.clamp(40.0, maxW);
    final h = state.rect.height.clamp(40.0, maxH);

    final maxL = math.max(0.0, screenSize.width - w);
    final maxT = math.max(0.0, screenSize.height - h);
    final l = state.rect.left.clamp(0.0, maxL);
    final t = state.rect.top.clamp(0.0, maxT);

    return Rect.fromLTWH(l, t, w, h);
  }
}