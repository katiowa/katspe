import 'bounding_box.dart';
import 'province_model.dart';

/// Estrutura raiz do JSON otimizado interno: o mapa completo.
class EngineMapData {
  final int formatVersion;
  final DateTime generatedAt;
  final List<ProvinceModel> provinces;
  final BoundingBox worldBounds;

  EngineMapData({
    required this.formatVersion,
    required this.generatedAt,
    required this.provinces,
    required this.worldBounds,
  });

  factory EngineMapData.empty() => EngineMapData(
        formatVersion: 1,
        generatedAt: DateTime.now(),
        provinces: const [],
        worldBounds: BoundingBox.empty(),
      );

  factory EngineMapData.fromJson(Map<String, dynamic> json) {
    final rawProvinces = json['provinces'] as List;
    return EngineMapData(
      formatVersion: json['formatVersion'] as int,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      provinces: rawProvinces
          .map((p) => ProvinceModel.fromJson(p as Map<String, dynamic>))
          .toList(growable: false),
      worldBounds: BoundingBox.fromJson(json['worldBounds'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'generatedAt': generatedAt.toIso8601String(),
        'provinces': provinces.map((p) => p.toJson()).toList(growable: false),
        'worldBounds': worldBounds.toJson(),
      };

  static BoundingBox computeWorldBounds(List<ProvinceModel> provinces) {
    var bounds = BoundingBox.empty();
    for (final p in provinces) {
      bounds = bounds.merge(p.boundingBox);
    }
    return bounds;
  }

  /// Índice id -> posição na lista [provinces], construído sob demanda e em
  /// O(N) uma única vez por instância (instâncias são imutáveis: a lista
  /// nunca muda depois de criada, então o índice nunca fica stale). Isso
  /// leva `findById`/`upsertProvince`/`removeProvince` de O(N) para O(1)
  /// amortizado, sem trocar a estrutura pública `List<ProvinceModel>` que
  /// o resto do projeto (painter, spatial grid, export) já consome.
  Map<int, int>? _idIndexCache;

  Map<int, int> get _idIndex {
    final cached = _idIndexCache;
    if (cached != null) return cached;
    final index = <int, int>{};
    for (int i = 0; i < provinces.length; i++) {
      index[provinces[i].id] = i;
    }
    return _idIndexCache = index;
  }

  ProvinceModel? findById(int id) {
    final i = _idIndex[id];
    return i == null ? null : provinces[i];
  }

  /// Posição de uma província na lista [provinces], em O(1). Usado pelo
  /// `MapRepository` para atualizar o `SpatialGrid` incrementalmente
  /// (ver `SpatialGrid.updateProvinceAt`) sem precisar reconstruir o
  /// índice espacial inteiro a cada edição.
  int? indexOf(int id) => _idIndex[id];

  /// Retorna uma NOVA [EngineMapData] com [province] inserida (se o id
  /// for novo) ou substituída (se já existir). Usa o índice id->posição
  /// para evitar o `indexWhere` linear a cada chamada.
  EngineMapData upsertProvince(ProvinceModel province) {
    final updated = List<ProvinceModel>.of(provinces);
    final existingIndex = _idIndex[province.id];
    if (existingIndex != null) {
      updated[existingIndex] = province;
    } else {
      updated.add(province);
    }
    return EngineMapData(
      formatVersion: formatVersion,
      generatedAt: DateTime.now(),
      provinces: updated,
      worldBounds: worldBounds.merge(province.boundingBox),
    );
  }

  EngineMapData removeProvince(int provinceId) {
    if (!_idIndex.containsKey(provinceId)) return this;
    final updated = provinces.where((p) => p.id != provinceId).toList();
    return EngineMapData(
      formatVersion: formatVersion,
      generatedAt: DateTime.now(),
      provinces: updated,
      worldBounds: computeWorldBounds(updated),
    );
  }

  /// Insere/substitui várias províncias de uma vez em UMA única passada
  /// O(N), em vez de chamar [upsertProvince] em loop (que seria O(K×N):
  /// um `findById` + uma cópia de lista inteira POR província alterada).
  /// Use isso sempre que uma ação do usuário afetar mais de uma província
  /// (mover seleção múltipla, atualizar vários pontos, etc.).
  EngineMapData upsertMany(Iterable<ProvinceModel> changed) {
    final changedList = changed.toList(growable: false);
    if (changedList.isEmpty) return this;
    final byId = {for (final p in changedList) p.id: p};
    final updated = List<ProvinceModel>.of(provinces);
    var bounds = worldBounds;
    for (int i = 0; i < updated.length; i++) {
      final replacement = byId.remove(updated[i].id);
      if (replacement != null) {
        updated[i] = replacement;
        bounds = bounds.merge(replacement.boundingBox);
      }
    }
    // Sobras em `byId` são províncias novas (ids que não existiam ainda).
    for (final p in byId.values) {
      updated.add(p);
      bounds = bounds.merge(p.boundingBox);
    }
    return EngineMapData(
      formatVersion: formatVersion,
      generatedAt: DateTime.now(),
      provinces: updated,
      worldBounds: bounds,
    );
  }

  /// Remove várias províncias de uma vez em UMA única passada O(N), em vez
  /// de chamar [removeProvince] em loop (O(K×N)).
  EngineMapData removeMany(Iterable<int> ids) {
    final idSet = ids.toSet();
    if (idSet.isEmpty) return this;
    final updated = provinces.where((p) => !idSet.contains(p.id)).toList();
    return EngineMapData(
      formatVersion: formatVersion,
      generatedAt: DateTime.now(),
      provinces: updated,
      worldBounds: computeWorldBounds(updated),
    );
  }
}
