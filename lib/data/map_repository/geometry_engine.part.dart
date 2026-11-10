part of '../map_repository.dart';

const bool debugMerge = true;

void _mergeLog(String msg) {
  if (debugMerge) debugPrint('[MERGE_DEBUG] $msg');
}

class ClipResult {
  final int id;
  final ProvinceModel? updatedProv;
  ClipResult(this.id, this.updatedProv);
}

class MergeContoursData {
  final int id;
  final int colorValue;
  final int geometryVersion;
  final List<ui.Offset> baseContour;
  final List<List<ui.Offset>> secondaries;
  final int islandCount;

  MergeContoursData(this.id, this.colorValue, this.geometryVersion, this.baseContour, this.secondaries, this.islandCount);
}

mixin _GeometryEngine {}

class _GeometryWorker {
  
  static double polygonAreaSigned(List<ui.Offset> points) {
    double area = 0.0;
    for (int i = 0; i < points.length; i++) {
      int j = (i + 1) % points.length;
      area += points[i].dx * points[j].dy - points[j].dx * points[i].dy;
    }
    return area / 2.0;
  }

  static ui.Offset? lineIntersection(ui.Offset p1, ui.Offset p2, ui.Offset p3, ui.Offset p4) {
    double denom = (p1.dx - p2.dx) * (p3.dy - p4.dy) - (p1.dy - p2.dy) * (p3.dx - p4.dx);
    if (denom.abs() < 0.001) return null;
    double t = ((p1.dx - p3.dx) * (p3.dy - p4.dy) - (p1.dy - p3.dy) * (p3.dx - p4.dx)) / denom;
    double u = ((p1.dx - p3.dx) * (p1.dy - p2.dy) - (p1.dy - p3.dy) * (p1.dx - p2.dx)) / denom;
    if (t >= 0 && t <= 1 && u >= 0 && u <= 1) {
      return ui.Offset(p1.dx + t * (p2.dx - p1.dx), p1.dy + t * (p2.dy - p1.dy));
    }
    return null;
  }

  static double perpendicularDistance(ui.Offset pt, ui.Offset lineStart, ui.Offset lineEnd) {
    double dx = lineEnd.dx - lineStart.dx;
    double dy = lineEnd.dy - lineStart.dy;
    double mag = math.sqrt(dx * dx + dy * dy);
    if (mag > 0.0) { dx /= mag; dy /= mag; }
    double pvx = pt.dx - lineStart.dx;
    double pvy = pt.dy - lineStart.dy;
    double pvdot = pvx * dx + pvy * dy;
    double ax = pvx - pvdot * dx;
    double ay = pvy - pvdot * dy;
    return math.sqrt(ax * ax + ay * ay);
  }

