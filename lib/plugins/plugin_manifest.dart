/// Static metadata every plugin ships in its own `plugin.json`, bundled as
/// a Flutter asset at `plugins/<folder>/plugin.json`.
///
/// Kept as plain data — never code — so a plugin's boot priority can be
/// inspected, and eventually edited by the user, without recompiling the
/// engine. This is the piece of the plugin contract the architecture asks
/// to be JSON-driven ("a forma como tu vai salvar o número... pode ser
/// json").
class PluginManifest {
  final String id;
  final String displayName;

  /// Boot priority. A compact signed-byte range (-128..127): the closer
  /// to 0, the earlier the plugin boots. Values outside the range are
  /// clamped defensively — a malformed `plugin.json` should never crash
  /// the boot sequence.
  final int priority;

  const PluginManifest({
    required this.id,
    required this.displayName,
    required this.priority,
  });

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    final rawPriority = (json['priority'] as num?)?.toInt() ?? 0;
    return PluginManifest(
      id: json['id']?.toString() ?? 'unknown',
      displayName: json['displayName']?.toString() ?? json['id']?.toString() ?? 'Unknown',
      priority: rawPriority.clamp(-128, 127),
    );
  }
}
