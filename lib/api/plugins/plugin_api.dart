import '../../plugins/plugin_manifest.dart';

/// Read-only view of which Plugins are loaded and in what boot order.
///
/// Populated by [PluginManager] as each plugin finishes booting, and
/// consumed by anything that wants to introspect the running engine (for
/// example, a Dashboard plugin listing active mods) without depending on
/// `PluginManager` internals directly.
class PluginApi {
  final List<PluginManifest> _loaded = [];

  int get exposedFunctionCount => 2;

  List<PluginManifest> get loaded => List.unmodifiable(_loaded);

  void registerLoaded(PluginManifest manifest) => _loaded.add(manifest);

  bool isLoaded(String id) => _loaded.any((m) => m.id == id);
}
