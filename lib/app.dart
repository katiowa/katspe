import 'dart:ui';
import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:flutter/material.dart';

import 'core/engine_context.dart';
import 'editor/screen/editor_screen.dart';
import 'init.dart';
import 'render/boot_failure_view.dart';
import 'render/loading_screen.dart';
import 'theme/app_theme.dart';

/// Permite arrastar qualquer menu ou lista horizontal com o botão esquerdo do mouse no Desktop
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class MapEditorApp extends StatefulWidget {
  final PreFlightResult preFlight;
  
  const MapEditorApp({super.key, required this.preFlight});

  @override
  State<MapEditorApp> createState() => _MapEditorAppState();
}

class _MapEditorAppState extends State<MapEditorApp> {
  late BootOrchestrator _orchestrator;
  bool _isTeardownComplete = false;

  @override
  void initState() {
    super.initState();
    if (widget.preFlight.success) {
      _orchestrator = BootOrchestrator();
      _orchestrator.runHeavyBoot();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.preFlight.success) {
      return MaterialApp(
        title: 'KatsPE Engine',
        scrollBehavior: const AppScrollBehavior(),
        locale: DevicePreview.locale(context),
        builder: DevicePreview.appBuilder,
        theme: AppTheme.themeData(),
        home: EngineBootFailureScreen(report: widget.preFlight.failureReport!),
      );
    }

    return MaterialApp(
      title: 'KatsPE Engine',
      scrollBehavior: const AppScrollBehavior(),
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      theme: AppTheme.themeData(),
      home: Scaffold(
        backgroundColor: AppTheme.bg0,
        body: AnimatedBuilder(
          animation: _orchestrator,
          builder: (context, _) {
            if (_orchestrator.finalReport != null && !_orchestrator.finalReport!.success) {
              return EngineBootFailureScreen(report: _orchestrator.finalReport!);
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                if (_orchestrator.isFinished)
                  const MapEditorScreen(),
                  
                if (!_isTeardownComplete)
                  LoadingScreen(
                    orchestrator: _orchestrator,
                    lang: EngineContext.instance.language,
                    onTeardownComplete: () {
                      setState(() {
                        _isTeardownComplete = true;
                      });
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}