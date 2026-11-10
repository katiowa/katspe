import 'package:flutter/widgets.dart';

import 'renders/button_render.dart';
import 'renders/column_render.dart';
import 'renders/dropdown_render.dart';
import 'renders/row_render.dart';
import 'renders/text_field_render.dart';
import 'renders/text_render.dart';
import 'renders/topbar_render.dart';

/// A render template turns a plain parameter bag into a [Widget]. Templates
/// carry no business logic — they only know "how to build", never "why" or
/// "when" it should appear. The "why"/"when" belongs to Plugins and
/// Converters, which is why this typedef takes nothing but data in and a
/// [Widget] out.
typedef RenderBuilder = Widget Function(Map<String, dynamic> params);

/// Central registry and dispatcher for every visual template the shell can
/// build.
///
/// Backed by a plain [Map] — an O(1) dispatch table — instead of an
/// if/else or switch chain, so registering a new template (including ones
/// contributed by a Plugin at boot) never touches this file. This is the
/// "cego e burro" Core in practice: `RenderService` has no idea what
/// `dashboard.open_button` looks like or does, it only knows how to look
/// the id up and call the function stored under it.
class RenderService {
  RenderService._();
  static final RenderService instance = RenderService._();

  final Map<String, RenderBuilder> _templates = {};

  int get registeredCount => _templates.length;

  /// Registers (or overwrites) a template under [id]. Plugins reach this
  /// through `RenderApi.registerTemplate` — nothing outside `render/` and
  /// `api/` should touch this map directly.
  void register(String id, RenderBuilder builder) {
    _templates[id] = builder;
  }

  bool has(String id) => _templates.containsKey(id);

  /// Builds the widget registered under [id]. Returns a zero-size box
  /// instead of throwing when [id] is unknown, so a Plugin- or
  /// Lua-driven UI request referencing a missing template degrades
  /// silently in production rather than crashing the whole shell.
  Widget build(String id, [Map<String, dynamic> params = const {}]) {
    final builder = _templates[id];
    if (builder == null) return const SizedBox.shrink();
    return builder(params);
  }

  /// Registers every template the Core ships with out of the box. Called
  /// exactly once, by [RenderInitializer], during boot.
  void registerBuiltIns() {
    register('core.button', buildButtonRender);
    register('core.topbar', buildTopbarRender);
    register('core.dropdown', buildDropdownRender);
    register('core.row', buildRowRender);
    register('core.column', buildColumnRender);
    register('core.text', buildTextRender);
    register('core.text_field', buildTextFieldRender);
  }
}
