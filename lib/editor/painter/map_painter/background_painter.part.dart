part of '../map_painter.dart';

mixin _BackgroundPainter on MapPainterBase {
  void drawBackgroundLayer(Canvas canvas) {
    final img = backgroundImage;
    if (img == null) return;
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = config.backgroundOpacity >= 1.0
          ? null
          : ColorFilter.mode(
              Colors.white.withValues(alpha: config.backgroundOpacity),
              BlendMode.dstIn,
            );
            
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      paint,
    );
  }
}