import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:lua_dardo_plus/lua.dart';
import 'package:path/path.dart' as p;

import '../../engine/lua/lua_bindings.dart';
import '../../engine/lua/lua_type_converter.dart';

/// How long a single `invoke`/`render` round-trip gets before the caller
/// gives up on it. Matches the timeout the old one-shot Lua calls used —
/// a pure-Dart Lua interpreter has no OS-level watchdog of its own, so a
/// script that hangs (accidentally or not) has to be caught here.
const _callTimeout = Duration(seconds: 20);

/// How long session *startup* gets — much shorter, since activation only
/// has to run `main.lua` once, not do real work yet.
const _startupTimeout = Duration(seconds: 5);

/// Injected before every converter's own code. Generic request dispatch
/// only — this text never mentions import, export, or POIs. It gives a
/// converter's `main.lua` two things: a way to register named handlers
/// and UI-render slots (`EngineAPI.register_handler` /
/// `EngineAPI.register_ui_slot`), and it gives this Dart session a
/// uniform way to call into whichever ones got registered
/// (`__engine_invoke` / `__engine_render`) without ever knowing their
/// names in advance.
const _sessionRuntimePrelude = '''
local _handlers = {}
local _ui_slots = {}

function EngineAPI.register_handler(name, fn)
    _handlers[name] = fn
end

function EngineAPI.register_ui_slot(name, fn)
    _ui_slots[name] = fn
end

function __engine_invoke(name, args)
    local fn = _handlers[name]
    if fn == nil then return nil end
    return fn(args)
end

function __engine_render(name, ctx)
    local fn = _ui_slots[name]
    if fn == nil then return nil end
    return fn(ctx)
end
''';

/// One persistent, sandboxed Lua VM, alive for as long as one converter
/// is active.
///
/// This is the ENTIRE interface the engine has to a converter: activate
/// it once with its entry script, then only ever [invoke] a named
/// handler or [render] a named UI slot. Nothing here — or anywhere that
/// calls this class — knows what handlers or slots a given converter
/// actually registers. That's 100% the converter's `main.lua`'s
/// business, decided entirely in Lua.
class LuaConverterSession {
  final Isolate _isolate;
  final ReceivePort _fromIsolate;
  SendPort? _toIsolate;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  int _nextId = 0;
  bool _disposed = false;

  LuaConverterSession._(this._isolate, this._fromIsolate);

  /// Starts a new session and runs [entryScript] (expected to be
  /// `core.lua` + the converter's `main.lua`, concatenated by the
  /// caller) once inside it. [converterRootPath] scopes the one file-
  /// system capability this session gets — reading a text file relative
  /// to its own converter folder, so `main.lua` can pull in its own
  /// sibling files (e.g. its own `scripts/import.lua`) without Dart ever
  /// needing to know those files exist.
  static Future<LuaConverterSession> start(String entryScript, String converterRootPath) async {
    final fromIsolate = ReceivePort();
    final errorPort = ReceivePort();

    final isolate = await Isolate.spawn(
      _sessionIsolateEntry,
      fromIsolate.sendPort,
      onError: errorPort.sendPort,
      errorsAreFatal: false,
    );

    final session = LuaConverterSession._(isolate, fromIsolate);
    final readyCompleter = Completer<void>();

    fromIsolate.listen((raw) {
      if (session._toIsolate == null && raw is SendPort) {
        session._toIsolate = raw;
        if (!readyCompleter.isCompleted) readyCompleter.complete();
        return;
      }
      session._onMessage(raw);
    });

    errorPort.listen((_) {
      // A truly uncaught error escaped the isolate (a framework-level
      // problem, not a Lua error — those are already caught and sent
      // back as {ok:false} replies). Treat the session as dead rather
      // than leaving every pending caller hanging forever.
      session._disposed = true;
      for (final c in session._pending.values) {
        if (!c.isCompleted) c.completeError(Exception('Converter session crashed unexpectedly.'));
      }
      session._pending.clear();
    });

    await readyCompleter.future.timeout(
      _startupTimeout,
      onTimeout: () {
        isolate.kill(priority: Isolate.immediate);
        throw TimeoutException('The converter session did not start.');
      },
    );

    await session._send({'cmd': 'activate', 'script': entryScript, 'root': converterRootPath});
    return session;
  }

  /// Calls the handler the converter registered under [handler] via
  /// `EngineAPI.register_handler`, with [args] passed through as-is.
  /// Returns whatever it returned, or null if nothing was registered
  /// under that name — a converter that doesn't support a given action
  /// (e.g. it never registered `"export"`) simply produces no result;
  /// callers decide what that means, this layer doesn't guess.
  ///
  /// The result is always expected as a table (a Dart `Map` once
  /// converted) — a handler whose natural result is a single value (a
  /// plain string, say) wraps it under a key of its own choosing, e.g.
  /// `return { text = encode_map(data) }`, the same way `aoh2/main.lua`
  /// does for `"export"`. A bare non-table return is treated the same
  /// as "nothing registered" (null), rather than silently guessing which
  /// key the caller meant.
  Future<Map<String, dynamic>?> invoke(String handler, [Map<String, dynamic> args = const {}]) async {
    final reply = await _send({'cmd': 'invoke', 'handler': handler, 'args': args});
    final result = reply['result'];
    return result is Map ? result.cast<String, dynamic>() : null;
  }

