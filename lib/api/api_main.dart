import 'lua/lua_api.dart';
import 'plugins/plugin_api.dart';
import 'render/render_api.dart';

/// Single entry point Plugins and the active Lua converter use to talk
/// to the engine.
///
/// `EngineApi` itself does no work — it only builds and exposes the
/// specialized sub-APIs living under `api/<area>/`. Adding a new area of
/// engine functionality means adding a new sub-API folder and one field
/// here, never adding business logic to this file. Notably absent: any
/// area named after a converter's domain concepts (POIs, or anything
/// else) — the engine has no such concept of its own. Whatever a
/// converter needs beyond rendering and its own Lua session, it builds
/// entirely on top of `render` and `lua`.
class EngineApi {
  late final RenderApi render;
  late final LuaApi lua;
  late final PluginApi plugins;

  int _exposedFunctionCount = 0;

  /// Total number of functions exposed across every sub-API — a cheap,
  /// human-readable signal for the boot report ("N functions indexed").
  int get exposedFunctionCount => _exposedFunctionCount;

  /// Builds and indexes every sub-API. Called once, by `ApiInitializer`,
  /// right after the Render layer registers its built-in templates.
  void indexAll() {
    render = const RenderApi();
    lua = LuaApi();
    plugins = PluginApi();
    _exposedFunctionCount = render.exposedFunctionCount + plugins.exposedFunctionCount;
  }
}
