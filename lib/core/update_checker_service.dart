import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import 'language_controller.dart';
import '../theme/app_theme.dart';

class UpdateCheckerService {
  // CHANGE TO FALSE TO DEACTIVE THE FORCED UPDATE APPEARENCE.
  static const bool _forceTest = false;

  static const String _remoteUrl = 'https://raw.githubusercontent.com/katiowa/katspe/main/version.json';
  static final Uri _releasesUri = Uri.parse('https://github.com/katiowa/katspe/releases');

  static Future<void> checkForUpdates(BuildContext context, LanguageController lang) async {
    // 0. Curto-circuito para teste imediato de UI
    if (_forceTest) {
      if (context.mounted) {
        _showUpdateDialog(context, lang, 'Beta 0.0.0 (Teste)', 'Beta 0.0.1');
      }
      return;
    }

    try {
      // 1. Checa internet primeiro. Falha silenciosamente se estiver offline.
      if (!await _hasInternet()) return;

      // 2. Lê a versão local do bundle.
      final localJsonStr = await rootBundle.loadString('version.json');
      final localVersion = jsonDecode(localJsonStr)['versionName']?.toString();
      if (localVersion == null || localVersion.isEmpty) return;

      // 3. Busca a versão remota (Timeout estrito de 3s).
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(Uri.parse(_remoteUrl));
      final response = await request.close();
      
      if (response.statusCode != 200) return;
      
      final responseBody = await response.transform(utf8.decoder).join();
      final remoteVersion = jsonDecode(responseBody)['versionName']?.toString();

      // 4. Compara e exibe o modal
      if (remoteVersion != null && remoteVersion.isNotEmpty && localVersion != remoteVersion) {
        if (context.mounted) {
          _showUpdateDialog(context, lang, localVersion, remoteVersion);
        }
      }
    } catch (_) {
      // Ignora falhas de rede, parse ou ausência de arquivo sem estourar logs.
    }
  }

  static Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('github.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  static void _showUpdateDialog(BuildContext context, LanguageController lang, String local, String remote) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.system_update_alt, color: AppTheme.info),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                lang.get('update_available_title'),
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Text(
            lang.get('update_available_desc').replaceAll('{local}', local).replaceAll('{remote}', remote),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(lang.get('btn_ignore')),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.info,
              foregroundColor: AppTheme.bg0,
            ),
            onPressed: () async {
              // CORREÇÃO DO CRASH: Fechar o modal PRIMEIRO, enquanto o app ainda
              // tem o foco total, antes de mandar o SO abrir o navegador externo.
              Navigator.of(ctx).pop(); 
              try {
                if (await canLaunchUrl(_releasesUri)) {
                  await launchUrl(_releasesUri, mode: LaunchMode.externalApplication);
                }
              } catch (_) {}
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(lang.get('btn_update')),
          )
        ],
      ),
    );
  }
}