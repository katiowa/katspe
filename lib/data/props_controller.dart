import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../engine/engine_storage.dart';
import '../models/prop_model.dart';

class PropsController extends ChangeNotifier {
  final EngineStorageManager storage;
  final VoidCallback? onActionRecorded;

  List<PropModel> _props = [];
  final Map<String, ui.Image> _imagesCache = {};
  
  final List<List<PropModel>> _undoStack = [];
  final List<List<PropModel>> _redoStack = [];

  bool _isLoading = false;

  PropsController({required this.storage, this.onActionRecorded});

  List<PropModel> get props => List.unmodifiable(_props);
  bool get isLoading => _isLoading;

  ui.Image? getImage(String propId) => _imagesCache[propId];

  void recordSnapshot() {
    _undoStack.add(_props.map((p) => p.copyWith()).toList());
    _redoStack.clear();
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    onActionRecorded?.call();
  }

  bool undo() {
    if (_undoStack.isEmpty) return false;
    _redoStack.add(_props.map((p) => p.copyWith()).toList());
    _props = _undoStack.removeLast();
    notifyListeners();
    _saveManifest();
    return true;
  }

  bool redo() {
    if (_redoStack.isEmpty) return false;
    _undoStack.add(_props.map((p) => p.copyWith()).toList());
    _props = _redoStack.removeLast();
    notifyListeners();
    _saveManifest();
    return true;
  }

  Future<void> loadAll() async {
    _isLoading = true;
    notifyListeners();

    try {
      final manifest = await storage.loadPropsManifest();
      if (manifest == null) {
        _props = [];
        return;
      }

      _props = manifest.map((m) => PropModel.fromJson(m)).toList();
      final imgDir = await storage.propsImagesDir;

      for (final p in _props) {
        final file = File('${imgDir.path}${Platform.pathSeparator}${p.imageFileName}');
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          _imagesCache[p.id] = frame.image;
        }
      }
    } catch (e) {
      debugPrint("Failed to load props: $e");
      _props = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addProp(String sourcePath, ui.Offset centerWorldPos) async {
    _isLoading = true;
    notifyListeners();

    try {
      final fileName = await storage.savePropImage(sourcePath);
      if (fileName == null) return;

      final imgDir = await storage.propsImagesDir;
      final file = File('${imgDir.path}${Platform.pathSeparator}$fileName');
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;

      final String newId = 'prop_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
      _imagesCache[newId] = img;

      final double w = img.width.toDouble();
      final double h = img.height.toDouble();
      
      final corners = [
        ui.Offset(centerWorldPos.dx - w/2, centerWorldPos.dy - h/2), // TL
        ui.Offset(centerWorldPos.dx + w/2, centerWorldPos.dy - h/2), // TR
        ui.Offset(centerWorldPos.dx + w/2, centerWorldPos.dy + h/2), // BR
        ui.Offset(centerWorldPos.dx - w/2, centerWorldPos.dy + h/2), // BL
      ];

      final newProp = PropModel(
        id: newId,
        name: 'Prop ${_props.length + 1}',
        imageFileName: fileName,
        corners: corners,
        opacity: 1.0,
        rotation: 0.0,
        mesh: PropModel.generateMesh(corners, 1, 1.0),
      );

      recordSnapshot();
      _props.add(newProp);
      await _saveManifest();
      
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateProp(PropModel updatedProp, {bool saveToDisk = true}) {
    final idx = _props.indexWhere((p) => p.id == updatedProp.id);
    if (idx != -1) {
      _props[idx] = updatedProp;
      notifyListeners();
      if (saveToDisk) {
        _saveManifest();
      }
    }
  }

  void bringToFront(String propId) {
    final idx = _props.indexWhere((p) => p.id == propId);
    if (idx != -1 && idx < _props.length - 1) {
      recordSnapshot();
      final p = _props.removeAt(idx);
      _props.add(p);
      notifyListeners();
      _saveManifest();
    }
  }

  Future<void> removeProp(String propId) async {
    final idx = _props.indexWhere((p) => p.id == propId);
    if (idx != -1) {
      recordSnapshot();
      final p = _props.removeAt(idx);
      _imagesCache[p.id]?.dispose();
      _imagesCache.remove(p.id);
      
      notifyListeners();
      await _saveManifest();
      await storage.deletePropImage(p.imageFileName);
    }
  }

  void clearAll() {
    _props.clear();
    for (final img in _imagesCache.values) {
      img.dispose();
    }
    _imagesCache.clear();
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }

  Future<void> _saveManifest() async {
    final manifest = _props.map((p) => p.toJson()).toList();
    await storage.savePropsManifest(manifest);
  }

  @override
  void dispose() {
    for (final img in _imagesCache.values) {
      img.dispose();
    }
    _imagesCache.clear();
    super.dispose();
  }
}