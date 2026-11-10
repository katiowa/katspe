part of '../map_painter.dart';

mixin _PropsPainter on MapPainterBase {
  void drawPropsLayer(Canvas canvas, BoundingBox visibleWorld) {
    if (props.isEmpty) return;

    for (final prop in props) {
      if (!prop.isVisible) continue;
      if (enableFrustumCulling && !prop.boundingBox.intersects(visibleWorld)) continue;

      final img = propImages[prop.id];
      if (img == null || prop.mesh.isEmpty) continue;

      final w = img.width.toDouble();
      final h = img.height.toDouble();

      final positions = <Offset>[];
      final texCoords = <Offset>[];
      final d = prop.divisions;

      for (int row = 0; row < d; row++) {
        for (int col = 0; col < d; col++) {
          int iTL = row * (d + 1) + col;
          int iTR = iTL + 1;
          int iBL = (row + 1) * (d + 1) + col;
          int iBR = iBL + 1;

          if (iBR >= prop.mesh.length) continue;

          Offset pTL = prop.mesh[iTL];
          Offset pTR = prop.mesh[iTR];
          Offset pBL = prop.mesh[iBL];
          Offset pBR = prop.mesh[iBR];

          double uTL = (col / d) * w;
          double vTL = (row / d) * h;
          double uTR = ((col + 1) / d) * w;
          double vTR = (row / d) * h;
          double uBL = (col / d) * w;
          double vBL = ((row + 1) / d) * h;
          double uBR = ((col + 1) / d) * w;
          double vBR = ((row + 1) / d) * h;

          positions.addAll([pTL, pTR, pBR, pTL, pBR, pBL]);
          texCoords.addAll([
            Offset(uTL, vTL), Offset(uTR, vTR), Offset(uBR, vBR),
            Offset(uTL, vTL), Offset(uBR, vBR), Offset(uBL, vBL)
          ]);
        }
      }

      final Float64List matrix4 = Float64List.fromList(const [
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0,
      ]);

      final shader = ui.ImageShader(
        img,
        ui.TileMode.clamp,
        ui.TileMode.clamp,
        matrix4,
      );

      final paint = Paint()
        ..shader = shader
        ..color = Color.fromRGBO(255, 255, 255, prop.opacity);

      final vertices = ui.Vertices(
        ui.VertexMode.triangles,
        positions,
        textureCoordinates: texCoords,
      );

      canvas.drawVertices(vertices, ui.BlendMode.modulate, paint);

      if (selectedPropId == prop.id && !prop.isLocked) {
        _drawPropHandles(canvas, prop);
      }
    }
  }

  void _drawPropHandles(Canvas canvas, PropModel prop) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = config.selectedBorderColor
      ..strokeWidth = 2.0 / zoomScale;

    // A Borda principal do Prop conectando as 4 quinas
    final path = Path()
      ..moveTo(prop.corners[0].dx, prop.corners[0].dy)
      ..lineTo(prop.corners[1].dx, prop.corners[1].dy)
      ..lineTo(prop.corners[2].dx, prop.corners[2].dy)
      ..lineTo(prop.corners[3].dx, prop.corners[3].dy)
      ..close();

    canvas.drawPath(path, linePaint);

    // No modo Deformar, traça o Wireframe conectando todos os nós internos da malha
    if (prop.isDeforming && prop.divisions > 1 && prop.mesh.isNotEmpty) {
      final wireframePaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x664FA3E3)
        ..strokeWidth = 1.0 / zoomScale;
      
      final meshPath = Path();
      int d = prop.divisions;
      
      for (int row = 0; row <= d; row++) {
        meshPath.moveTo(prop.mesh[row * (d + 1)].dx, prop.mesh[row * (d + 1)].dy);
        for (int col = 1; col <= d; col++) {
          meshPath.lineTo(prop.mesh[row * (d + 1) + col].dx, prop.mesh[row * (d + 1) + col].dy);
        }
      }
      for (int col = 0; col <= d; col++) {
        meshPath.moveTo(prop.mesh[col].dx, prop.mesh[col].dy);
        for (int row = 1; row <= d; row++) {
          meshPath.lineTo(prop.mesh[row * (d + 1) + col].dx, prop.mesh[row * (d + 1) + col].dy);
        }
      }
      canvas.drawPath(meshPath, wireframePaint);
    }

    final handlePaint = Paint()
      ..color = config.pointHandleColor
      ..style = PaintingStyle.fill;

    final subHandlePaint = Paint()
      ..color = const Color(0xFF4FA3E3)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / zoomScale;

    final radius = 6.0 / zoomScale;

    void drawHandle(Offset center, Paint fill) {
      canvas.drawCircle(center, radius, fill);
      canvas.drawCircle(center, radius, borderPaint);
    }

    if (prop.isDeforming) {
      // No modo Deformar, desenha TODAS as handles da malha para o usuário poder clicar e arrastar
      int d = prop.divisions;
      for (int i = 0; i < prop.mesh.length; i++) {
        bool isCorner = i == 0 || i == d || i == prop.mesh.length - 1 || i == prop.mesh.length - 1 - d;
        drawHandle(prop.mesh[i], isCorner ? handlePaint : subHandlePaint);
      }
    } else {
      // No modo Scale normal, desenha apenas os 4 cantos
      for (final corner in prop.corners) {
        drawHandle(corner, handlePaint);
      }
    }

    // Alça Central para Mover (Pan)
    final cx = (prop.corners[0].dx + prop.corners[1].dx + prop.corners[2].dx + prop.corners[3].dx) / 4;
    final cy = (prop.corners[0].dy + prop.corners[1].dy + prop.corners[2].dy + prop.corners[3].dy) / 4;
    canvas.drawCircle(Offset(cx, cy), radius * 1.2, subHandlePaint);
    canvas.drawCircle(Offset(cx, cy), radius * 1.2, borderPaint);
  }
}