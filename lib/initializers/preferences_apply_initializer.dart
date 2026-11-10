import '../core/engine_context.dart';
import 'initializer_contract.dart';

class PreferencesApplyInitializer implements InitializerContract {
  @override
  String get name => 'Preferences';
  
  @override
  String get loadingKey => 'boot_step_prefs';

  @override
  Future<InitializerResult> run() async {
    try {
      final prefs = EngineContext.instance.preferences;
      final cullingEnabled = prefs.cullingEnabled ?? true;
      final cullingMargin = prefs.cullingMargin ?? 0.0;
      final converter = prefs.selectedConverter ?? 'none';
      return InitializerResult.ok(
        'Culling ${cullingEnabled ? 'on' : 'off'} (margin $cullingMargin), '
        'selected converter "$converter".',
      );
    } catch (e) {
      return InitializerResult.failure('Could not apply global preferences: $e');
    }
  }
}