import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dialogs/project_dashboard_dialog.dart';

import '../../api/lua/lua_converter_session.dart';
import '../../api/lua/lua_value_utils.dart';
import '../../core/app_preferences.dart';
import '../../core/language_controller.dart';
import '../../core/engine_context.dart';
import '../../data/background_image_controller.dart';
import '../../data/map_repository.dart';
import '../../data/props_controller.dart';
import '../../engine/engine_config.dart';
import '../../io/export_manager.dart';
import '../../models/map_marker.dart';
import '../../models/province.dart';
import '../../models/prop_model.dart';
import '../dialogs/overlap_confirm_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../dialogs/island_correction_dialog.dart';
import '../editor_tool.dart';
import '../painter/camera_transform.dart';
import '../painter/map_painter.dart';
import '../painter/map_painter_cache.dart';
import '../point_edit_controller.dart';
import '../widgets/point_action_menu.dart';
import '../widgets/properties_panel.dart';
import '../widgets/side_toolbar.dart';
import '../widgets/top_bar.dart';
import '../../render/lua_panel.dart';
import '../../theme/app_theme.dart';

import '../layout/panel_layout_controller.dart';
import '../layout/panel_state.dart';
import '../widgets/layout/draggable_panel_wrapper.dart';
import '../widgets/expandable_action_menu.dart';

part 'workspace_logic.part.dart';
part 'selection_logic.part.dart';
part 'poi_placement_logic.part.dart';
part 'point_manipulation_logic.part.dart';
part 'province_drawing_logic.part.dart';
part 'core_interaction_logic.part.dart';
part 'keyboard_shortcuts.part.dart';
part 'gesture_controller.part.dart';
part 'layout_sections/dialog_handlers_section.part.dart';
part 'layout_sections/panel_wrappers_section.part.dart';
part 'layout_sections/canvas_area_section.part.dart';
part 'layout_sections/mobile_controls_section.part.dart';
part 'layout_sections/layout_manager.part.dart';

class MapEditorScreen extends StatefulWidget {
  const MapEditorScreen({super.key});

  @override
  State<MapEditorScreen> createState() => _MapEditorScreenState();
}

abstract class _MapEditorScreenStateBase extends State<MapEditorScreen> {
  final MapEngineConfig _config = const MapEngineConfig();
  late final MapRepository _mapRepo = MapRepository(config: _config);
  final BackgroundImageController _background = BackgroundImageController();
  final AppPreferences _prefs = AppPreferences();
  late final LanguageController _lang = LanguageController(preferences: _prefs);
  
  late final PropsController _propsController = PropsController(
    storage: _mapRepo.storage,
    onActionRecorded: () => _mapRepo.markPropAction(),
  );

  final PanelLayoutController _panelController = PanelLayoutController();

  final GlobalKey _canvasKey = GlobalKey();
  final FocusNode _canvasFocusNode = FocusNode(); 
  
  EditorTool _tool = EditorTool.select;

  final MapPainterCache _painterCache = MapPainterCache();

  final ValueNotifier<Offset> _panOffset = ValueNotifier(Offset.zero);
  final ValueNotifier<double> _zoom = ValueNotifier(1.0);
  double _baseZoomForPinch = 1.0;

  final ValueNotifier<double> _uiScale = ValueNotifier(1.0);

  final ValueNotifier<bool> _enableFrustumCulling = ValueNotifier(true);
  final ValueNotifier<double> _cullingMargin = ValueNotifier(0.5);
  final ValueNotifier<bool> _enableSnapping = ValueNotifier(true);
  final ValueNotifier<bool> _showAllPoints = ValueNotifier(false);

  final ValueNotifier<bool> _showProvinces = ValueNotifier(true);
  final ValueNotifier<bool> _showXRay = ValueNotifier(false);
  final ValueNotifier<bool> _showBg = ValueNotifier(true);

  final ValueNotifier<Set<String>> _hiddenPoiCategories = ValueNotifier<Set<String>>({});

  final ValueNotifier<Offset> _provinceDragDelta = ValueNotifier(Offset.zero);
  final List<Offset> _movingVerticesCache = [];

  final ValueNotifier<bool> _isShiftActive = ValueNotifier(false);
  final ValueNotifier<bool> _isDeselectModeActive = ValueNotifier(false);
  
  final ValueNotifier<Offset?> _boxSelectStart = ValueNotifier(null);
  final ValueNotifier<Offset?> _boxSelectEnd = ValueNotifier(null);

  Set<int> _selectedProvinceIds = {};
  ProvinceModel? _clipboardProvince;
  
  final List<Offset> _pointsInProgress = [];
  int _pendingProvinceColor = randomProvinceColorValue();

  List<SelectedPointRef> _selectedPoints = [];
  Set<(int, int)> _fastSelectedPoints = {};
  
  List<SelectedPointRef> _currentHitPoints = [];
  int _currentHitIndex = 0;
  final Map<String, Offset> _originalPointCoords = {};
  
  final List<MapEntry<int, List<int>>> _validEdgesToSubdivide = [];

  final ValueNotifier<SelectedPointRef?> _draggingPoint = ValueNotifier(null);
  final ValueNotifier<Offset?> _dragWorldPosition = ValueNotifier(null);

