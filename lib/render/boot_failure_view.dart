import 'package:flutter/material.dart';

import '../init.dart';

/// Deliberately bypasses [RenderService]: if boot failed, the Core cannot
/// assume the render layer itself initialized correctly. This view is the
/// one piece of UI the shell is allowed to hardcode, precisely because it
/// exists to describe the case where nothing else can be trusted yet.
class EngineBootFailureScreen extends StatelessWidget {
  final EngineBootReport report;
  const EngineBootFailureScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1E24),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Engine failed to boot',
                  style: TextStyle(color: Color(0xFFE5484D), fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                for (final step in report.steps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${step.success ? 'OK  ' : 'FAIL'}  ${step.name}: ${step.message}',
                      style: TextStyle(
                        color: step.success ? const Color(0xFF63D471) : const Color(0xFFE5484D),
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
