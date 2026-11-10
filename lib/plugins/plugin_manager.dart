import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../api/api_main.dart';
import '../initializers/initializer_contract.dart';
import 'packages/dashboard/main.dart';
import 'plugin_contract.dart';
import 'plugin_manifest.dart';

/// Loads every registered Plugin's `plugin.json`, sorts by priority
/// (ascending — closer to 0 boots first) and runs `onBoot` in that order.
///
/// `plugin_contract.dart`, `plugin_manifest.dart` and this file are the
/// Core's plugin *infrastructure* — they define and enforce the contract.
/// The actual plugin packages themselves live one level deeper, under
/// `plugins/packages/<name>/`, so the two are never ambiguous: nothing
/// under `packages/` is a manager, and nothing outside `packages/` is a
/// plugin.
///
/// Dart/Flutter has no dynamic module loading: every plugin class listed
/// in [_registry] must be compiled into the app. What IS data-driven is
/// each plugin's `priority`, read from its own bundled `plugin.json` — a
/// new priority value there reorders the boot sequence with no rebuild of
/// the plugin's Dart logic.
class PluginManager {
  /// The compiled set of plugins this build ships with. Registering a new
  /// Dart plugin means adding one line here — nothing else in the Core
  /// changes.
  static final List<PluginContract> _registry = [
    DashboardPlugin(),
  ];

  final EngineApi api;
  PluginManager({required this.api});

  Future<InitializerResult> bootAll() async {
    final withManifests = <(PluginContract, PluginManifest)>[];

    for (final plugin in _registry) {
      try {
        final raw = await rootBundle.loadString(plugin.manifestAssetPath);
        final manifest = PluginManifest.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        withManifests.add((plugin, manifest));
      } catch (e) {
        return InitializerResult.failure('Plugin "${plugin.id}" has no readable plugin.json: $e');
      }
    }

    withManifests.sort((a, b) => a.$2.priority.compareTo(b.$2.priority));

    for (final entry in withManifests) {
      final (plugin, manifest) = entry;
      final result = await plugin.onBoot(api);
      if (!result.success) {
        return InitializerResult.failure('Plugin "${manifest.id}" failed to boot: ${result.message}');
      }
      api.plugins.registerLoaded(manifest);
    }

    return InitializerResult.ok('${withManifests.length} plugin(s) booted.');
  }
}
