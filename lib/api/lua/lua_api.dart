import 'lua_converter_session.dart';

export 'lua_converter_session.dart' show LuaConverterSession;

/// Reference layer for the engine's one live connection to Lua: the
/// active converter's persistent session.
///
/// `LuaApi` holds no execution logic of its own. Activation, the
/// isolate/protocol plumbing, and every actual capability a converter
/// exposes (import, export, its UI, anything else) live in
/// [LuaConverterSession] and, from there on, entirely inside whichever
/// Lua code that converter's `main.lua` chose to register. This class
/// only tracks which session — if any — is currently active and
/// forwards to it. There is no default converter and no fallback
/// behavior here: activating is always an explicit call, matching an
/// explicit choice made elsewhere (see
/// `EngineStorageManager.resolveActiveConverter`).
class LuaApi {
  LuaConverterSession? _active;
  String? _activeConverterName;

  LuaConverterSession? get active => _active;

  /// Name of the converter [active] belongs to, or null if none is
  /// active. Lets callers avoid re-activating (spawning a fresh isolate)
  /// when the right converter is already running.
  String? get activeConverterName => _activeConverterName;

  /// Activates [converterName]'s session, disposing whatever was active
  /// before — unless it's already the one requested, in which case this
  /// is a no-op. [entryScript]/[converterRootPath] come from
  /// `EngineStorageManager.loadConverterEntryPoint` — this class doesn't
  /// know or care what's inside the script, only that it's the one
  /// thing to run.
  Future<void> activateConverter(String converterName, String entryScript, String converterRootPath) async {
    if (_activeConverterName == converterName && _active != null) return;
    _active?.dispose();
    _active = await LuaConverterSession.start(entryScript, converterRootPath);
    _activeConverterName = converterName;
  }

  void deactivateConverter() {
    _active?.dispose();
    _active = null;
    _activeConverterName = null;
  }
}