  /// Calls the UI-building function the converter registered under
  /// [slot] via `EngineAPI.register_ui_slot`, with [context] passed
  /// through. Returns the descriptor tree it built, or null if nothing
  /// is registered for that slot.
  Future<Map<String, dynamic>?> render(String slot, [Map<String, dynamic> context = const {}]) async {
    final reply = await _send({'cmd': 'render', 'slot': slot, 'context': context});
    final tree = reply['tree'];
    return tree is Map ? tree.cast<String, dynamic>() : null;
  }

  Future<Map<String, dynamic>> _send(Map<String, dynamic> message) {
    if (_disposed) return Future.error(StateError('Converter session is no longer active.'));
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _toIsolate!.send({...message, 'id': id});
    return completer.future.timeout(
      _callTimeout,
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException('Converter did not respond in time.');
      },
    );
  }

  void _onMessage(dynamic raw) {
    if (raw is! Map) return;
    final completer = _pending.remove(raw['id']);
    if (completer == null) return;
    if (raw['ok'] == true) {
      completer.complete(raw.cast<String, dynamic>());
    } else {
      completer.completeError(Exception(raw['error']?.toString() ?? 'Unknown converter error.'));
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _toIsolate?.send({'cmd': 'dispose', 'id': -1});
    _isolate.kill(priority: Isolate.immediate);
    _fromIsolate.close();
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(StateError('Converter session disposed.'));
    }
    _pending.clear();
  }
}

void _sessionIsolateEntry(SendPort mainSendPort) {
  final commandPort = ReceivePort();
  mainSendPort.send(commandPort.sendPort);

  LuaState? ls;

  commandPort.listen((raw) {
    final message = (raw as Map).cast<String, dynamic>();
    final id = message['id'];

    try {
      switch (message['cmd'] as String) {
        case 'activate':
          ls = LuaState.newState();
          ls!.openLibs();
          registerEngineApi(ls!);
          _registerReadTextFile(ls!, message['root'] as String);

          final fullScript = '$_sessionRuntimePrelude\n${message['script'] as String}';
          final loadStatus = ls!.loadString(fullScript);
          if (loadStatus != ThreadStatus.luaOk) {
            mainSendPort.send({'id': id, 'ok': false, 'error': ls!.toStr(-1) ?? 'Failed to load converter script.'});
            return;
          }
          final initStatus = ls!.pCall(0, 0, 0);
          if (initStatus != ThreadStatus.luaOk) {
            mainSendPort.send({'id': id, 'ok': false, 'error': ls!.toStr(-1) ?? 'Failed to initialize converter script.'});
            return;
          }
          mainSendPort.send({'id': id, 'ok': true});
          break;

        case 'invoke':
          final result = _dispatch(
            ls!,
            '__engine_invoke',
            message['handler'] as String,
            (message['args'] as Map).cast<String, dynamic>(),
          );
          mainSendPort.send({'id': id, 'ok': true, 'result': result});
          break;

        case 'render':
          final result = _dispatch(
            ls!,
            '__engine_render',
            message['slot'] as String,
            (message['context'] as Map).cast<String, dynamic>(),
          );
          mainSendPort.send({'id': id, 'ok': true, 'tree': result});
          break;

        case 'dispose':
          Isolate.current.kill(priority: Isolate.immediate);
          break;

        default:
          mainSendPort.send({'id': id, 'ok': false, 'error': 'Unknown session command.'});
      }
    } catch (e) {
      mainSendPort.send({'id': id, 'ok': false, 'error': e.toString()});
    }
  });
}

dynamic _dispatch(LuaState ls, String dispatchFnName, String name, Map<String, dynamic> args) {
  ls.getGlobal(dispatchFnName);
  ls.pushString(name);
  dartToLuaValue(ls, args);
  final status = ls.pCall(2, 1, 0);
  if (status != ThreadStatus.luaOk) {
    throw Exception(ls.toStr(-1) ?? 'Converter script raised an error.');
  }
  return luaValueToDart(ls, -1);
}

/// Adds one more function to the `EngineAPI` table on top of whatever
/// `registerEngineApi` already put there: a text-file reader scoped to
/// this one converter's own folder ([converterRootPath]). This is what
/// lets a converter's `main.lua` pull in its own sibling files (its own
/// `scripts/import.lua`, its own data files, however it wants to
/// organize itself) without Dart ever needing to know those files exist
/// or what they're called — Dart only ever provides "read a relative
/// path inside your own folder", never anything action-specific.
///
/// Deliberately rejects absolute paths and `..` segments — a converter
/// reads its own files, never anything else on disk.
void _registerReadTextFile(LuaState ls, String converterRootPath) {
  ls.getGlobal('EngineAPI');
  ls.pushDartFunction((LuaState state) {
    final relPath = state.checkString(1) ?? '';
    final normalized = p.normalize(relPath);
    if (p.isAbsolute(normalized) || normalized.startsWith('..')) {
      state.pushNil();
      return 1;
    }
    final file = File(p.join(converterRootPath, normalized));
    if (!file.existsSync()) {
      state.pushNil();
      return 1;
    }
    var text = file.readAsStringSync();
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    state.pushString(text);
    return 1;
  });
  ls.setField(-2, 'read_text_file');
  ls.pop(1);
}
