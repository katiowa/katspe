import '../api/api_main.dart';
import '../initializers/initializer_contract.dart';

/// Contract every Plugin implements.
///
/// The Core only ever talks to plugins through this interface — it never
/// imports a concrete plugin class beyond the single registration line in
/// [PluginManager], and a plugin never imports another plugin's
/// implementation. All real logic and UI actions for that plugin's slice
/// of the app live behind [onBoot].
abstract class PluginContract {
  /// Must match the `id` declared in this plugin's `plugin.json`.
  String get id;

  /// Asset path to the bundled manifest, e.g. `plugins/dashboard/plugin.json`.
  String get manifestAssetPath;

  /// Runs once during boot, in priority order. Plugins register their
  /// templates, tools and event handlers through [api] here — they never
  /// reach into the renderer or into another plugin directly.
  Future<InitializerResult> onBoot(EngineApi api);
}
