part of 'editor_screen.dart';

mixin _ProvinceDrawingLogic on _MapEditorScreenStateBase, _SelectionLogic {

  void _tapCreateProvincePoint(Offset localPosition, MapPainter painter) {
    final world = _applySnapping(painter.screenToWorld(localPosition));

    if (_pointsInProgress.length >= 3) {
      final pLast = _pointsInProgress.last; 
      final pNew = world;

      int? bridgeIndex;
      for (int i = 0; i < _pointsInProgress.length - 2; i++) {
        final pA = _pointsInProgress[i];
        final pB = _pointsInProgress[i + 1];

        if ((pA - pNew).distanceSquared < 1.0 && (pB - pLast).distanceSquared < 1.0) {
          bridgeIndex = i;
          break;
        }
      }

      if (bridgeIndex != null) {
        final pA = _pointsInProgress[bridgeIndex];
        final pB = _pointsInProgress[bridgeIndex + 1];

        if ((pA.dx - pB.dx).abs() > 0.01 && (pA.dy - pB.dy).abs() > 0.01) {
          _handleIslandCorrection(bridgeIndex, pA, pB, pNew);
          return;
        }
      }
    }

    setState(() {
      _pointsInProgress.add(world);
    });
  }

  Future<void> _handleIslandCorrection(int bridgeIndex, Offset pA, Offset pB, Offset pNew) async {
    final originalList = List<Offset>.of(_pointsInProgress);

    List<Offset> buildPreview(int pathChoice) {
      final pMid = (pathChoice == 1)
          ? Offset(pB.dx, pA.dy)
          : Offset(pA.dx, pB.dy);
          
      final preview = List<Offset>.of(originalList);
      preview.insert(bridgeIndex + 1, pMid);
      preview.add(pMid);
      preview.add(pA);
      return preview;
    }

    int currentPath = 1;
    final size = MediaQuery.of(context).size;
    _islandCorrectionPosition.value = Offset(math.max(16.0, (size.width - 480) / 2), 80);

    setState(() {
      _pointsInProgress.clear();
      _pointsInProgress.addAll(buildPreview(currentPath));

      _islandCorrectionCurrentPath = currentPath;
      _onIslandCorrectionPathChanged = (newPath) {
        setState(() {
          _islandCorrectionCurrentPath = newPath;
          _pointsInProgress.clear();
          _pointsInProgress.addAll(buildPreview(newPath));
        });
      };
    });

    _islandCorrectionCompleter = Completer<IslandCorrectionResult>();
    final result = await _islandCorrectionCompleter!.future;

    setState(() {
      _islandCorrectionCompleter = null;
      _onIslandCorrectionPathChanged = null;
    });

    if (result == IslandCorrectionResult.confirm) {
      // preview mantido
    } else if (result == IslandCorrectionResult.ignore) {
      setState(() {
        _pointsInProgress.clear();
        _pointsInProgress.addAll(originalList);
        _pointsInProgress.add(pNew);
      });
    } else {
      setState(() {
        _pointsInProgress.clear();
        _pointsInProgress.addAll(originalList);
      });
    }
  }

  Future<void> _commitCurrentProvince() async {
    if (_pointsInProgress.length < 3) return;
    final xs = _pointsInProgress.map((p) => p.dx.round()).toList();
    final ys = _pointsInProgress.map((p) => p.dy.round()).toList();

    final tempBbox = BoundingBox.fromPoints(Int32List.fromList(xs), Int32List.fromList(ys));
    final overlapping = _mapRepo.mapData.provinces.where((p) => p.boundingBox.intersects(tempBbox)).toList();

    Set<int> selectedToClip = {};
    if (overlapping.isNotEmpty) {
      final decision = await showOverlapConfirmDialog(context, _lang, overlapping);
      if (decision == null) return;
      selectedToClip = decision;
    }

    final province = await _mapRepo.commitProvince(
      xs: xs, ys: ys, colorValue: _pendingProvinceColor, clipTargets: selectedToClip,
      enableSnapping: _enableSnapping.value,
    );

    setState(() {
      _pointsInProgress.clear();
      _selectedProvinceIds = {province.id};
      _pendingProvinceColor = randomProvinceColorValue();
    });
  }
}