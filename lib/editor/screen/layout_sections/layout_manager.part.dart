part of '../editor_screen.dart';

/// Entry point / Gerenciador unificado que reúne todos os submódulos de layout
/// e monta o corpo da interface visual do editor.
mixin _LayoutSections on 
    _MapEditorScreenStateBase, 
    _DialogHandlersSection,
    _PanelWrappersSection, 
    _CanvasAreaSection, 
    _MobileControlsSection {

  /// Constrói o corpo principal em escala 1:1 física nativa.
  /// Removemos completamente qualquer OverflowBox ou Transform.scale artificial,
  /// garantindo que 100% dos cliques e toques caiam com precisão cirúrgica exatamente onde o dedo encosta.
  Widget buildEditorScaffoldBody() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCanvasArea(),
        _buildTopBarWrapper(),
        _buildSideBarWrapper(),
        _buildPropertiesWrapper(),
        _buildMobileControlsOverlay(),
      ],
    );
  }
}