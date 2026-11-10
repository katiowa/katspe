part of '../top_bar.dart';

extension _PropCardExtension on TopBar {
  Widget _buildPropCard(PropModel prop, ui.Image? img) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        backgroundColor: AppTheme.bg2,
        collapsedBackgroundColor: AppTheme.bg2,
        iconColor: AppTheme.accent,
        collapsedIconColor: AppTheme.textSecondary,
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.bg1,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.border),
              ),
              clipBehavior: Clip.hardEdge,
              child: img != null
                  ? RawImage(image: img, fit: BoxFit.cover)
                  : const Icon(Icons.image, color: AppTheme.textDisabled, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(prop.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ),
            IconButton(
              icon: Icon(prop.isVisible ? Icons.visibility : Icons.visibility_off, size: 18),
              color: prop.isVisible ? AppTheme.accent : AppTheme.textDisabled,
              tooltip: prop.isVisible ? lang.get('prop_visibility_hide') : lang.get('prop_visibility_show'),
              onPressed: () {
                final isVis = !prop.isVisible;
                propsController.recordSnapshot();
                propsController.updateProp(prop.copyWith(
                  isVisible: isVis,
                  isLocked: isVis ? prop.isLocked : true,
                ));
              },
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: prop.isLocked ? AppTheme.success : AppTheme.danger, width: 1.5),
              ),
              child: IconButton(
                icon: Icon(prop.isLocked ? Icons.lock : Icons.lock_open, size: 14),
                color: prop.isLocked ? AppTheme.success : AppTheme.danger,
                tooltip: prop.isLocked ? lang.get('prop_lock') : lang.get('prop_unlock'),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                padding: EdgeInsets.zero,
                onPressed: () {
                  propsController.recordSnapshot();
                  propsController.updateProp(prop.copyWith(isLocked: !prop.isLocked));
                },
              ),
            ),
          ],
        ),
        children: [
          Row(
            children: [
              Text(lang.get('prop_opacity'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              Expanded(
                child: Slider(
                  value: prop.opacity,
                  min: 0.0, max: 1.0,
                  activeColor: AppTheme.accent,
                  onChanged: (v) => propsController.updateProp(prop.copyWith(opacity: v), saveToDisk: false),
                  onChangeEnd: (v) {
                    propsController.recordSnapshot();
                    propsController.updateProp(prop.copyWith(opacity: v), saveToDisk: true);
                  },
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(lang.get('prop_angle'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                const SizedBox(width: 12),
                _PropAngleControl(
                  prop: prop,
                  propsController: propsController,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Opacity(
                opacity: prop.isDeforming ? 0.4 : 1.0,
                child: IgnorePointer(
                  ignoring: prop.isDeforming,
                  child: Row(
                    children: [
                      Switch(
                        value: prop.keepAspectRatio,
                        activeThumbColor: AppTheme.accent,
                        onChanged: (v) {
                          propsController.recordSnapshot();
                          propsController.updateProp(prop.copyWith(keepAspectRatio: v));
                        },
                      ),
                      Text(lang.get('prop_aspect_ratio'), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Switch(
                    value: prop.isDeforming,
                    activeThumbColor: AppTheme.info,
                    onChanged: (v) {
                      propsController.recordSnapshot();
                      var newProp = prop.copyWith(isDeforming: v);
                      if (!v) {
                        newProp = newProp.copyWith(mesh: PropModel.generateMesh(newProp.corners, newProp.divisions, newProp.distance));
                      }
                      propsController.updateProp(newProp);
                    },
                  ),
                  Text(lang.get('prop_deform'), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
                ],
              ),
            ],
          ),

          if (prop.isDeforming) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.bg1,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(lang.get('prop_divisions'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      Expanded(
                        child: Slider(
                          value: prop.divisions.toDouble(),
                          min: 1, max: 5, divisions: 4,
                          activeColor: AppTheme.info,
                          label: prop.divisions.toString(),
                          onChanged: (v) {
                            final newDivs = v.toInt();
                            final newMesh = PropModel.generateMesh(prop.corners, newDivs, prop.distance);
                            propsController.updateProp(prop.copyWith(divisions: newDivs, mesh: newMesh), saveToDisk: false);
                          },
                          onChangeEnd: (v) {
                            propsController.recordSnapshot();
                            final newDivs = v.toInt();
                            final newMesh = PropModel.generateMesh(prop.corners, newDivs, prop.distance);
                            propsController.updateProp(prop.copyWith(divisions: newDivs, mesh: newMesh), saveToDisk: true);
                          },
                        ),
                      ),
                      Text('${prop.divisions}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      Text(lang.get('prop_distance'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                      Expanded(
                        child: Slider(
                          value: prop.distance,
                          min: 0.1, max: 2.0,
                          activeColor: AppTheme.info,
                          onChanged: (v) {
                            final newMesh = PropModel.generateMesh(prop.corners, prop.divisions, v);
                            propsController.updateProp(prop.copyWith(distance: v, mesh: newMesh), saveToDisk: false);
                          },
                          onChangeEnd: (v) {
                            propsController.recordSnapshot();
                            final newMesh = PropModel.generateMesh(prop.corners, prop.divisions, v);
                            propsController.updateProp(prop.copyWith(distance: v, mesh: newMesh), saveToDisk: true);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger.withValues(alpha: 0.2), foregroundColor: AppTheme.danger),
              onPressed: () => propsController.removeProp(prop.id),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: Text(lang.get('prop_delete')),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              lang.get('prop_delete_hint'),
              style: const TextStyle(color: AppTheme.textDisabled, fontSize: 10, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}