  static ui.Offset? fastSnap(double px, double py, Set<(int, int)> known) {
    int cx = px.round();
    int cy = py.round();
    ui.Offset? best;
    double bestDistSq = 0.5; 
    
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        if (known.contains((cx + dx, cy + dy))) {
           double kx = (cx + dx).toDouble();
           double ky = (cy + dy).toDouble();
           double distSq = (px - kx)*(px - kx) + (py - ky)*(py - ky);
           if (distSq < bestDistSq) {
              bestDistSq = distSq;
              best = ui.Offset(kx, ky);
           }
        }
      }
    }
    return best;
  }

  static List<ui.Offset> simplifyOptimized(List<ui.Offset> points, double epsilon, Set<(int, int)> keepPoints) {
    if (points.length < 3) return points;

    for (int i = 1; i < points.length - 1; i++) {
      int rx = points[i].dx.round();
      int ry = points[i].dy.round();
      if (keepPoints.contains((rx, ry))) {
        var p1 = simplifyOptimized(points.sublist(0, i + 1), epsilon, keepPoints);
        var p2 = simplifyOptimized(points.sublist(i), epsilon, keepPoints);
        return [...p1.sublist(0, p1.length - 1), ...p2];
      }
    }

    int dmaxIndex = 0;
    double dmax = 0;
    for (int i = 1; i < points.length - 1; i++) {
      double d = perpendicularDistance(points[i], points.first, points.last);
      if (d > dmax) { dmaxIndex = i; dmax = d; }
    }
    if (dmax > epsilon) {
      var p1 = simplifyOptimized(points.sublist(0, dmaxIndex + 1), epsilon, keepPoints);
      var p2 = simplifyOptimized(points.sublist(dmaxIndex), epsilon, keepPoints);
      return [...p1.sublist(0, p1.length - 1), ...p2];
    } else {
      return [points.first, points.last];
    }
  }

  static bool _isPointInPolygon(ui.Offset pt, List<ui.Offset> poly) {
    bool inside = false;
    int j = poly.length - 1;
    for (int i = 0; i < poly.length; i++) {
      if ((poly[i].dy > pt.dy) != (poly[j].dy > pt.dy) &&
          pt.dx < (poly[j].dx - poly[i].dx) * (pt.dy - poly[i].dy) / (poly[j].dy - poly[i].dy) + poly[i].dx) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  static ui.Path provinceToCleanPath(ProvinceModel p) {
    final edgeCounts = <(int, int, int, int), int>{};
    final edgeMap = <(int, int, int, int), (ui.Offset, ui.Offset)>{};

    for (int i = 0; i < p.pointCount; i++) {
      final x1 = p.pointsX[i];
      final y1 = p.pointsY[i];
      final next = (i + 1) % p.pointCount;
      final x2 = p.pointsX[next];
      final y2 = p.pointsY[next];
      if (x1 == x2 && y1 == y2) continue;

      final key = (x1, y1, x2, y2);
      final revKey = (x2, y2, x1, y1);

      if (edgeCounts.containsKey(revKey) && edgeCounts[revKey]! > 0) {
        edgeCounts[revKey] = edgeCounts[revKey]! - 1;
        if (edgeCounts[revKey] == 0) {
          edgeCounts.remove(revKey);
          edgeMap.remove(revKey);
        }
      } else {
        edgeCounts[key] = (edgeCounts[key] ?? 0) + 1;
        edgeMap[key] = (
          ui.Offset(x1.toDouble(), y1.toDouble()),
          ui.Offset(x2.toDouble(), y2.toDouble()),
        );
      }
    }

    final activeEdges = <(ui.Offset, ui.Offset)>[];
    for (final entry in edgeCounts.entries) {
      for (int i = 0; i < entry.value; i++) {
        activeEdges.add(edgeMap[entry.key]!);
      }
    }

    final path = ui.Path();
    if (activeEdges.isEmpty) return path;

    while (activeEdges.isNotEmpty) {
      final first = activeEdges.removeAt(0);
      final loopPoints = <ui.Offset>[first.$1, first.$2];
      var currEnd = first.$2;

      while (true) {
        final nextIdx = activeEdges.indexWhere((e) => e.$1 == currEnd);
        if (nextIdx == -1) break;
        final next = activeEdges.removeAt(nextIdx);
        currEnd = next.$2;
        if (currEnd == loopPoints.first) break;
        loopPoints.add(currEnd);
      }

      if (loopPoints.length >= 3) {
        if (polygonAreaSigned(loopPoints) < 0) {
          final rev = loopPoints.reversed.toList();
          loopPoints.clear();
          loopPoints.addAll(rev);
        }
        path.moveTo(loopPoints[0].dx, loopPoints[0].dy);
        for (int i = 1; i < loopPoints.length; i++) {
          path.lineTo(loopPoints[i].dx, loopPoints[i].dy);
        }
        path.close();
      }
    }

    return path;
  }

  // =========================================================================================
  // FASE A: O Processamento Pesado. Path.combine, métricas, ray-casting e simplificação.
  // Só roda 1 vez quando você solta o clique no "Mesclar".
  // =========================================================================================
  static MergeContoursData? runBooleanMergePhaseA(List<ProvinceModel> provinces) {
    _mergeLog('--- INICIANDO FASE A (NATIVA E PESADA) ---');
    if (provinces.length < 2) return null;

    final Set<(int, int)> knownVertices = {};
    for (final p in provinces) {
      for (int i = 0; i < p.pointCount; i++) {
        knownVertices.add((p.pointsX[i], p.pointsY[i]));
      }
    }

    ui.Path combinedPath = provinceToCleanPath(provinces.first);

    for (int pIdx = 1; pIdx < provinces.length; pIdx++) {
      final pPath = provinceToCleanPath(provinces[pIdx]);
      try {
        combinedPath = ui.Path.combine(ui.PathOperation.union, combinedPath, pPath);
      } catch (e) {
        _mergeLog('Aviso: Path.combine falhou em uma província: $e. Tentando continuar...');
      }
    }

    final metrics = combinedPath.computeMetrics().toList();
    if (metrics.isEmpty) {
      _mergeLog('Falha: A união resultou em um Path vazio.');
      return null;
    }

    List<List<ui.Offset>> contours = [];
    for (var metric in metrics) {
      List<ui.Offset> sampled = [];
      
      for (double d = 0; d < metric.length; d += 1.0) {
        sampled.add(metric.getTangentForOffset(d)!.position);
      }
      if (sampled.isEmpty) continue;

      List<ui.Offset> snapped = [];
      for (var p in sampled) {
        final snap = fastSnap(p.dx, p.dy, knownVertices);
        if (snap != null) {
           if (snapped.isEmpty || snapped.last != snap) snapped.add(snap);
        } else {
           final pt = ui.Offset(p.dx.roundToDouble(), p.dy.roundToDouble());
           if (snapped.isEmpty || snapped.last != pt) snapped.add(pt);
        }
      }

      List<ui.Offset> contour = simplifyOptimized(snapped, 1.2, knownVertices);
      
      if (contour.length > 2) {
         double area = polygonAreaSigned(contour).abs();
         if (area > 1.0) {
             contours.add(contour);
         }
      }
    }

    if (contours.isEmpty) return null;

    contours.sort((a, b) => polygonAreaSigned(b).abs().compareTo(polygonAreaSigned(a).abs()));
    final baseContour = contours.first;
    final secondaries = contours.sublist(1);

    int islandsDetected = 0;
    for (var sec in secondaries) {
       bool isHole = _isPointInPolygon(sec.first, baseContour);
       if (!isHole) islandsDetected++;
    }

    _mergeLog('Fase A concluída: Contorno Base + ${secondaries.length} secundários detectados. Ilhas reais: $islandsDetected');

    return MergeContoursData(
      provinces.first.id,
      provinces.first.colorValue,
      provinces.first.geometryVersion,
      baseContour,
      secondaries,
      islandsDetected,
    );
  }

  // =========================================================================================
  // FASE B: Instântanea (O(N)). Injeta as pontes (L-Shape) permitindo ilhas se conectarem 
  // entre si (crescimento de massa), evitando linhas cruzadas na tela.
  // =========================================================================================
  static ProvinceModel runBooleanMergePhaseB(MergeContoursData data, int pathChoice) {
    // 1. O Contorno Principal que vai "crescer" absorvendo as ilhas
    List<ui.Offset> currentMain = List.of(data.baseContour);
    double baseArea = polygonAreaSigned(data.baseContour);

    // 2. Prepara as ilhas (arruma o sentido de rotação para buracos ou ilhas normais)
    List<List<ui.Offset>> islands = [];
    for (var sec in data.secondaries) {
        bool isHole = _isPointInPolygon(sec.first, data.baseContour);
        double secArea = polygonAreaSigned(sec);

        if (isHole) {
            if ((baseArea > 0 && secArea > 0) || (baseArea < 0 && secArea < 0)) {
                islands.add(sec.reversed.toList());
            } else {
                islands.add(sec);
            }
        } else {
            if ((baseArea > 0 && secArea < 0) || (baseArea < 0 && secArea > 0)) {
                islands.add(sec.reversed.toList());
            } else {
                islands.add(sec);
            }
        }
    }

    // 3. Algoritmo Iterativo de Crescimento (Minimum Spanning Tree de Contornos)
    // Conectamos a ilha mais próxima ao "corpo principal atual" (que pode já incluir outras ilhas).
    // Se a Ilha 2 estiver mais perto da Ilha 1 do que do Continente, ela se conecta na Ilha 1!
    while (islands.isNotEmpty) {
        int bestIslandIdx = -1;
        int bestMainIdx = -1;
        int bestSecIdx = -1;
        double minD = double.infinity;

        for (int i = 0; i < islands.length; i++) {
            var island = islands[i];
            for (int m = 0; m < currentMain.length; m++) {
                for (int s = 0; s < island.length; s++) {
                    double dx = currentMain[m].dx - island[s].dx;
                    double dy = currentMain[m].dy - island[s].dy;
                    
                    // Distância Euclidiana Pura: O mais perto real vence, sem punições.
                    double distSq = dx * dx + dy * dy;

                    if (distSq < minD) {
                        minD = distSq;
                        bestIslandIdx = i;
                        bestMainIdx = m;
                        bestSecIdx = s;
                    }
                }
            }
        }

        var chosenIsland = islands.removeAt(bestIslandIdx);
        var pMain = currentMain[bestMainIdx];
        var pSec = chosenIsland[bestSecIdx];

        List<ui.Offset> injection = [];
        
        // Ida: Ponte L-Shape ou Diagonal
        if (pathChoice == 1) {
            injection.add(ui.Offset(pSec.dx, pMain.dy));
        } else if (pathChoice == 2) {
            injection.add(ui.Offset(pMain.dx, pSec.dy));
        }

        // Caminha pelo contorno da Ilha
        for (int s = 0; s < chosenIsland.length; s++) {
            injection.add(chosenIsland[(bestSecIdx + s) % chosenIsland.length]);
        }
        injection.add(chosenIsland[bestSecIdx]);
        
        // Volta: Ponte L-Shape ou Diagonal
        if (pathChoice == 1) {
            injection.add(ui.Offset(pSec.dx, pMain.dy));
        } else if (pathChoice == 2) {
            injection.add(ui.Offset(pMain.dx, pSec.dy));
        }

        injection.add(pMain); // Fecha a ponte devolvendo pro corpo principal

        // Injeta a ilha e a ponte logo após o ponto de ancoragem.
        // O `currentMain` cresce e a próxima ilha pode se ancorar nesta que acabou de entrar.
        currentMain.insertAll(bestMainIdx + 1, injection);
    }

    // 4. Limpeza final para remover vértices duplicados consecutivos (L-Shapes muito próximos viram retas)
    List<ui.Offset> cleanPoints = [];
    for (var p in currentMain) {
      if (cleanPoints.isEmpty || cleanPoints.last != p) cleanPoints.add(p);
    }
    if (cleanPoints.length > 2 && cleanPoints.first == cleanPoints.last) cleanPoints.removeLast();

    return ProvinceModel.fromPoints(
       id: data.id,
       xs: cleanPoints.map((p) => p.dx.round()).toList(),
       ys: cleanPoints.map((p) => p.dy.round()).toList(),
       colorValue: data.colorValue,
       geometryVersion: data.geometryVersion + 1,
    );
  }

  static List<ClipResult> runClipping(ProvinceModel newProv, List<ProvinceModel> oldProvs, bool enableSnapping) {
    final results = <ClipResult>[];
    
    final newPath = ui.Path();
    newPath.moveTo(newProv.pointsX[0].toDouble(), newProv.pointsY[0].toDouble());
    for (int i = 1; i < newProv.pointCount; i++) {
      newPath.lineTo(newProv.pointsX[i].toDouble(), newProv.pointsY[i].toDouble());
    }
    newPath.close();

    for (final oldProv in oldProvs) {
      if (oldProv.id == newProv.id) continue;

      final Set<(int, int)> knownVertices = {};
      for (int i = 0; i < oldProv.pointCount; i++) { knownVertices.add((oldProv.pointsX[i], oldProv.pointsY[i])); }
      for (int i = 0; i < newProv.pointCount; i++) { knownVertices.add((newProv.pointsX[i], newProv.pointsY[i])); }
      
      for (int i = 0; i < oldProv.pointCount; i++) {
        final p1 = ui.Offset(oldProv.pointsX[i].toDouble(), oldProv.pointsY[i].toDouble());
        final p2 = ui.Offset(oldProv.pointsX[(i + 1) % oldProv.pointCount].toDouble(), oldProv.pointsY[(i + 1) % oldProv.pointCount].toDouble());
        for (int j = 0; j < newProv.pointCount; j++) {
          final p3 = ui.Offset(newProv.pointsX[j].toDouble(), newProv.pointsY[j].toDouble());
          final p4 = ui.Offset(newProv.pointsX[(j + 1) % newProv.pointCount].toDouble(), newProv.pointsY[(j + 1) % newProv.pointCount].toDouble());
          final intersect = lineIntersection(p1, p2, p3, p4);
          if (intersect != null) knownVertices.add((intersect.dx.round(), intersect.dy.round()));
        }
      }

      final oldPath = ui.Path();
      oldPath.moveTo(oldProv.pointsX[0].toDouble(), oldProv.pointsY[0].toDouble());
      for (int i = 1; i < oldProv.pointCount; i++) {
        oldPath.lineTo(oldProv.pointsX[i].toDouble(), oldProv.pointsY[i].toDouble());
      }
      oldPath.close();

      final resultPath = ui.Path.combine(ui.PathOperation.difference, oldPath, newPath);
      final metrics = resultPath.computeMetrics().toList();
      
      if (metrics.isEmpty) { 
        results.add(ClipResult(oldProv.id, null)); 
        continue; 
      }

      List<List<ui.Offset>> contours = [];

      for (int m = 0; m < metrics.length; m++) {
        final metric = metrics[m];
        List<ui.Offset> sampled = [];

        for (double d = 0; d < metric.length; d += 1.0) {
          sampled.add(metric.getTangentForOffset(d)!.position);
        }
        if (sampled.isEmpty) continue;

        List<ui.Offset> snapped = [];
        for (var p in sampled) {
          if (enableSnapping) {
            final snap = fastSnap(p.dx, p.dy, knownVertices);
            if (snap != null) {
              if (snapped.isEmpty || snapped.last != snap) snapped.add(snap);
              continue;
            }
          }
          final pt = ui.Offset(p.dx.roundToDouble(), p.dy.roundToDouble());
          if (snapped.isEmpty || snapped.last != pt) snapped.add(pt);
        }

        List<ui.Offset> contour = simplifyOptimized(snapped, 1.2, knownVertices);
        if (contour.isNotEmpty) contours.add(contour);
      }

      if (contours.isEmpty) { 
        results.add(ClipResult(oldProv.id, null)); 
        continue; 
      }

      contours.sort((a, b) => polygonAreaSigned(b).abs().compareTo(polygonAreaSigned(a).abs()));
      List<ui.Offset> finalPoints = contours.first;
      double baseArea = polygonAreaSigned(finalPoints);

      for (int i = 1; i < contours.length; i++) {
         List<ui.Offset> secondary = contours[i];
         
         bool isHole = _isPointInPolygon(secondary.first, finalPoints);
         double secArea = polygonAreaSigned(secondary);

         if (isHole) {
             if ((baseArea > 0 && secArea > 0) || (baseArea < 0 && secArea < 0)) {
                 secondary = secondary.reversed.toList();
             }
         } else {
             if ((baseArea > 0 && secArea < 0) || (baseArea < 0 && secArea > 0)) {
                 secondary = secondary.reversed.toList();
             }
         }

         int bestBaseIdx = 0, bestSecIdx = 0;
         double minD = double.infinity;

         for(int b = 0; b < finalPoints.length; b++) {
             for(int s = 0; s < secondary.length; s++) {
                 double d = (finalPoints[b].dx - secondary[s].dx)*(finalPoints[b].dx - secondary[s].dx) + 
                            (finalPoints[b].dy - secondary[s].dy)*(finalPoints[b].dy - secondary[s].dy);
                 if (d < minD) { minD = d; bestBaseIdx = b; bestSecIdx = s; }
             }
         }

         List<ui.Offset> newBase = [];
         for(int b = 0; b <= bestBaseIdx; b++) { newBase.add(finalPoints[b]); }
         for(int s = 0; s < secondary.length; s++) { newBase.add(secondary[(bestSecIdx + s) % secondary.length]); }
         newBase.add(secondary[bestSecIdx]);
         newBase.add(finalPoints[bestBaseIdx]);
         for(int b = bestBaseIdx + 1; b < finalPoints.length; b++) { newBase.add(finalPoints[b]); }
         finalPoints = newBase;
      }

      List<ui.Offset> cleanPoints = [];
      for (var p in finalPoints) {
        if (cleanPoints.isEmpty || cleanPoints.last != p) cleanPoints.add(p);
      }
      if (cleanPoints.length > 2 && cleanPoints.first == cleanPoints.last) {
        cleanPoints.removeLast();
      }

      if (cleanPoints.length > 2) {
        final updated = oldProv.copyWith(
          pointsX: Int32List.fromList(cleanPoints.map((p) => p.dx.round()).toList()),
          pointsY: Int32List.fromList(cleanPoints.map((p) => p.dy.round()).toList()),
        );
        results.add(ClipResult(oldProv.id, updated));
      } else {
        results.add(ClipResult(oldProv.id, null));
      }
    }
    
    return results;
  }
}