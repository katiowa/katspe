import 'dart:ui';
import 'package:flutter/widgets.dart' show TextPainter;

/// Cache de `Path` por província, com vida útil independente do
/// `MapPainter` (que é reconstruído a cada notificação do
/// `AnimatedBuilder` — inclusive a cada pixel de pan/zoom).
///
/// Sem isso, `MapPainter._buildPath()` reconstruía a geometria de TODAS
/// as províncias visíveis a cada frame, mesmo em pan/zoom puro — que já
/// é resolvido só com `canvas.scale`/`translate` e não muda nenhum
/// ponto. Guardando o `Path` já construído por província e invalidando
/// SOMENTE quando `ProvinceModel.geometryVersion` mudar de verdade, pan
/// e zoom passam a custar ZERO reconstrução de `Path`.
///
/// Precisa ser criado uma vez pelo dono do `MapPainter` (a tela do
/// editor) e reaproveitado entre frames — nunca recriado dentro do
/// `build()`.
class MapPathCache {
  final Map<int, (int version, Path path)> _cache = {};

  Path getOrBuild(int provinceId, int geometryVersion, Path Function() build) {
    final cached = _cache[provinceId];
    if (cached != null && cached.$1 == geometryVersion) {
      return cached.$2;
    }
    final path = build();
    _cache[provinceId] = (geometryVersion, path);
    return path;
  }

  /// Remove entradas de províncias que não existem mais no mapa atual
  /// (deletadas/mescladas), para não vazar memória indefinidamente numa
  /// sessão de edição longa.
  void prune(Set<int> liveProvinceIds) {
    _cache.removeWhere((id, _) => !liveProvinceIds.contains(id));
  }
}

/// Cache de `TextPainter` (já com `layout()` chamado) para os rótulos de
/// POI, evitando o custo de shaping/medição de fonte — uma das
/// operações mais caras do Flutter — a cada frame por cidade/montanha/
/// wonder visível.
///
/// O tamanho da fonte depende do zoom (`poiLabelFontSize / zoomScale`,
/// para manter um tamanho constante na TELA independente do zoom),
/// então a chave inclui um "bucket" de zoom quantizado em vez do valor
/// exato — evita relayout a cada frame de PAN (zoom não muda) enquanto
/// ainda faz o texto reagir ao ZOOM com granularidade fina o bastante
/// para não ser perceptível (passos de ~5%).
class MapLabelCache {
  final Map<(String, int), TextPainter> _cache = {};
  static const int _maxEntries = 4000;

  TextPainter getOrBuild(String text, double zoomScale, TextPainter Function() build) {
    final bucket = (zoomScale * 20).round();
    final key = (text, bucket);
    final cached = _cache[key];
    if (cached != null) return cached;
    if (_cache.length >= _maxEntries) {
      // Sem LRU real por simplicidade: um mapa com dezenas de milhares
      // de nomes de cidade distintos, navegado em zooms muito variados,
      // não deveria reter um TextPainter para cada combinação para
      // sempre. Descartar tudo periodicamente é barato e o cache
      // reconstrói sob demanda nos próximos frames.
      _cache.clear();
    }
    final painter = build();
    _cache[key] = painter;
    return painter;
  }
}

/// Agrupa os caches que o `MapPainter` usa entre frames. Uma única
/// instância deve ser criada pela tela do editor (não pelo painter) e
/// passada a cada `MapPainter` novo.
class MapPainterCache {
  final MapPathCache paths = MapPathCache();
  final MapLabelCache labels = MapLabelCache();
}
