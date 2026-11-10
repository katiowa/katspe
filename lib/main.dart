import 'dart:io';
import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // No mobile real, ativa tela cheia imersiva (esconde status bar e navbar do sistema)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  
  final preFlight = await preFlightBoot();

  runApp(
    DevicePreview(
      enabled: !kReleaseMode, // Ativo em modo de desenvolvimento no Desktop
      builder: (context) => MapEditorApp(preFlight: preFlight),
    ),
  );
}