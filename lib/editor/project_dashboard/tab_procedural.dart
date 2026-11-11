import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/language_controller.dart';
import '../../theme/app_theme.dart';

class TabProcedural extends StatefulWidget {
  final LanguageController lang;
  final bool isNarrow;
  const TabProcedural({super.key, required this.lang, this.isNarrow = false});

  @override
  State<TabProcedural> createState() => _TabProceduralState();
}

class _TabProceduralState extends State<TabProcedural> {
  bool _consentGiven = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(widget.isNarrow ? 14.0 : 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_fix_high, color: AppTheme.accent, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.lang.get('opengs_title'), 
                  style: TextStyle(
                    color: AppTheme.textPrimary, 
                    fontSize: widget.isNarrow ? 18 : 22, 
                    fontWeight: FontWeight.bold
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              primary: false,
              child: Text(
                widget.lang.get('opengs_desc'), 
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)
              ),
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: AppTheme.bg3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              side: BorderSide(color: _consentGiven ? AppTheme.accent : AppTheme.border),
            ),
            child: CheckboxListTile(
              title: Text(widget.lang.get('opengs_consent'), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
              value: _consentGiven, 
              activeColor: AppTheme.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
              onChanged: (val) => setState(() => _consentGiven = val ?? false),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.bottomRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _consentGiven ? AppTheme.success : AppTheme.bg3, 
                foregroundColor: _consentGiven ? AppTheme.bg0 : AppTheme.textDisabled, 
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
              ),
              onPressed: _consentGiven ? () async {
                final url = Uri.parse('https://github.com/Thomas-Holtvedt/opengs-maptool');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              } : null,
              icon: const Icon(Icons.open_in_new, size: 16), 
              label: Text(widget.lang.get('opengs_btn'), style: const TextStyle(fontSize: 12)),
            ),
          )
        ],
      ),
    );
  }
}