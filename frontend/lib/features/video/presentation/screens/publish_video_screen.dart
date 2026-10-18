import 'package:flutter/material.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/subtitle_draft.dart';
import '../widgets/publish_video_widgets.dart';

/// Bước 2 của luồng đăng video: nhập thông tin bài học, phụ đề (AI hoặc thủ công) rồi đăng.
class PublishVideoScreen extends StatefulWidget {
  final String videoUrl;
  final String thumbnailUrl;
  final int duration;
  final String fileName;
  final String? aiTaskId;

  const PublishVideoScreen({
    super.key,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.duration,
    required this.fileName,
    this.aiTaskId,
  });

  @override
  State<PublishVideoScreen> createState() => _PublishVideoScreenState();
}

class _PublishVideoScreenState extends State<PublishVideoScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _thumbnailController = TextEditingController();
  final List<SubtitleDraft> _subtitles = [];
  String _jlptLevel = 'N5';
  bool _isPublic = true;
  bool _isSubmitting = false;
  bool _isTranscribing = false;
  bool _isManualSubtitleMode = false;

  @override
  void initState() {
    super.initState();
    final name = widget.fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    _titleController.text = name;
    _thumbnailController.text = widget.thumbnailUrl;
  }

  /// Chế độ "Tự nhập": thêm một đoạn phụ đề trống (mặc định 0 → tối đa 5 giây đầu).
  void _addManualSubtitle() {
    setState(() {
      _isManualSubtitleMode = true;
      _subtitles.add(
        SubtitleDraft(start: '00:00', end: formatMmSs(widget.duration.clamp(1, 5))),
      );
    });
  }

  /// Chế độ "Tạo bằng AI": hỏi kết quả Speech-to-Text của video vừa tải lên.
  void _startAiSubtitleGeneration() {
    final taskId = widget.aiTaskId;
    if (taskId == null || taskId.isEmpty) {
      _showMessage('Video chưa có tác vụ AI để tạo phụ đề.');
      return;
    }
    setState(() => _isManualSubtitleMode = false);
    _loadAiSubtitles(taskId);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _thumbnailController.dispose();
    for (final subtitle in _subtitles) {
      subtitle.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAiSubtitles(String taskId) async {
    if (mounted) {
      setState(() => _isTranscribing = true);
    }

    try {
      for (var attempt = 0; attempt < 60; attempt++) {
        // FAILED (500) / NOT_FOUND (404) -> ApiException mang errorMessage của backend
        final body = await ApiClient.instance.get(
          ApiConstants.speechStatusUrl(taskId),
        );
        if (body is! Map<String, dynamic>) {
          throw Exception('Không thể kiểm tra kết quả AI.');
        }
        final status = body['status']?.toString();
        if (status == 'COMPLETED') {
          final segments = body['segments'];
          if (segments is List) {
            final drafts = segments
                .whereType<Map<String, dynamic>>()
                .map(SubtitleDraft.fromAiSegment)
                .toList();
            if (mounted) {
              for (final subtitle in _subtitles) {
                subtitle.dispose();
              }
              setState(() {
                _subtitles
                  ..clear()
                  ..addAll(drafts);
                _isTranscribing = false;
              });
            }
          }
          return;
        }
        if (status == 'FAILED' || status == 'NOT_FOUND') {
          throw Exception(body['errorMessage'] ?? 'AI không thể tạo phụ đề.');
        }
        await Future<void>.delayed(const Duration(seconds: 2));
        // Người dùng đã rời màn hình → dừng hỏi trạng thái.
        if (!mounted) return;
      }
      throw Exception('AI xử lý quá lâu, bạn có thể nhập phụ đề thủ công.');
    } catch (error) {
      if (mounted) {
        setState(() => _isTranscribing = false);
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _publish({bool asDraft = false}) async {
    if (_titleController.text.trim().isEmpty ||
        _thumbnailController.text.trim().isEmpty) {
      _showMessage('Vui lòng nhập tiêu đề và ảnh bìa.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiClient.instance.post(
        ApiConstants.videosUrl,
        withAuth: true,
        body: {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          'thumbnailUrl': _thumbnailController.text.trim(),
          'duration': widget.duration < 1 ? 1 : widget.duration,
          'jlptLevel': _jlptLevel,
          'videoUrl': widget.videoUrl,
          'subtitles': SubtitleDraft.encodeList(_subtitles),
          'status': asDraft ? 'PRIVATE' : (_isPublic ? 'PUBLIC' : 'PRIVATE'),
        },
      );

      if (!mounted) return;
      _showMessage('Đăng video bài học thành công.');
      // Đóng cả màn đăng lẫn màn tải lên.
      Navigator.of(context).pop(true);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.studioBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Đăng bài học',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => _publish(asDraft: true),
            child: const Text(
              'Lưu nháp',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          UploadedVideoSummary(
            thumbnailUrl: widget.thumbnailUrl,
            fileName: widget.fileName,
            durationSeconds: widget.duration,
          ),
          const SizedBox(height: 22),
          LabeledTextField(
            label: 'Tiêu đề bài học',
            controller: _titleController,
            maxLength: 100,
          ),
          const SizedBox(height: 18),
          LabeledTextField(
            label: 'Mô tả bài học',
            controller: _descriptionController,
            maxLines: 3,
          ),
          const SizedBox(height: 22),
          const PublishSectionTitle('Trình độ JLPT'),
          const SizedBox(height: 10),
          JlptLevelSelector(
            selected: _jlptLevel,
            onChanged: (level) => setState(() => _jlptLevel = level),
          ),
          const SizedBox(height: 22),
          const PublishSectionTitle('Phụ đề & Lời thoại'),
          const SizedBox(height: 10),
          SubtitleModeSelector(
            isManual: _isManualSubtitleMode,
            aiAvailable: widget.aiTaskId?.isNotEmpty == true,
            busy: _isTranscribing,
            onSelectAi: _startAiSubtitleGeneration,
            onSelectManual: _addManualSubtitle,
          ),
          const SizedBox(height: 12),
          if (_isTranscribing)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(color: AppColors.brandPink),
            ),
          if (!_isTranscribing && _subtitles.isEmpty && !_isManualSubtitleMode)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Bạn có thể tạo phụ đề bằng AI hoặc tự nhập lời thoại cho video.',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          for (final (index, subtitle) in _subtitles.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SubtitleDraftCard(
                index: index,
                subtitle: subtitle,
                onToggleEdit: () =>
                    setState(() => subtitle.editing = !subtitle.editing),
              ),
            ),
          if (_isManualSubtitleMode && !_isTranscribing)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addManualSubtitle,
                icon: const Icon(Icons.add),
                label: const Text('Thêm đoạn phụ đề'),
              ),
            ),
          const SizedBox(height: 12),
          const PublishSectionTitle('Quyền riêng tư'),
          const SizedBox(height: 10),
          PrivacyToggleCard(
            isPublic: _isPublic,
            onToggle: () => setState(() => _isPublic = !_isPublic),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _publish,
            icon: _isSubmitting
                ? const SizedBox.shrink()
                : const Icon(Icons.arrow_forward_rounded),
            label: _isSubmitting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Đăng video bài học'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              backgroundColor: AppColors.brandPink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
