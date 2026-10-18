import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/subtitle_draft.dart';

// Các khối giao diện của màn PublishVideoScreen.

const jlptLevels = ['N5', 'N4', 'N3', 'N2', 'N1'];

class PublishSectionTitle extends StatelessWidget {
  final String title;

  const PublishSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    );
  }
}

/// Ảnh bìa + tên tệp + thời lượng của video vừa tải lên.
class UploadedVideoSummary extends StatelessWidget {
  final String thumbnailUrl;
  final String fileName;
  final int durationSeconds;

  const UploadedVideoSummary({
    super.key,
    required this.thumbnailUrl,
    required this.fileName,
    required this.durationSeconds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.studioSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              thumbnailUrl,
              width: 118,
              height: 78,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 118,
                height: 78,
                color: AppColors.studioRaised,
                child: const Icon(Icons.video_library_outlined),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '${formatMmSs(durationSeconds)} • Video đã tải lên',
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ô nhập có nhãn; nếu có [maxLength] thì hiện bộ đếm ký tự cạnh nhãn.
class LabeledTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int? maxLength;
  final int maxLines;

  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    this.maxLength,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.white24),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (maxLength != null)
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) => Text(
                  '${value.text.length}/$maxLength',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 9),
        TextField(
          controller: controller,
          maxLength: maxLength,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.studioSurface,
            border: border,
            enabledBorder: border,
          ),
        ),
      ],
    );
  }
}

/// Hàng 5 nút chọn trình độ JLPT.
class JlptLevelSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const JlptLevelSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: jlptLevels.map((level) {
        final isSelected = level == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            // Nền vẽ bằng Container, ink trên Material trong suốt phía trên nền.
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brandPink
                    : AppColors.studioSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => onChanged(level),
                  borderRadius: BorderRadius.circular(14),
                  child: Center(
                    child: Text(
                      level,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : Colors.white54,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Thẻ một dòng phụ đề: xem hoặc sửa (tiếng Nhật + bản dịch).
class SubtitleDraftCard extends StatelessWidget {
  final int index;
  final SubtitleDraft subtitle;
  final VoidCallback onToggleEdit;

  const SubtitleDraftCard({
    super.key,
    required this.index,
    required this.subtitle,
    required this.onToggleEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.studioSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, size: 15, color: Colors.white60),
              const SizedBox(width: 5),
              Text(
                '${subtitle.start} - ${subtitle.end}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '#${index + 1}',
                style: const TextStyle(color: Colors.white54),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onToggleEdit,
                icon: const Icon(Icons.edit, size: 17, color: Colors.white60),
              ),
            ],
          ),
          if (subtitle.editing) ...[
            _input(subtitle.japanese, 'Tiếng Nhật'),
            _input(subtitle.translation, 'Bản dịch'),
          ] else ...[
            Text(
              subtitle.japanese.text.isEmpty
                  ? 'Chưa có nội dung phụ đề'
                  : subtitle.japanese.text,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle.translation.text.isEmpty
                  ? 'Nhấn biểu tượng bút để nhập phụ đề'
                  : subtitle.translation.text,
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ],
      ),
    );
  }

  Widget _input(TextEditingController controller, String hint) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: AppColors.studioBackground,
        ),
      ),
    );
  }
}

/// Thẻ chuyển Công khai / Riêng tư.
class PrivacyToggleCard extends StatelessWidget {
  final bool isPublic;
  final VoidCallback onToggle;

  const PrivacyToggleCard({
    super.key,
    required this.isPublic,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    // Nền vẽ bằng Container, ink trên Material trong suốt phía trên nền.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.studioSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  isPublic ? Icons.public : Icons.lock_outline,
                  color: Colors.white70,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isPublic ? 'Công khai' : 'Riêng tư',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (isPublic) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.studioBadge,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Mặc định',
                                style: TextStyle(
                                  color: AppColors.studioBadgeText,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isPublic
                            ? 'Mọi người đều có thể xem bài học và ôn tập'
                            : 'Chỉ bạn có thể xem bài học này',
                        style: const TextStyle(color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
