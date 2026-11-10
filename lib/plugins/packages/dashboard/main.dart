import 'package:flutter/material.dart';

import '../../../api/api_main.dart';
import '../../../initializers/initializer_contract.dart';
import '../../plugin_contract.dart';

/// Example Plugin: contributes a single topbar button template.
///
/// This is intentionally the whole plugin. Real business logic — what
/// happens when the button is pressed, what dialog it opens — belongs to
/// whichever Plugin owns that feature; the Core never sees it, it only
/// renders whatever template got registered under
/// `dashboard.open_button`.
class DashboardPlugin implements PluginContract {
  @override
  String get id => 'dashboard';

  @override
  String get manifestAssetPath => 'lib/plugins/packages/dashboard/plugin.json';

  @override
  Future<InitializerResult> onBoot(EngineApi api) async {
    api.render.registerTemplate(
      'dashboard.open_button',
      (params) => api.render.build('core.button', {
        'label': params['label'] as String? ?? 'Dashboard',
        'icon': Icons.dashboard_outlined,
        'tooltip': params['tooltip'] as String?,
        'onPressed': params['onPressed'],
      }),
    );
    return const InitializerResult.ok('Registered the "dashboard.open_button" template.');
  }
}
