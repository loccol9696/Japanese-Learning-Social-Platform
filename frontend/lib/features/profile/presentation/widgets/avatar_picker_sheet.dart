import 'package:flutter/material.dart';
import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/app_colors.dart';

class AvatarPickerSheet extends StatefulWidget {
  final String currentAvatarUrl;
  final ValueChanged<String> onAvatarSelected;

  const AvatarPickerSheet({
    super.key,
    required this.currentAvatarUrl,
    required this.onAvatarSelected,
  });

  static const List<_PresetAvatar> presets = [
    _PresetAvatar(
      id: 'sakura',
      name: 'Sakura Girl',
      url:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
    ),
    _PresetAvatar(
      id: 'kenji',
      name: 'Kenji Sensei',
      url:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=256&q=80',
    ),
    _PresetAvatar(
      id: 'yuki',
      name: 'Yuki Anime',
      url:
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=256&q=80',
    ),
    _PresetAvatar(
      id: 'daiki',
      name: 'Daiki Otaku',
      url:
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=256&q=80',
    ),
    _PresetAvatar(
      id: 'bot_kenji',
      name: 'Kenji Bot',
      url: 'https://api.dicebear.com/7.x/bottts/png?seed=Kenji',
    ),
    _PresetAvatar(
      id: 'bot_sakura',
      name: 'Sakura Bot',
      url: 'https://api.dicebear.com/7.x/bottts/png?seed=Sakura',
    ),
    _PresetAvatar(
      id: 'bot_tokyo',
      name: 'Tokyo Neon',
      url: 'https://api.dicebear.com/7.x/bottts/png?seed=Tokyo',
    ),
    _PresetAvatar(
      id: 'bot_shiba',
      name: 'Inu Shiba',
      url: 'https://api.dicebear.com/7.x/bottts/png?seed=Shiba',
    ),
  ];

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
  late String _selectedUrl;
  late final TextEditingController _customUrlController;

  @override
  void initState() {
    super.initState();
    _selectedUrl = widget.currentAvatarUrl;
    _customUrlController = TextEditingController(text: widget.currentAvatarUrl);
  }

  @override
  void dispose() {
    _customUrlController.dispose();
    super.dispose();
  }

  void _applySelection(String url) {
    setState(() {
      _selectedUrl = url;
      _customUrlController.text = url;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 16.0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44.0,
              height: 4.0,
              decoration: BoxDecoration(
                color: AppColors.softSkyBlue.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
          const SizedBox(height: 18.0),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                appStrings.choosePresetAvatar,
                style: const TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14.0),

          // Preset Avatars Grid
          SizedBox(
            height: 176.0,
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12.0,
                mainAxisSpacing: 12.0,
                childAspectRatio: 0.9,
              ),
              itemCount: AvatarPickerSheet.presets.length,
              itemBuilder: (context, index) {
                final preset = AvatarPickerSheet.presets[index];
                final isSelected = _selectedUrl == preset.url;

                return GestureDetector(
                  onTap: () => _applySelection(preset.url),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.periwinkle
                                : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.periwinkle
                                        .withValues(alpha: 0.5),
                                    blurRadius: 10.0,
                                  ),
                                ]
                              : null,
                        ),
                        child: CircleAvatar(
                          radius: 26.0,
                          backgroundColor: AppColors.surfaceCardSubtle,
                          backgroundImage: NetworkImage(preset.url),
                          onBackgroundImageError: (_, __) {},
                          child: isSelected
                              ? Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.periwinkle
                                        .withValues(alpha: 0.4),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20.0,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        preset.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isSelected
                              ? AppColors.periwinkle
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12.0),
          // Custom URL Input
          Text(
            appStrings.customAvatarUrl,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8.0),
          TextField(
            controller: _customUrlController,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13.5,
            ),
            decoration: InputDecoration(
              hintText: appStrings.enterAvatarUrl,
              hintStyle: TextStyle(
                color: AppColors.softSkyBlue.withValues(alpha: 0.4),
              ),
              prefixIcon: const Icon(
                Icons.link_rounded,
                color: AppColors.periwinkle,
                size: 20.0,
              ),
              filled: true,
              fillColor: AppColors.surfaceCardSubtle,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.0),
                borderSide: BorderSide(
                  color: AppColors.softSkyBlue.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.0),
                borderSide: const BorderSide(
                  color: AppColors.periwinkle,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _selectedUrl = val.trim();
              });
            },
          ),
          const SizedBox(height: 20.0),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 48.0,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.periwinkle,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                ),
                elevation: 4.0,
                shadowColor: AppColors.periwinkle.withValues(alpha: 0.4),
              ),
              onPressed: () {
                widget.onAvatarSelected(_selectedUrl);
                Navigator.pop(context);
              },
              child: Text(
                appStrings.select,
                style: const TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetAvatar {
  final String id;
  final String name;
  final String url;

  const _PresetAvatar({
    required this.id,
    required this.name,
    required this.url,
  });
}
