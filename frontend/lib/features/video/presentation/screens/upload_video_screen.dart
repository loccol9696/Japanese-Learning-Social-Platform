import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../home/presentation/widgets/bottom_nav_dock.dart';
import '../../../../core/theme/app_palette.dart';

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  PlatformFile? _selectedFile;
  final _youtubeController = TextEditingController();
  late final PageController _tabPageController;
  bool _isYoutubeMode = false;
  bool _isUploading = false;
  bool _notesExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabPageController = PageController();
  }

  @override
  void dispose() {
    _youtubeController.dispose();
    _tabPageController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov'],
      withData: true,
    );

    if (!mounted || result == null || result.files.single.bytes == null) {
      return;
    }

    setState(() => _selectedFile = result.files.single);
  }

  Future<void> _uploadVideo() async {
    final file = _selectedFile;
    final bytes = file?.bytes;
    if (file == null || bytes == null) {
      _showMessage('Vui lòng chọn tệp video trước khi tải lên.');
      return;
    }

    setState(() => _isUploading = true);
    try {
      // Tải video lớn nên không đặt giới hạn thời gian; ApiClient tự gắn token.
      final response = await ApiClient.instance.sendMultipart(
        () => http.MultipartRequest(
          'POST',
          Uri.parse('${ApiConstants.baseUrl}/media/upload?folder=jlsp/videos'),
        )..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: file.name),
          ),
      );
      final data = ApiClient.decodeResponse(response);
      final videoUrl = data is Map<String, dynamic>
          ? (data['secureUrl'] ?? data['secure_url'] ?? data['url'])
          : null;
      final duration = data is Map<String, dynamic> && data['duration'] is num
          ? (data['duration'] as num).round()
          : 1;
      final publicId = data is Map<String, dynamic> ? data['publicId'] : null;
      final aiTaskId = data is Map<String, dynamic> ? data['aiTaskId'] : null;

      if (!mounted) return;
      if (videoUrl is! String || videoUrl.isEmpty) {
        throw Exception('Backend không trả về đường dẫn video.');
      }
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PublishVideoScreen(
            videoUrl: videoUrl,
            thumbnailUrl: _thumbnailUrl(videoUrl, publicId),
            duration: duration,
            fileName: file.name,
            aiTaskId: aiTaskId is String ? aiTaskId : null,
          ),
        ),
      );
      if (mounted && result is int && result != 2) {
        Navigator.of(context).pop(result);
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  String _thumbnailUrl(String videoUrl, dynamic publicId) {
    if (publicId is String && publicId.isNotEmpty) {
      final marker = '/video/upload/';
      final index = videoUrl.indexOf(marker);
      if (index >= 0) {
        return '${videoUrl.substring(0, index)}${marker}so_0/$publicId.jpg';
      }
    }
    return videoUrl;
  }

  void _importYoutubeVideo() {
    final url = _youtubeController.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        (!uri.host.contains('youtube.com') && !uri.host.contains('youtu.be'))) {
      _showMessage('Vui lòng nhập một đường link YouTube hợp lệ.');
      return;
    }
    _showMessage('Backend chưa có API nhập video từ YouTube.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Xanh dương nhạt cho gạch chân tab, icon tải lên và nút "Dán".
  static const Color _linkBlue = Color(0xFF38BDF8);

  bool get _hasYoutubeLink => _youtubeController.text.trim().isNotEmpty;

  bool get _canSubmit =>
      !_isUploading && (_isYoutubeMode ? _hasYoutubeLink : _selectedFile != null);

  Future<void> _pasteYoutubeLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (!mounted || text == null || text.isEmpty) return;
    setState(() => _youtubeController.text = text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppPalette.textPrimary,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Tải video lên',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTabs(),
            Expanded(
              child: PageView(
                controller: _tabPageController,
                onPageChanged: (index) {
                  setState(() => _isYoutubeMode = index == 1);
                },
                children: [
                  // Page 0: File upload
                  CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: _buildFilePicker()),
                              const SizedBox(height: 16),
                              _buildNotes(),
                              const SizedBox(height: 16),
                              _buildSubmitButton(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Page 1: YouTube link
                  CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildYoutubeInput(),
                              const Spacer(),
                              _buildNotes(),
                              const SizedBox(height: 16),
                              _buildSubmitButton(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hai tab chữ, tab đang chọn có gạch chân xanh nhạt; có đường kẻ phía dưới.
  Widget _buildTabs() {
    Widget tab(String label, bool active, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 46,
            child: Stack(
              children: [
                Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active
                          ? AppPalette.textPrimary
                          : AppPalette.textSecondary,
                      fontSize: 15,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 2,
                    color: active ? _linkBlue : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppPalette.surface)),
      ),
      child: Row(
        children: [
          tab('Tải tệp lên', !_isYoutubeMode, () {
            setState(() => _isYoutubeMode = false);
            _tabPageController.animateToPage(
              0,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
            );
          }),
          tab('Liên kết YouTube', _isYoutubeMode, () {
            setState(() => _isYoutubeMode = true);
            _tabPageController.animateToPage(
              1,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
            );
          }),
        ],
      ),
    );
  }

  /// Khung viền đứt nét chiếm hết chiều cao còn lại; chạm để chọn video.
  Widget _buildFilePicker() {
    final file = _selectedFile;

    return CustomPaint(
      foregroundPainter: const _DashedBorderPainter(
        color: AppPalette.border,
        radius: 20,
      ),
      child: InkWell(
        onTap: _isUploading ? null : _pickVideo,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_upload_outlined,
                  size: 46,
                  color: _linkBlue,
                ),
                const SizedBox(height: 16),
                Text(
                  file?.name ?? 'Chạm để chọn video',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  file == null
                      ? 'MP4, MOV · Tối đa 500MB · Tỷ lệ 9:16 (dọc)'
                      : 'Chạm để chọn lại video',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppPalette.textSecondary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYoutubeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Liên kết YouTube',
          style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _youtubeController,
          keyboardType: TextInputType.url,
          cursorColor: AppPalette.accent,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: AppPalette.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Dán liên kết video',
            hintStyle: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 15,
            ),
            filled: true,
            fillColor: AppPalette.surfaceHigh,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            suffixIcon: TextButton(
              onPressed: _pasteYoutubeLink,
              child: const Text(
                'Dán',
                style: TextStyle(
                  color: _linkBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppPalette.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  /// "Lưu ý khi đăng video": gập / mở, nội dung là 3 đoạn chữ thường.
  Widget _buildNotes() {
    const notes = [
      'Độ dài tối ưu dưới 60 giây giúp ghi nhớ ngắt quãng (SRS) hiệu quả hơn.',
      'Phụ đề và Furigana được tạo tự động sau khi tải lên.',
      'Tuân thủ bản quyền và tiêu chuẩn cộng đồng.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _notesExpanded = !_notesExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Lưu ý khi đăng video',
                    style: TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  _notesExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppPalette.textPrimary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: _notesExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final note in notes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            note,
                            style: const TextStyle(
                              color: AppPalette.textPrimary,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  /// Nút tải lên: mờ khi chưa chọn video / chưa nhập liên kết.
  Widget _buildSubmitButton() {
    return SizedBox(
      height: 50,
      child: FilledButton(
        onPressed: _canSubmit
            ? (_isYoutubeMode ? _importYoutubeVideo : _uploadVideo)
            : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.accent,
          foregroundColor: AppPalette.textPrimary,
          disabledBackgroundColor:
              _isUploading ? AppPalette.accent : AppPalette.navBar,
          disabledForegroundColor: _isUploading
              ? AppPalette.textPrimary
              : AppPalette.textSecondary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: _isUploading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppPalette.textPrimary,
                ),
              )
            : const Text('Tải video lên'),
      ),
    );
  }
}

/// Vẽ viền bo góc dạng nét đứt (Flutter không có sẵn).
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  static const double _dashLength = 6;
  static const double _gapLength = 5;
  static const double _strokeWidth = 1.2;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + _dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += _dashLength + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}

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
  final List<_SubtitleDraft> _subtitles = [];
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
        final result = await ApiClient.instance.get(
          ApiConstants.speechStatusUrl(taskId),
        );
        if (result is! Map<String, dynamic>) {
          throw Exception('Không thể kiểm tra kết quả AI.');
        }
        final body = result;
        final status = body['status']?.toString();
        if (status == 'COMPLETED') {
          final segments = body['segments'];
          if (segments is List) {
            final drafts = segments
                .whereType<Map<String, dynamic>>()
                .map(_subtitleFromAi)
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
      }
      throw Exception('AI xử lý quá lâu, bạn có thể nhập phụ đề thủ công.');
    } catch (error) {
      if (mounted) {
        setState(() => _isTranscribing = false);
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _addManualSubtitle() {
    setState(() {
      _isManualSubtitleMode = true;
      _subtitles.add(
        _SubtitleDraft(
          start: '00:00',
          end: _formatTimestamp(widget.duration.clamp(1, 5).toDouble()),
        ),
      );
    });
  }

  void _startAiSubtitleGeneration() {
    final taskId = widget.aiTaskId;
    if (taskId == null || taskId.isEmpty) {
      _showMessage('Video chưa có tác vụ AI để tạo phụ đề.');
      return;
    }

    setState(() => _isManualSubtitleMode = false);
    _loadAiSubtitles(taskId);
  }

  _SubtitleDraft _subtitleFromAi(Map<String, dynamic> segment) {
    final start = _formatTimestamp(
      (segment['startTime'] as num?)?.toDouble() ?? 0,
    );
    final end = _formatTimestamp((segment['endTime'] as num?)?.toDouble() ?? 0);
    return _SubtitleDraft(
      start: start,
      end: end,
      japaneseText: segment['text']?.toString() ?? '',
      translationText: segment['translatedText']?.toString() ?? '',
      editing: false,
    );
  }

  String _formatTimestamp(double seconds) {
    final wholeSeconds = seconds.round();
    final minutes = wholeSeconds ~/ 60;
    final remainder = wholeSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  Future<void> _publish({bool asDraft = false}) async {
    if (_titleController.text.trim().isEmpty ||
        _thumbnailController.text.trim().isEmpty) {
      _showMessage('Vui lòng nhập tiêu đề và ảnh bìa.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // Người đăng do server lấy từ access token.
      await ApiClient.instance.post(
        '${ApiConstants.baseUrl}/videos',
        body: {
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          'thumbnailUrl': _thumbnailController.text.trim(),
          'duration': widget.duration < 1 ? 1 : widget.duration,
          'jlptLevel': _jlptLevel,
          'videoUrl': widget.videoUrl,
          'subtitles': _subtitleJson(),
          'status': asDraft ? 'PRIVATE' : (_isPublic ? 'PUBLIC' : 'PRIVATE'),
        },
      );

      if (!mounted) return;
      _showMessage('Đăng video bài học thành công.');
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

  String? _subtitleJson() {
    final items = _subtitles
        .where((subtitle) => subtitle.japanese.text.trim().isNotEmpty)
        .map(
          (subtitle) => {
            'start': subtitle.start,
            'end': subtitle.end,
            'text': subtitle.japanese.text.trim(),
            'translation': subtitle.translation.text.trim(),
          },
        )
        .toList();
    return items.isEmpty ? null : jsonEncode(items);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleNavigation(int index) {
    if (index != 2 && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const Text(
          'Đăng bài học',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => _publish(asDraft: true),
            child: const Text(
              'Lưu nháp',
              style: TextStyle(color: AppPalette.textSecondary),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _buildVideoSummary(),
          const SizedBox(height: 22),
          _buildTextField(
            label: 'Tiêu đề bài học',
            controller: _titleController,
            maxLength: 100,
          ),
          const SizedBox(height: 18),
          _buildTextField(
            label: 'Mô tả bài học',
            controller: _descriptionController,
            maxLines: 3,
          ),
          const SizedBox(height: 22),
          _buildSectionTitle('Trình độ JLPT'),
          const SizedBox(height: 10),
          _buildJlptSelector(),
          const SizedBox(height: 22),
          _buildSectionTitle('Phụ đề & Lời thoại'),
          const SizedBox(height: 10),
          _buildSubtitleModeSelector(),
          const SizedBox(height: 12),
          if (_isTranscribing)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(color: AppPalette.accent),
            ),
          if (!_isTranscribing && _subtitles.isEmpty && !_isManualSubtitleMode)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Bạn có thể tạo phụ đề bằng AI hoặc tự nhập lời thoại cho video.',
                style: TextStyle(color: AppPalette.textSecondary),
              ),
            ),
          ..._subtitles.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildSubtitleCard(entry.key, entry.value),
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
          _buildSectionTitle('Quyền riêng tư'),
          const SizedBox(height: 10),
          _buildPrivacyCard(),
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
              backgroundColor: AppPalette.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavDock(
        selectedIndex: 2,
        onTabSelected: _isSubmitting ? (_) {} : _handleNavigation,
      ),
    );
  }

  Widget _buildVideoSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppPalette.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              widget.thumbnailUrl,
              width: 118,
              height: 78,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 118,
                height: 78,
                color: AppPalette.surface,
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
                  widget.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_formatDuration(widget.duration)} • Video đã tải lên',
                  style: const TextStyle(color: AppPalette.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    int? maxLength,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (maxLength != null)
              Text(
                '${controller.text.length}/$maxLength',
                style: const TextStyle(
                  color: AppPalette.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        const SizedBox(height: 9),
        TextField(
          controller: controller,
          maxLength: maxLength,
          maxLines: maxLines,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppPalette.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppPalette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppPalette.border),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    );
  }

  Widget _buildJlptSelector() {
    return Row(
      children: ['N5', 'N4', 'N3', 'N2', 'N1'].map((level) {
        final selected = level == _jlptLevel;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _jlptLevel = level),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppPalette.accent
                      : AppPalette.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppPalette.border),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppPalette.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubtitleModeSelector() {
    final aiAvailable = widget.aiTaskId?.isNotEmpty == true;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppPalette.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _subtitleModeButton(
              icon: Icons.auto_awesome_rounded,
              label: 'Tạo bằng AI',
              selected: !_isManualSubtitleMode,
              enabled: aiAvailable && !_isTranscribing,
              onTap: _startAiSubtitleGeneration,
            ),
          ),
          Expanded(
            child: _subtitleModeButton(
              icon: Icons.edit_note_rounded,
              label: 'Tự nhập',
              selected: _isManualSubtitleMode,
              enabled: !_isTranscribing,
              onTap: _addManualSubtitle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subtitleModeButton({
    required IconData icon,
    required String label,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF48202D) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: enabled
                  ? (selected ? AppPalette.accent : AppPalette.textSecondary)
                  : AppPalette.border,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enabled
                      ? (selected ? Colors.white : AppPalette.textSecondary)
                      : AppPalette.border,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitleCard(int index, _SubtitleDraft subtitle) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, size: 15, color: AppPalette.textSecondary),
              const SizedBox(width: 5),
              Text(
                '${subtitle.start} - ${subtitle.end}',
                style: const TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '#${index + 1}',
                style: const TextStyle(color: AppPalette.textSecondary),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    setState(() => subtitle.editing = !subtitle.editing),
                icon: const Icon(Icons.edit, size: 17, color: AppPalette.textSecondary),
              ),
            ],
          ),
          if (subtitle.editing) ...[
            _subtitleInput(subtitle.japanese, 'Tiếng Nhật'),
            _subtitleInput(subtitle.translation, 'Bản dịch'),
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
              style: const TextStyle(color: AppPalette.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _subtitleInput(TextEditingController controller, String hint) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: AppPalette.background,
        ),
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return InkWell(
      onTap: () => setState(() => _isPublic = !_isPublic),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppPalette.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppPalette.border),
        ),
        child: Row(
          children: [
            Icon(
              _isPublic ? Icons.public : Icons.lock_outline,
              color: AppPalette.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _isPublic ? 'Công khai' : 'Riêng tư',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (_isPublic) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF481D2B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Mặc định',
                            style: TextStyle(
                              color: Color(0xFFFF6A88),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _isPublic
                        ? 'Mọi người đều có thể xem bài học và ôn tập'
                        : 'Chỉ bạn có thể xem bài học này',
                    style: const TextStyle(color: AppPalette.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppPalette.textSecondary),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }
}

class _SubtitleDraft {
  final String start;
  final String end;
  final japanese = TextEditingController();
  final translation = TextEditingController();
  bool editing;

  _SubtitleDraft({
    required this.start,
    required this.end,
    String japaneseText = '',
    String translationText = '',
    this.editing = true,
  }) {
    japanese.text = japaneseText;
    translation.text = translationText;
  }

  void dispose() {
    japanese.dispose();
    translation.dispose();
  }
}
