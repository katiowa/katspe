import 'package:flutter/widgets.dart';

import '../../render/main.dart';

/// The only door Plugins and Converters use to reach the renderer.
///
/// Never import `render/main.dart` directly from outside `api/` — going
/// through here is what keeps the Core "blind": it doesn't know which
/// Plugin asked for a button, only that something asked for `core.button`.
class RenderApi {
  const RenderApi();

  int get exposedFunctionCount => 3;

  /// Registers a new template a Plugin builds. [id] should be namespaced
  /// as `<plugin>.<name>` (e.g. `dashboard.open_button`) to avoid
  /// collisions with Core templates (`core.*`) or other Plugins.
  void registerTemplate(String id, RenderBuilder builder) {
    RenderService.instance.register(id, builder);
  }

  bool hasTemplate(String id) => RenderService.instance.has(id);

  /// Builds a widget from a registered template. This is the only
  /// function a Plugin needs in order to put anything on screen.
  Widget build(String templateId, [Map<String, dynamic> params = const {}]) {
    return RenderService.instance.build(templateId, params);
  }
}
