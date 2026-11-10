import '../core/engine_context.dart';
import '../plugins/plugin_manager.dart';
import 'initializer_contract.dart';

class PluginInitializer implements InitializerContract {
  @override
  String get name => 'Plugins';
  
  @override
  String get loadingKey => 'boot_step_plugins';

  @override
  Future<InitializerResult> run() async {
    try {
      final ctx = EngineContext.instance;
      ctx.plugins = PluginManager(api: ctx.api);
      return await ctx.plugins.bootAll();
    } catch (e) {
      return InitializerResult.failure('Plugin boot pipeline crashed: $e');
    }
  }
}