  Offset? _dragMouseStartWorld;
  DateTime _lastDragEndTime = DateTime.fromMillisecondsSinceEpoch(0);

  String? _selectedPropId;
  int? _draggedPropCornerIndex;
  List<Offset>? _propOriginalCorners;
  List<Offset>? _propOriginalMesh;

  double? _poiDragStartWorldX;
  double? _poiDragStartWorldY;
  Offset? _poiDragStartFocal;

  List<MapMarker> _markers = [];
  MarkerSpatialIndex? _markerIndex;
  List<Map<String, dynamic>> _poiCategories = [];
  String? _activePoiCategory;

  Map<String, dynamic>? _pendingPoiEditorContext;

  ExportOptions _exportOptions = const ExportOptions();
  bool _isExporting = false;
  List<String> _lastExportedFiles = [];

  Offset _fabPosition = const Offset(24, 24);
  bool _isDraggingFab = false;
  bool _isFabOpen = false;
  ActionExpandDirection _fabDirection = ActionExpandDirection.left;

  Completer<IslandCorrectionResult>? _islandCorrectionCompleter;
  final ValueNotifier<Offset> _islandCorrectionPosition = ValueNotifier(const Offset(100, 100));
  int _islandCorrectionCurrentPath = 1;
  void Function(int)? _onIslandCorrectionPathChanged;

  bool get _isEditingText {
    if (_pendingPoiEditorContext != null) return true;
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || primary == _canvasFocusNode) return false;
    final ctx = primary.context;
    if (ctx != null) {
      if (ctx.widget is EditableText || ctx.findAncestorWidgetOfExactType<EditableText>() != null) {
        return true;
      }
    }
    return false;
  }

  void _applyUiScale() {
    if (!mounted) return;
    final scale = _uiScale.value;
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 750;
    
    final double baseTop = isNarrow ? 44.0 : 56.0;
    final double baseSide = isNarrow ? 46.0 : 56.0;
    final double baseProp = isNarrow ? 250.0 : 300.0;

    _panelController.updatePanelSizeDirect('topbar', height: baseTop * scale);
    _panelController.updatePanelSizeDirect('sidebar', width: baseSide * scale);
    _panelController.updatePanelSizeDirect('properties', width: baseProp * scale);
  }
}

class _MapEditorScreenState extends _MapEditorScreenStateBase
    with
        _SelectionLogic,
        _PoiPlacementLogic,
        _PointManipulationLogic,
        _ProvinceDrawingLogic,
        _CoreInteractionLogic,
        _WorkspaceLogic,
        _KeyboardShortcuts,
        _GestureController,
        _DialogHandlersSection,
        _PanelWrappersSection,
        _CanvasAreaSection,
        _MobileControlsSection,
        _LayoutSections {
  
  @override
  void initState() {
    super.initState();
    _mapRepo.addListener(_onChanged);
    _background.addListener(_onChanged);
    _lang.addListener(_onChanged);
    
    _uiScale.addListener(_applyUiScale);

    _initializeEngine();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Lê a largura exata do frame ativo (funciona perfeitamente com o DevicePreview)
      final screenWidth = MediaQuery.of(context).size.width;
      final isNarrow = screenWidth < 750;
      
      final double topBarHeight = isNarrow ? 44.0 : 56.0;
      final double sideBarWidth = isNarrow ? 46.0 : 56.0;
      final double propertiesWidth = isNarrow ? 250.0 : 300.0;

      // TopBar e Toolbar (esquerda) nascem sempre abertas para uso imediato
      _panelController.initPanel('topbar', Rect.fromLTWH(0, 0, 800, topBarHeight), initialDock: DockPosition.top, isCollapsed: false);
      _panelController.initPanel('sidebar', Rect.fromLTWH(0, topBarHeight, sideBarWidth, 320), initialDock: DockPosition.left, isCollapsed: false);
      
      // Painel de Propriedades (direita) nasce fechado se a tela for estreita (mobile), e aberto se for larga (PC)
      _panelController.initPanel('properties', Rect.fromLTWH(500, topBarHeight, propertiesWidth, 500), initialDock: DockPosition.right, isCollapsed: isNarrow);
      
      _applyUiScale();
    });
  }

  @override
  void dispose() {
    unawaited(_mapRepo.storage.flushMapCache());
    _uiScale.removeListener(_applyUiScale);
    _mapRepo.removeListener(_onChanged);
    _background.removeListener(_onChanged);
    _lang.removeListener(_onChanged);
    _propsController.dispose();
    
    _panOffset.dispose();
    _zoom.dispose();
    _uiScale.dispose();
    _enableFrustumCulling.dispose();
    _cullingMargin.dispose();
    _enableSnapping.dispose();
    _showAllPoints.dispose();
    _showProvinces.dispose();
    _showXRay.dispose();
    _showBg.dispose();
    _hiddenPoiCategories.dispose();
    _isShiftActive.dispose();
    _isDeselectModeActive.dispose();
    _draggingPoint.dispose();
    _dragWorldPosition.dispose();
    _boxSelectStart.dispose();
    _boxSelectEnd.dispose();
    _provinceDragDelta.dispose();
    _islandCorrectionPosition.dispose();
    _lang.dispose(); 
    _canvasFocusNode.dispose();
    _panelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _canvasFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        body: buildEditorScaffoldBody(),
      ),
    );
  }
}