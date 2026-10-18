import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/locale_manager.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';

/// Đổi ảnh đại diện: tải ảnh từ máy lên, hoặc chọn một ảnh minh họa có sẵn.
/// Chọn xong sheet tự đóng và trả URL qua [onAvatarSelected]. Mở bằng [showAvatarPickerSheet]
/// (màu nền đặt trên chính sheet để ListTile hiện được hiệu ứng chạm).
Future<void> showAvatarPickerSheet(
  BuildContext context, {
  required String currentAvatarUrl,
  required ValueChanged<String> onAvatarSelected,
  required Future<String> Function(Uint8List bytes, String filename) onUpload,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.socialSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
    ),
    builder: (_) => AvatarPickerSheet(
      currentAvatarUrl: currentAvatarUrl,
      onAvatarSelected: onAvatarSelected,
      onUpload: onUpload,
    ),
  );
}

class AvatarPickerSheet extends StatefulWidget {
  final String currentAvatarUrl;
  final ValueChanged<String> onAvatarSelected;

  /// Tải ảnh lên server, trả về URL (vd. `ProfileRepository.uploadAvatar`).
  final Future<String> Function(Uint8List bytes, String filename) onUpload;

  const AvatarPickerSheet({
    super.key,
    required this.currentAvatarUrl,
    required this.onAvatarSelected,
    required this.onUpload,
  });

  /// Ảnh minh họa do DiceBear sinh theo seed (không dùng ảnh người thật).
  static const List<String> presetUrls = [
    'https://api.dicebear.com/7.x/adventurer/png?seed=Sakura',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Kenji',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Yuki',
    'https://api.dicebear.com/7.x/adventurer/png?seed=Daiki',
    'https://api.dicebear.com/7.x/bottts/png?seed=Kenji',
    'https://api.dicebear.com/7.x/bottts/png?seed=Sakura',
    'https://api.dicebear.com/7.x/bottts/png?seed=Tokyo',
    'https://api.dicebear.com/7.x/bottts/png?seed=Shiba',
  ];

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
  bool _uploading = false;
  String? _error;

  void _select(String url) {
    widget.onAvatarSelected(url);
    Navigator.of(context).pop();
  }

  Future<void> _pickAndUpload() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null || !mounted) return;

    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final url = await widget.onUpload(await file.readAsBytes(), file.name);
      if (mounted) _select(url);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = e is ApiException ? e.message : appStrings.uploadPhotoFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Text(
              appStrings.changeAvatar,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12.0),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              leading: _uploading
                  ? const SizedBox(
                      width: 24.0,
                      height: 24.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        color: Colors.white70,
                      ),
                    )
                  : const Icon(
                      Icons.photo_library_outlined,
                      color: Colors.white,
                    ),
              title: Text(
                appStrings.uploadPhoto,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: _error == null
                  ? null
                  : Text(
                      _error!,
                      style: const TextStyle(color: AppColors.socialRed),
                    ),
              onTap: _uploading ? null : _pickAndUpload,
            ),
            const SizedBox(height: 8.0),
            Text(
              appStrings.choosePresetAvatar,
              style: const TextStyle(
                color: AppColors.socialTextMuted,
                fontSize: 13.0,
              ),
            ),
            const SizedBox(height: 12.0),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12.0,
              crossAxisSpacing: 12.0,
              children: [
                for (final url in AvatarPickerSheet.presetUrls)
                  _PresetAvatar(
                    url: url,
                    selected: url == widget.currentAvatarUrl,
                    onTap: _uploading ? null : () => _select(url),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetAvatar extends StatelessWidget {
  final String url;
  final bool selected;
  final VoidCallback? onTap;

  const _PresetAvatar({required this.url, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2.0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2.0,
          ),
        ),
        child: CircleAvatar(
          backgroundColor: AppColors.socialBackground,
          backgroundImage: NetworkImage(url),
          onBackgroundImageError: (_, _) {},
        ),
      ),
    );
  }
}
