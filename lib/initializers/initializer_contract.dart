/// Typed outcome of running a single boot [InitializerContract]. Every
/// initializer returns one of these instead of throwing or relying on side
/// effects, so `init.dart` can decide what to do next (continue, stop,
/// display a diagnostic) purely by inspecting data.
class InitializerResult {
  final bool success;
  final String message;

  const InitializerResult.ok([this.message = 'OK']) : success = true;
  const InitializerResult.failure(this.message) : success = false;

  @override
  String toString() => success ? 'OK: $message' : 'FAILED: $message';
}

/// Every specialized boot step (Storage, Interface, Render, API, Plugins,
/// Preferences, Converters) implements this contract. `init.dart` only
/// ever talks to a list of these — it never knows what a given stage does
/// internally, only whether it succeeded.
abstract class InitializerContract {
  /// Short, human-readable name used in the boot report.
  String get name;
  
  /// A chave que será buscada no LanguageController para exibir na tela de loading.
  String get loadingKey;

  /// Runs this boot stage. Must never throw: catch internally and return
  /// [InitializerResult.failure] with an explanatory message instead.
  Future<InitializerResult> run();
}