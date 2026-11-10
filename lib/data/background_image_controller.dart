import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Carrega e mantém em memória a imagem de fundo do cenário (o mapa-
/// múndi/textura por baixo das províncias, ex: um heightmap ou o mapa
/// político de referência do AoH2).
///
/// A imagem é desenhada em COORDENADAS DE MUNDO a partir de (0,0) — o
/// mesmo espaço de coordenadas usado pelas províncias e por
/// cities/mountains/wonders — então basta que o arquivo escolhido pelo
/// usuário já esteja na mesma escala/alinhamento do `.txt` do mapa
/// (como é o caso do mapa oficial do AoH2).
class BackgroundImageController extends ChangeNotifier {
  ui.Image? _image;
  String? _imagePath;
  bool _isLoading = false;

  ui.Image? get image => _image;
  String? get imagePath => _imagePath;
  bool get hasImage => _image != null;
  bool get isLoading => _isLoading;

  /// Carrega uma imagem (PNG/JPG/BMP) do disco a partir de [path] e a
  /// decodifica de forma assíncrona (não bloqueia a thread de UI
  /// durante o decode, que pode ser pesado para mapas-múndi grandes).
  Future<void> loadFromFile(String path) async {
    _isLoading = true;
    notifyListeners();
    try {
      final Uint8List bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _image?.dispose();
      _image = frame.image;
      _imagePath = path;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _image?.dispose();
    _image = null;
    _imagePath = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }
}
