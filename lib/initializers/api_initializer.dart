import '../api/api_main.dart';
import '../core/engine_context.dart';
import 'initializer_contract.dart';

class ApiInitializer implements InitializerContract {
  @override
  String get name => 'API';
  
  @override
  String get loadingKey => 'boot_step_api';

  @override
  Future<InitializerResult> run() async {
    try {
      final api = EngineApi()..indexAll();
      EngineContext.instance.api = api;
      return InitializerResult.ok(
        '${api.exposedFunctionCount} function(s) indexed across the render/lua/plugins sub-APIs.',
      );
    } catch (e) {
      return InitializerResult.failure('Could not index the API layer: $e');
    }
  }
}