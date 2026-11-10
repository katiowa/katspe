import 'dart:ui' show Offset;

/// Transformação pura de câmera (pan + zoom) entre coordenadas de tela e
/// coordenadas de mundo.
///
/// Extraído do [MapPainter] porque parte do código (por exemplo, o
/// overlay do menu de ação do ponto selecionado) só precisa converter
/// UMA coordenada e não tem nenhum motivo para instanciar um
/// `CustomPainter` inteiro — com todas as listas de províncias, POIs e
/// a config da engine — só para chamar `worldToScreen`/`screenToWorld`
/// e descartar o objeto sem nunca pintar nada.
class CameraTransform {
  final Offset panOffset;
  final double zoomScale;

  const CameraTransform({required this.panOffset, required this.zoomScale});

  Offset screenToWorld(Offset localPosition) => Offset(
        localPosition.dx / zoomScale + panOffset.dx,
        localPosition.dy / zoomScale + panOffset.dy,
      );

  Offset worldToScreen(Offset worldPosition) => Offset(
        (worldPosition.dx - panOffset.dx) * zoomScale,
        (worldPosition.dy - panOffset.dy) * zoomScale,
      );
}
