import '../api/api_main.dart';
import '../engine/engine_config.dart';
import '../engine/engine_storage.dart';
import '../plugins/plugin_manager.dart';
import 'app_preferences.dart';
import 'language_controller.dart';

/// The engine's explicit composition root.
///
/// Each field is filled in by exactly one boot stage (see `init.dart`) and
/// is safe to read from any stage that runs after it. There is no hidden
/// global state anywhere else in the Core — if a service exists at
/// runtime, it lives here, and nothing outside `initializers/` ever
/// assigns to these fields.
class EngineContext {
  EngineContext._();
  static final EngineContext instance = EngineContext._();

  /// Set by [StorageInitializer].
  late final AppPreferences preferences;
  late final MapEngineConfig config;
  late final EngineStorageManager storage;

  /// Set by [InterfaceInitializer].
  late final LanguageController language;

  /// Set by [ApiInitializer].
  late final EngineApi api;

  /// Set by [PluginInitializer].
  late final PluginManager plugins;
}
