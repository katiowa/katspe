import 'package:flutter/material.dart';

enum DockPosition { none, left, right, top, bottom }

/// Guarda a verdade absoluta sobre onde um painel está, seu tamanho e status.
class PanelState {
  final String id;
  final Rect rect;
  final DockPosition dock;
  final bool isCollapsed;
  final bool isEditMode;
  final bool isActivelyDragging;

  /// Posição/fatia que este painel ocupa se dividir a borda com outros painéis
  final int slotIndex;

  /// Tamanhos originais antes de esticar nas bordas
  final double floatingWidth;
  final double floatingHeight;

  const PanelState({
    required this.id,
    required this.rect,
    this.dock = DockPosition.none,
    this.isCollapsed = false,
    this.isEditMode = false,
    this.isActivelyDragging = false,
    this.slotIndex = 0,
    this.floatingWidth = 300.0,
    this.floatingHeight = 400.0,
  });

  PanelState copyWith({
    Rect? rect,
    DockPosition? dock,
    bool? isCollapsed,
    bool? isEditMode,
    bool? isActivelyDragging,
    int? slotIndex,
    double? floatingWidth,
    double? floatingHeight,
  }) {
    return PanelState(
      id: id,
      rect: rect ?? this.rect,
      dock: dock ?? this.dock,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      isEditMode: isEditMode ?? this.isEditMode,
      isActivelyDragging: isActivelyDragging ?? this.isActivelyDragging,
      slotIndex: slotIndex ?? this.slotIndex,
      floatingWidth: floatingWidth ?? this.floatingWidth,
      floatingHeight: floatingHeight ?? this.floatingHeight,
    );
  }
}