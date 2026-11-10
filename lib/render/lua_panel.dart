import 'package:flutter/material.dart';

import '../api/lua/lua_converter_session.dart';
import '../engine/engine_storage.dart';
import 'lua_descriptor_interpreter.dart';

/// A self-contained panel whose entire content — and behavior — comes
/// from one Lua UI slot (`EngineAPI.register_ui_slot`).
class LuaRenderedPanel extends StatefulWidget {
  final LuaConverterSession session;
  final String slot;
  final Map<String, dynamic> context;
  final EngineStorageManager? storage;
  final VoidCallback? onClose;
  final VoidCallback? onChanged;

  const LuaRenderedPanel({
    super.key,
    required this.session,
    required this.slot,
    this.context = const {},
    this.storage,
    this.onClose,
    this.onChanged,
  });

  @override
  State<LuaRenderedPanel> createState() => _LuaRenderedPanelState();
}

class _LuaRenderedPanelState extends State<LuaRenderedPanel> {
  Map<String, dynamic>? _tree;
  bool _loading = true;
  final Map<String, TextEditingController> _fieldControllers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LuaRenderedPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final tree = await widget.session.render(widget.slot, widget.context);
    if (!mounted) return;
    setState(() {
      _tree = tree;
      _loading = false;
    });
  }

  Future<void> _handleAction(String handlerName, Map<String, dynamic> staticArgs) async {
    // A Inversão de Autoridade: Se a Engine (Dart) atualizou o X/Y da POI pelo
    // arrasto na tela, esses valores "vivos" vão sobrescrever os argumentos
    // estáticos que o Lua tentou enviar. Isso impede que o Confirm faça a POI
    // teleportar de volta pra onde foi criada.
    final args = <String, dynamic>{
      ...staticArgs,
      if (widget.context.containsKey('x')) 'x': widget.context['x'],
      if (widget.context.containsKey('y')) 'y': widget.context['y'],
      for (final entry in _fieldControllers.entries) entry.key: entry.value.text,
    };

    final result = await widget.session.invoke(handlerName, args);
    widget.onChanged?.call();

    if (result?['close'] == true) {
      widget.onClose?.call();
      return;
    }

    final tree = await widget.session.render(widget.slot, widget.context);
    if (!mounted) return;
    setState(() => _tree = tree);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final tree = _tree;
    if (tree == null) return const SizedBox.shrink();

    return buildLuaDescriptor(
      tree,
      _handleAction,
      fieldControllers: _fieldControllers,
      storage: widget.storage,
    );
  }
}