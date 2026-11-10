part of '../map_repository.dart';

enum HistoryDomain { map, poi, prop }

mixin _HistoryManager on ChangeNotifier {
  final List<HistoryDomain> _globalUndo = [];
  final List<HistoryDomain> _globalRedo = [];

  final List<EngineMapData> _mapUndo = [];
  final List<EngineMapData> _mapRedo = [];

  bool get canUndo => _globalUndo.isNotEmpty;
  bool get canRedo => _globalRedo.isNotEmpty;

  void _pushMapHistory(EngineMapData data) {
    _mapUndo.add(data);
    _globalUndo.add(HistoryDomain.map);
    _mapRedo.clear();
    _globalRedo.clear();
    
    if (_globalUndo.length > 50) {
      final dropped = _globalUndo.removeAt(0);
      if (dropped == HistoryDomain.map) _mapUndo.removeAt(0);
    }
  }

  void markPoiAction() {
    _globalUndo.add(HistoryDomain.poi);
    _globalRedo.clear();
    _mapRedo.clear(); 
    
    if (_globalUndo.length > 50) {
      final dropped = _globalUndo.removeAt(0);
      if (dropped == HistoryDomain.map) _mapUndo.removeAt(0);
    }
    notifyListeners();
  }

  void markPropAction() {
    _globalUndo.add(HistoryDomain.prop);
    _globalRedo.clear();
    _mapRedo.clear();
    
    if (_globalUndo.length > 50) {
      final dropped = _globalUndo.removeAt(0);
      if (dropped == HistoryDomain.map) _mapUndo.removeAt(0);
    }
    notifyListeners();
  }

  void _clearHistory() {
    _globalUndo.clear();
    _globalRedo.clear();
    _mapUndo.clear();
    _mapRedo.clear();
  }

  EngineMapData get _currentMapData => (this as MapRepository)._mapData;
  set _currentMapData(EngineMapData value) => (this as MapRepository)._mapData = value;

  Future<HistoryDomain?> undo() async {
    if (!canUndo) return null;
    
    final domain = _globalUndo.removeLast();
    _globalRedo.add(domain);

    if (domain == HistoryDomain.map) {
      _mapRedo.add(_currentMapData);
      _currentMapData = _mapUndo.removeLast();
      (this as MapRepository)._rebuildSpatialIndex();
      notifyListeners();
      await (this as MapRepository).storage.saveMapCache(_currentMapData);
      return HistoryDomain.map;
    } else if (domain == HistoryDomain.poi) {
      final session = (this as MapRepository).activeSession;
      if (session != null) {
        await session.invoke('poi_undo');
      }
      notifyListeners();
      return HistoryDomain.poi;
    } else {
      notifyListeners();
      return HistoryDomain.prop;
    }
  }

  Future<HistoryDomain?> redo() async {
    if (!canRedo) return null;
    
    final domain = _globalRedo.removeLast();
    _globalUndo.add(domain);

    if (domain == HistoryDomain.map) {
      _mapUndo.add(_currentMapData);
      _currentMapData = _mapRedo.removeLast();
      (this as MapRepository)._rebuildSpatialIndex();
      notifyListeners();
      await (this as MapRepository).storage.saveMapCache(_currentMapData);
      return HistoryDomain.map;
    } else if (domain == HistoryDomain.poi) {
      final session = (this as MapRepository).activeSession;
      if (session != null) {
        await session.invoke('poi_redo');
      }
      notifyListeners();
      return HistoryDomain.poi;
    } else {
      notifyListeners();
      return HistoryDomain.prop;
    }
  }
}