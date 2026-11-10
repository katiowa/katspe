import 'package:flutter/material.dart';

import '../../core/language_controller.dart';
import '../../models/province.dart';
import '../../theme/app_theme.dart';

Future<Set<int>?> showOverlapConfirmDialog(
  BuildContext context,
  LanguageController langController,
  List<ProvinceModel> overlapping,
) async {
  Set<int> selectedToClip = {};
  bool proceed = false;
  bool ignoreClipping = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setModalState) {
        return AlertDialog(
          backgroundColor: AppTheme.bg2,
          title: Text(langController.get('dialog_overlap_title'), style: const TextStyle(color: AppTheme.textPrimary)),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(langController.get('dialog_overlap_desc'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: overlapping.map((p) => CheckboxListTile(
                      title: Text(langController.get('dialog_overlap_province').replaceAll('{id}', p.id.toString()), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                      value: selectedToClip.contains(p.id),
                      activeColor: AppTheme.accent,
                      onChanged: (v) => setModalState(() {
                        if (v == true) { selectedToClip.add(p.id); } else { selectedToClip.remove(p.id); }
                      }),
                    )).toList(),
                  )
                )
              ]
            )
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(langController.get('dialog_overlap_cancel'))),
            FilledButton.tonal(onPressed: () { proceed = true; ignoreClipping = true; Navigator.pop(ctx); }, child: Text(langController.get('dialog_overlap_ignore'))),
            FilledButton(onPressed: () { proceed = true; Navigator.pop(ctx); }, child: Text(langController.get('dialog_overlap_clip')))
          ]
        );
      }
    )
  );

  if (!proceed) return null;
  if (ignoreClipping) return {};
  return selectedToClip;
}
