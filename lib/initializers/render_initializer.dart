import '../render/main.dart';
import 'initializer_contract.dart';

class RenderInitializer implements InitializerContract {
  @override
  String get name => 'Render';
  
  @override
  String get loadingKey => 'boot_step_render';

  @override
  Future<InitializerResult> run() async {
    try {
      RenderService.instance.registerBuiltIns();
      return InitializerResult.ok(
        '${RenderService.instance.registeredCount} built-in template(s) registered.',
      );
    } catch (e) {
      return InitializerResult.failure('Could not register built-in render templates: $e');
    }
  }
}