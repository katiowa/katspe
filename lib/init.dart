import 'package:flutter/foundation.dart';

import 'initializers/api_initializer.dart';
import 'initializers/initializer_contract.dart';
import 'initializers/interface_initializer.dart';
import 'initializers/plugin_initializer.dart';
import 'initializers/preferences_apply_initializer.dart';
import 'initializers/render_initializer.dart';
import 'initializers/storage_initializer.dart';

/// Outcome of a single boot stage, kept for the diagnostics screen and for
/// anyone who wants to log the boot sequence.
class BootStep {
  final String name;
  final bool success;
  final String message;
  const BootStep({required this.name, required this.success, required this.message});
}

/// Outcome of the full boot sequence.
class EngineBootReport {
  final List<BootStep> steps;
  final bool success;
  EngineBootReport(this.steps) : success = steps.every((s) => s.success);
}

class PreFlightResult {
  final bool success;
  final EngineBootReport? failureReport;
  PreFlightResult.success() : success = true, failureReport = null;
  PreFlightResult.failure(this.failureReport) : success = false;
}

/// Fase 1: Pre-Flight
/// Executa instantaneamente ANTES da UI ser desenhada para termos 
/// as pastas e o JSON do idioma nativo já carregados na memória.
Future<PreFlightResult> preFlightBoot() async {
  final pipeline = <InitializerContract>[
    StorageInitializer(),
    InterfaceInitializer(),
  ];

  final steps = <BootStep>[];
  for (final initializer in pipeline) {
    final result = await initializer.run();
    steps.add(BootStep(name: initializer.name, success: result.success, message: result.message));
    if (!result.success) {
      return PreFlightResult.failure(EngineBootReport(steps));
    }
  }
  return PreFlightResult.success();
}

/// Fase 2: Heavy Boot Orchestrator
/// Executado e controlado pela UI de Loading (já traduzida).
class BootOrchestrator extends ChangeNotifier {
  int currentStep = 0;
  final int totalSteps = 4;
  String currentLoadingKey = '';
  bool isFinished = false;
  EngineBootReport? finalReport;

  Future<void> runHeavyBoot() async {
    final pipeline = <InitializerContract>[
      RenderInitializer(),
      ApiInitializer(),
      PluginInitializer(),
      PreferencesApplyInitializer(),
    ];

    final steps = <BootStep>[
      const BootStep(name: 'Storage', success: true, message: 'OK (Pre-flight)'),
      const BootStep(name: 'Interface', success: true, message: 'OK (Pre-flight)'),
    ];

    for (int i = 0; i < pipeline.length; i++) {
      final initializer = pipeline[i];
      currentLoadingKey = initializer.loadingKey;
      notifyListeners();

      // Um micro delay artificial para que os passos ultrarrápidos 
      // não passem em branco aos olhos do usuário (fluidez na barra).
      await Future.delayed(const Duration(milliseconds: 200));

      final result = await initializer.run();
      steps.add(BootStep(name: initializer.name, success: result.success, message: result.message));
      
      currentStep = i + 1;

      if (!result.success) {
        finalReport = EngineBootReport(steps);
        notifyListeners();
        return;
      }
    }

    // Garante que o usuário consiga ver a barra em 100% por um instante 
    // antes da tela disparar o pulso do "Proceed".
    await Future.delayed(const Duration(milliseconds: 350));
    
    finalReport = EngineBootReport(steps);
    isFinished = true;
    notifyListeners();
  }
}