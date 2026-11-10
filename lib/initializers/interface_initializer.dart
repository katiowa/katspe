import '../core/engine_context.dart';
import '../core/language_controller.dart';
import 'initializer_contract.dart';

class InterfaceInitializer implements InitializerContract {
  @override
  String get name => 'Interface';
  
  @override
  String get loadingKey => 'boot_step_interface';

  @override
  Future<InitializerResult> run() async {
    try {
      final ctx = EngineContext.instance;
      ctx.language = LanguageController(preferences: ctx.preferences);
      await ctx.language.init();

      final count = ctx.language.availableLanguages.length;
      if (count == 0) {
        return const InitializerResult.failure(
          'No language packs found under engine/languages — the shell has no strings to show.',
        );
      }
      final active = ctx.language.currentLanguage?.displayName ?? 'none';
      return InitializerResult.ok('$count language pack(s) found, "$active" active.');
    } catch (e) {
      return InitializerResult.failure('Could not load the interface language: $e');
    }
  }
}