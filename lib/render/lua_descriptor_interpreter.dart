import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../engine/engine_storage.dart';
import '../api/lua/lua_value_utils.dart';
import 'main.dart';

/// Called when a rendered node's action fires (a button tap, a field
/// submit). [staticArgs] is whatever the descriptor node declared under
/// `args`; the caller (see `LuaRenderedPanel`) merges in any locally
/// tracked text-field values before actually invoking Lua.
typedef LuaAction = void Function(String handlerName, Map<String, dynamic> staticArgs);

/// Turns a descriptor tree returned by a converter's `render()` call
/// (see `LuaConverterSession.render`) into real Flutter widgets.
///
/// This is the ONLY place a Lua descriptor ever becomes a [Widget] —
/// nothing else in the Core interprets this shape. It resolves each
/// node's `type` through the exact same dispatch table Plugins already
/// use ([RenderService]): `type: "button"` builds through `core.button`,
/// the same template `plugins/packages/dashboard` composes with. Lua
/// authors get the same visual vocabulary Plugins get, because it's
/// literally the same templates.
///
/// Descriptor shape: `{type, ...props, args: {...}, children: [descriptor, ...]}`.
/// A bare `type` (no dot, e.g. `"button"`) resolves to a Core template
/// (`"core.button"`); a dotted id is used as-is. `onTap`/`onSubmit` name
/// a handler [LuaAction] calls when triggered, together with whatever
/// static `args` the node declared.
///
/// **Text input is the one deliberate exception to "everything goes
/// through Lua":** a `text_field` node's live value is never wired to
/// [onAction] — reporting every keystroke would mean an isolate
/// round-trip per key pressed. Instead its `key` names a
/// [TextEditingController] tracked in [fieldControllers] (supplied by
/// the caller and shared across the whole tree), which the caller reads
/// from at the moment any button fires — see `LuaRenderedPanel`.
///
/// A `file_picker_button` node is the other exception: opening a native
/// OS file dialog isn't something any Core render template can do (it
/// needs a real platform plugin), so this interpreter special-cases it
/// instead of resolving it through [RenderService].
Widget buildLuaDescriptor(
  Map<String, dynamic> descriptor,
  LuaAction onAction, {
  Map<String, TextEditingController>? fieldControllers,
  EngineStorageManager? storage,
}) {
  final rawType = descriptor['type']?.toString() ?? 'column';
  final params = Map<String, dynamic>.from(descriptor)..remove('type');
  final staticArgs = (params['args'] as Map?)?.cast<String, dynamic>() ?? const {};

  if (rawType == 'file_picker_button') {
    return _LuaFilePickerButton(
      label: params['label']?.toString() ?? 'Add file',
      extensions: params['extensions'] == null
          ? null
          : asLuaList(params['extensions']).map((e) => e.toString()).toList(),
      multiple: params['multiple'] as bool? ?? true,
      onPicked: params['onPicked']?.toString(),
      staticArgs: staticArgs,
      storage: storage,
      onAction: onAction,
    );
  }

  if (rawType == 'text_field' && fieldControllers != null) {
    final key = params['key']?.toString();
    if (key != null) {
      final controller = fieldControllers.putIfAbsent(
        key,
        () => TextEditingController(text: params['value']?.toString() ?? ''),
      );
      params['controller'] = controller;
    }
  }

  final childrenRaw = params.remove('children');
  if (childrenRaw is List) {
    params['children'] = [
      for (final child in childrenRaw.whereType<Map>())
        buildLuaDescriptor(
          child.cast<String, dynamic>(),
          onAction,
          fieldControllers: fieldControllers,
          storage: storage,
        ),
    ];
  }

  for (final key in const ['onTap', 'onSubmit']) {
    final handlerName = params[key];
    if (handlerName is String) {
      params[key] = () => onAction(handlerName, staticArgs);
    }
  }
  // A button's "tap" is the generic, Lua-facing name for this action;
  // the Core template underneath is a plain Flutter button and calls it
  // `onPressed` — translated here so a Lua author only ever needs to
  // know the generic descriptor vocabulary, never Flutter's own names.
  if (rawType == 'button' && params.containsKey('onTap')) {
    params['onPressed'] = params.remove('onTap');
  }

  final templateId = rawType.contains('.') ? rawType : 'core.$rawType';
  return RenderService.instance.build(templateId, params);
}

class _LuaFilePickerButton extends StatelessWidget {
  final String label;
  final List<String>? extensions;
  final bool multiple;
  final String? onPicked;
  final Map<String, dynamic> staticArgs;
  final EngineStorageManager? storage;
  final LuaAction onAction;

  const _LuaFilePickerButton({
    required this.label,
    required this.extensions,
    required this.multiple,
    required this.onPicked,
    required this.staticArgs,
    required this.storage,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return RenderService.instance.build('core.button', {
      'label': label,
      'onPressed': onPicked == null ? null : _pick,
    });
  }

  Future<void> _pick() async {
    List<PlatformFile> files;
    
    if (multiple) {
      files = await FilePicker.pickFiles(
        type: extensions == null ? FileType.any : FileType.custom,
        allowedExtensions: extensions,
      );
    } else {
      final file = await FilePicker.pickFile(
        type: extensions == null ? FileType.any : FileType.custom,
        allowedExtensions: extensions,
      );
      files = file != null ? [file] : [];
    }
    
    if (files.isEmpty) return;

    for (final file in files) {
      final pickedPath = file.path;
      if (pickedPath == null) continue;
      try {
        var readPath = pickedPath;
        if (storage != null) {
          final cloned = await storage!.cloneImportedFile(pickedPath);
          if (cloned != null) readPath = cloned;
        }
        
        // Remove Byte Order Mark (BOM) invisível que quebra o parse json no Lua
        var text = await File(readPath).readAsString();
        text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        if (text.startsWith('\uFEFF')) text = text.substring(1);
        
        onAction(onPicked!, {...staticArgs, 'raw_text': text, 'file_name': p.basename(readPath)});
      } catch (_) {
        // One unreadable file shouldn't stop the rest of the batch.
      }
    }
  }
}