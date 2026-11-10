import 'dart:math' as math;
import 'dart:ui' show Offset;
import 'bounding_box.dart';

class PropModel {
  final String id;
  final String name;
  final String imageFileName;
  final double opacity;
  final double rotation; // Rotação em graus (-180 a 180)
  final bool isLocked;
  final bool isVisible;
  final bool keepAspectRatio;
  final bool isDeforming;
  
  final int divisions;
  final double distance;
  
  final List<Offset> mesh;
  final List<Offset> corners;

  const PropModel({
    required this.id,
    required this.name,
    required this.imageFileName,
    this.opacity = 1.0, 
    this.rotation = 0.0,
    this.isLocked = false,
    this.isVisible = true,
    this.keepAspectRatio = true,
    this.isDeforming = false,
    this.divisions = 1,
    this.distance = 1.0,
    required this.corners,
    this.mesh = const [],
  });

  /// Rotaciona a geometria atual (corners e mesh) ao redor do centro do prop
  /// preservando qualquer escala ou deformação já existente.
  PropModel withRotation(double targetAngleDeg) {
    final deltaDeg = targetAngleDeg - rotation;
    if (deltaDeg == 0.0) return this;

    final alpha = deltaDeg * math.pi / 180.0;
    final cosA = math.cos(alpha);
    final sinA = math.sin(alpha);

    final cx = (corners[0].dx + corners[1].dx + corners[2].dx + corners[3].dx) / 4.0;
    final cy = (corners[0].dy + corners[1].dy + corners[2].dy + corners[3].dy) / 4.0;

    Offset rotatePt(Offset p) {
      final dx = p.dx - cx;
      final dy = p.dy - cy;
      return Offset(
        cx + dx * cosA - dy * sinA,
        cy + dx * sinA + dy * cosA,
      );
    }

    final newCorners = corners.map(rotatePt).toList();
    final newMesh = mesh.map(rotatePt).toList();

    return copyWith(
      rotation: targetAngleDeg,
      corners: newCorners,
      mesh: newMesh,
    );
  }

  /// Gera a malha de interpolação bilinear garantindo que os 4 cantos
  /// fiquem RIGIDAMENTE fixos nos corners da imagem, e o parâmetro 'distance'
  /// afeta estritamente a densidade/espaçamento entre os vizinhos!
  static List<Offset> generateMesh(List<Offset> corners, int divisions, double distance) {
    if (corners.length < 4) return corners;
    final d = divisions;
    final result = <Offset>[];

    // Curva simétrica para espaçamento entre pontos
    double spacing(double t) {
      if (distance == 1.0 || t <= 0.0 || t >= 1.0) return t;
      if (t <= 0.5) {
        return 0.5 * math.pow(2 * t, distance);
      } else {
        return 1.0 - (0.5 * math.pow(2 * (1.0 - t), distance));
      }
    }

    for (int row = 0; row <= d; row++) {
      final v = spacing(row / d);
      for (int col = 0; col <= d; col++) {
        final u = spacing(col / d);
        
        final top = Offset.lerp(corners[0], corners[1], u)!;
        final bottom = Offset.lerp(corners[3], corners[2], u)!;
        final pt = Offset.lerp(top, bottom, v)!;
        result.add(pt);
      }
    }
    return result;
  }

  BoundingBox get boundingBox {
    if (corners.isEmpty) return BoundingBox.empty();
    double minX = corners[0].dx, maxX = corners[0].dx;
    double minY = corners[0].dy, maxY = corners[0].dy;
    
    for (int i = 1; i < 4; i++) {
      if (corners[i].dx < minX) minX = corners[i].dx;
      if (corners[i].dx > maxX) maxX = corners[i].dx;
      if (corners[i].dy < minY) minY = corners[i].dy;
      if (corners[i].dy > maxY) maxY = corners[i].dy;
    }
    
    return BoundingBox(
      minX: minX.floor(),
      minY: minY.floor(),
      maxX: maxX.ceil(),
      maxY: maxY.ceil(),
    );
  }

  factory PropModel.fromJson(Map<String, dynamic> json) {
    final rawCorners = json['corners'] as List;
    final parsedCorners = rawCorners.map((c) => Offset(
      (c['x'] as num).toDouble(),
      (c['y'] as num).toDouble()
    )).toList();

    final rawMesh = json['mesh'] as List?;
    final parsedMesh = rawMesh?.map((c) => Offset(
      (c['x'] as num).toDouble(),
      (c['y'] as num).toDouble()
    )).toList() ?? [];

    final divs = (json['divisions'] as num?)?.toInt() ?? 1;
    final dist = (json['distance'] as num?)?.toDouble() ?? 1.0;
    final rot = (json['rotation'] as num?)?.toDouble() ?? 0.0;

    return PropModel(
      id: json['id'].toString(),
      name: json['name'].toString(),
      imageFileName: json['imageFileName'].toString(),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      rotation: rot,
      isLocked: json['isLocked'] as bool? ?? false,
      isVisible: json['isVisible'] as bool? ?? true,
      keepAspectRatio: json['keepAspectRatio'] as bool? ?? true,
      isDeforming: json['isDeforming'] as bool? ?? false,
      divisions: divs,
      distance: dist,
      corners: parsedCorners,
      mesh: parsedMesh.isEmpty ? generateMesh(parsedCorners, divs, dist) : parsedMesh,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imageFileName': imageFileName,
    'opacity': opacity,
    'rotation': rotation,
    'isLocked': isLocked,
    'isVisible': isVisible,
    'keepAspectRatio': keepAspectRatio,
    'isDeforming': isDeforming,
    'divisions': divisions,
    'distance': distance,
    'corners': corners.map((c) => {'x': c.dx, 'y': c.dy}).toList(),
    'mesh': mesh.map((c) => {'x': c.dx, 'y': c.dy}).toList(),
  };

  PropModel copyWith({
    String? name,
    double? opacity,
    double? rotation,
    bool? isLocked,
    bool? isVisible,
    bool? keepAspectRatio,
    bool? isDeforming,
    int? divisions,
    double? distance,
    List<Offset>? corners,
    List<Offset>? mesh,
  }) {
    return PropModel(
      id: id,
      name: name ?? this.name,
      imageFileName: imageFileName,
      opacity: opacity ?? this.opacity,
      rotation: rotation ?? this.rotation,
      isLocked: isLocked ?? this.isLocked,
      isVisible: isVisible ?? this.isVisible,
      keepAspectRatio: keepAspectRatio ?? this.keepAspectRatio,
      isDeforming: isDeforming ?? this.isDeforming,
      divisions: divisions ?? this.divisions,
      distance: distance ?? this.distance,
      corners: corners ?? List.of(this.corners),
      mesh: mesh ?? List.of(this.mesh),
    );
  }
}