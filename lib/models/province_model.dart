import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter/material.dart' show HSVColor;

import 'bounding_box.dart';

final Random _colorRandom = Random();

int randomProvinceColorValue({Random? random}) {
  final rnd = random ?? _colorRandom;
  final hue = rnd.nextDouble() * 360.0;
  final color = HSVColor.fromAHSV(1.0, hue, 0.55 + rnd.nextDouble() * 0.35,
          0.65 + rnd.nextDouble() * 0.25)
      .toColor();
  return color.toARGB32();
}

class ProvinceModel {
  final int id;
  final Int32List pointsX;
  final Int32List pointsY;
  final BoundingBox boundingBox;
  final int colorValue;
  final int geometryVersion;

  const ProvinceModel({
    required this.id,
    required this.pointsX,
    required this.pointsY,
    required this.boundingBox,
    required this.colorValue,
    this.geometryVersion = 0,
  });

  /// Constrói uma província a partir de listas brutas de coordenadas.
  /// Agora aceita a [geometryVersion] para invalidar o cache de desenho corretamente!
  factory ProvinceModel.fromPoints({
    required int id,
    required List<int> xs,
    required List<int> ys,
    int? colorValue,
    int geometryVersion = 0,
  }) {
    final pointsX = Int32List.fromList(xs);
    final pointsY = Int32List.fromList(ys);
    return ProvinceModel(
      id: id,
      pointsX: pointsX,
      pointsY: pointsY,
      boundingBox: BoundingBox.fromPoints(pointsX, pointsY),
      colorValue: colorValue ?? randomProvinceColorValue(),
      geometryVersion: geometryVersion,
    );
  }

  factory ProvinceModel.fromJson(Map<String, dynamic> json) {
    return ProvinceModel(
      id: json['id'] as int,
      pointsX: Int32List.fromList((json['x'] as List).cast<int>()),
      pointsY: Int32List.fromList((json['y'] as List).cast<int>()),
      boundingBox: BoundingBox.fromJson(json['bbox'] as Map<String, dynamic>),
      colorValue: json['color'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': pointsX,
        'y': pointsY,
        'bbox': boundingBox.toJson(),
        'color': colorValue,
      };

  int get pointCount => pointsX.length;
  Color get color => Color(colorValue);

  ProvinceModel withPointMoved(int pointIndex, int newX, int newY) {
    final newXs = Int32List.fromList(pointsX);
    final newYs = Int32List.fromList(pointsY);
    newXs[pointIndex] = newX;
    newYs[pointIndex] = newY;
    return ProvinceModel(
      id: id,
      pointsX: newXs,
      pointsY: newYs,
      boundingBox: BoundingBox.fromPoints(newXs, newYs),
      colorValue: colorValue,
      geometryVersion: geometryVersion + 1,
    );
  }

  ProvinceModel copyWith({
    Int32List? pointsX,
    Int32List? pointsY,
    int? colorValue,
  }) {
    final newX = pointsX ?? this.pointsX;
    final newY = pointsY ?? this.pointsY;
    final geometryChanged = pointsX != null || pointsY != null;
    return ProvinceModel(
      id: id,
      pointsX: newX,
      pointsY: newY,
      boundingBox:
          geometryChanged ? BoundingBox.fromPoints(newX, newY) : boundingBox,
      colorValue: colorValue ?? this.colorValue,
      geometryVersion: geometryChanged ? geometryVersion + 1 : geometryVersion,
    );
  }
}

extension ProvinceGeometry on ProvinceModel {
  bool containsWorldPoint(double px, double py) {
    if (!boundingBox.containsPoint(px.round(), py.round())) return false;
    bool inside = false;
    final n = pointsX.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      final xi = pointsX[i], yi = pointsY[i];
      final xj = pointsX[j], yj = pointsY[j];
      final crosses = ((yi > py) != (yj > py)) &&
          (px < (xj - xi) * (py - yi) / (yj - yi) + xi);
      if (crosses) inside = !inside;
    }
    return inside;
  }

  (int index, double distance)? nearestPoint(double px, double py) {
    if (pointsX.isEmpty) return null;
    int bestIndex = 0;
    double bestDistSq = double.infinity;
    for (int i = 0; i < pointsX.length; i++) {
      final dx = pointsX[i] - px;
      final dy = pointsY[i] - py;
      final distSq = dx * dx + dy * dy;
      if (distSq < bestDistSq) {
        bestDistSq = distSq;
        bestIndex = i;
      }
    }
    return (bestIndex, sqrt(bestDistSq));
  }
}