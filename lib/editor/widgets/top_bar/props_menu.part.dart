part of '../top_bar.dart';

extension _PropsMenuExtension on TopBar {
  Widget _buildPropsMenu(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(AppTheme.bg2),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: const BorderSide(color: AppTheme.border),
          ),
        ),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
      ),
      builder: (context, controller, child) {
        return Tooltip(
          message: lang.get('topbar_props_menu'),
          child: IconButton(
            icon: const Icon(Icons.photo_size_select_large, size: 18, color: AppTheme.textPrimary), 
            onPressed: () { 
              if (controller.isOpen) { 
                controller.close(); 
              } else { 
                controller.open(); 
              } 
            },
          ),
        );
      },
      menuChildren: [
        SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onImportProp,
                    icon: const Icon(Icons.add_photo_alternate, size: 16),
                    label: Text(lang.get('prop_import_btn')),
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.bg3),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: propsController,
                builder: (context, _) {
                  if (propsController.props.isEmpty) return const SizedBox.shrink();
                  
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Divider(height: 1, color: AppTheme.border),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 450),
                        child: SingleChildScrollView(
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (int index = 0; index < propsController.props.length; index++)
                                  Builder(
                                    builder: (context) {
                                      final prop = propsController.props[propsController.props.length - 1 - index];
                                      final img = propsController.getImage(prop.id);
                                      return _buildPropCard(prop, img);
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}