import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

// Các khối giao diện của màn UploadVideoScreen.

BoxDecoration _panelDecoration({double radius = 18}) => BoxDecoration(
  color: AppColors.studioPanel,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: Colors.white10),
);

/// Chọn nguồn video: tải tệp lên / liên kết YouTube.
class UploadSourceTabs extends StatelessWidget {
  final bool isYoutubeMode;
  final ValueChanged<bool> onChanged;

  const UploadSourceTabs({
    super.key,
    required this.isYoutubeMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget tab(IconData icon, String label, bool active, VoidCallback onTap) {
      // Material cục bộ: ink nằm trên nền thanh tab và di chuyển cùng nội dung.
      return Expanded(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              height: 40,
              decoration: BoxDecoration(
                color: active ? AppColors.studioRaised : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: active ? AppColors.brandPink : Colors.white54,
                  ),
                  const SizedBox(width: 7),
                  // Màn hẹp / cỡ chữ lớn: cắt "…" thay vì tràn.
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? Colors.white : Colors.white60,
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

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.studioSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          tab(
            Icons.upload_file_rounded,
            'Tải tệp lên',
            !isYoutubeMode,
            () => onChanged(false),
          ),
          tab(
            Icons.ondemand_video_rounded,
            'Liên kết YouTube',
            isYoutubeMode,
            () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

/// Khung chọn tệp video từ thiết bị.
class VideoFilePickerCard extends StatelessWidget {
  final String? selectedFileName;
  final VoidCallback onPick;

  const VideoFilePickerCard({
    super.key,
    required this.selectedFileName,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = selectedFileName != null;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 35,
              backgroundColor: AppColors.studioRaised,
              child: Icon(
                Icons.cloud_upload_outlined,
                size: 36,
                color: AppColors.brandPink,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              selectedFileName ?? 'Chạm để chọn tệp từ máy',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Text(
              hasFile
                  ? 'Đã chọn video để tải lên'
                  : 'Tải video trực tiếp từ thư viện ảnh hoặc tệp',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.add_circle_outline),
              label: Text(hasFile ? 'Chọn lại video' : 'Chọn từ thiết bị'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPink,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'MP4, MOV  •  Tối đa 500MB  •  Tỷ lệ 9:16 (dọc)',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ô dán liên kết YouTube.
class YoutubeLinkCard extends StatelessWidget {
  final TextEditingController controller;

  const YoutubeLinkCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dán liên kết YouTube',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          const Text(
            'Hỗ trợ video Shorts bài học tiếng Nhật',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.link),
              hintText: 'https://youtube.com/shorts/...',
              filled: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// Giới thiệu chế độ nhập từ YouTube.
class YoutubeImportInfo extends StatelessWidget {
  const YoutubeImportInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: const Row(
        children: [
          Icon(Icons.smart_display_rounded, color: AppColors.brandPink),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nhập link YouTube Shorts\nHỗ trợ trích xuất phụ đề tự động',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lưu ý khi đăng video.
class UploadNoticeCard extends StatelessWidget {
  const UploadNoticeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LƯU Ý KHI ĐĂNG VIDEO',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 14),
          Text(
            '◷  Độ dài tối ưu: Dưới 60 giây (Shorts/Reels) giúp tối ưu hoá khả năng ghi nhớ ngắt quãng (SRS).',
          ),
          SizedBox(height: 10),
          Text(
            '▣  Phụ đề & Furigana: Hệ thống tự động tạo phụ đề và phiên âm Furigana sau khi tải lên.',
          ),
          SizedBox(height: 10),
          Text(
            '♢  Quy chuẩn nội dung: Tuân thủ bản quyền và tiêu chuẩn cộng đồng.',
          ),
        ],
      ),
    );
  }
}
