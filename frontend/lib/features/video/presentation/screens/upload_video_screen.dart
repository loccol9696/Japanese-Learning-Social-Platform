import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/api_constants.dart';

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  PlatformFile? _selectedFile;
  final _youtubeController = TextEditingController();
  bool _isYoutubeMode = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _youtubeController.dispose();
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
    if (file?.bytes == null) {
      _showMessage('Vui lòng chọn tệp video trước khi tải lên.');
      return;
    }

    setState(() => _isUploading = true);
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}/media/upload?folder=jlsp/videos'),
      );
      request.files.add(
        http.MultipartFile.fromBytes('file', file!.bytes!, filename: file.name),
      );

      final response = await request.send();
      final responseBody = jsonDecode(
        await response.stream.bytesToString(),
      ) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(responseBody['message'] ?? 'Không thể tải video lên.');
      }

      final data = responseBody['data'];
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
      await Navigator.of(context).push(
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
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final youtube = _isYoutubeMode;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E12),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Tải video lên',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _isUploading
                ? null
                : (youtube ? _importYoutubeVideo : _uploadVideo),
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
          _buildTabs(),
          const SizedBox(height: 20),
          youtube ? _buildYoutubeInput() : _buildFilePicker(),
          const SizedBox(height: 16),
          if (youtube) _buildYoutubeNotice(),
          if (!youtube) _buildNoticeCard(),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isUploading
                ? null
                : (youtube ? _importYoutubeVideo : _uploadVideo),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: const Color(0xFFFF2D55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isUploading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(youtube ? 'Nhập video từ YouTube' : 'Tải video lên'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    Widget tab(IconData icon, String label, bool active, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF2A292E) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: active ? const Color(0xFFFF2D55) : Colors.white54,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF19181D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          tab(
            Icons.upload_file_rounded,
            'Tải tệp lên',
            !_isYoutubeMode,
            () => setState(() => _isYoutubeMode = false),
          ),
          tab(
            Icons.ondemand_video_rounded,
            'Liên kết YouTube',
            _isYoutubeMode,
            () => setState(() => _isYoutubeMode = true),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePicker() {
    return InkWell(
      onTap: _pickVideo,
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
              backgroundColor: Color(0xFF29272D),
              child: Icon(
                Icons.cloud_upload_outlined,
                size: 36,
                color: Color(0xFFFF2D55),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _selectedFile?.name ?? 'Chạm để chọn tệp từ máy',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 7),
            Text(
              _selectedFile == null
                  ? 'Tải video trực tiếp từ thư viện ảnh hoặc tệp'
                  : 'Đã chọn video để tải lên',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.add_circle_outline),
              label: Text(
                _selectedFile == null ? 'Chọn từ thiết bị' : 'Chọn lại video',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D55),
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

  Widget _buildYoutubeInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151419),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
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
            controller: _youtubeController,
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

  Widget _buildYoutubeNotice() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF151419),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
          ),
          child: const Row(
            children: [
              Icon(Icons.smart_display_rounded, color: Color(0xFFFF2D55)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nhập link YouTube Shorts\nHỗ trợ trích xuất phụ đề tự động',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildNoticeCard(),
      ],
    );
  }

  Widget _buildNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151419),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
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
        final response = await http.get(
          Uri.parse(ApiConstants.speechStatusUrl(taskId)),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('Không thể kiểm tra kết quả AI.');
        }

        final body =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
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
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/videos'),
        headers: {'Content-Type': 'application/json', 'X-User-Id': '1'},
        body: jsonEncode({
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
        }),
      );
      final responseBody = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(responseBody['message'] ?? 'Không thể đăng bài học.');
      }

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
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E12),
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
              child: LinearProgressIndicator(color: Color(0xFFFF2D55)),
            ),
          if (!_isTranscribing && _subtitles.isEmpty && !_isManualSubtitleMode)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Bạn có thể tạo phụ đề bằng AI hoặc tự nhập lời thoại cho video.',
                style: TextStyle(color: Colors.white60),
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
              backgroundColor: const Color(0xFFFF2D55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF19181D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
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
                color: const Color(0xFF29272D),
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
                  style: const TextStyle(color: Colors.white60),
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
                  color: Colors.white54,
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
            fillColor: const Color(0xFF19181D),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.white24),
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
                      ? const Color(0xFFFF2D55)
                      : const Color(0xFF19181D),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.white54,
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
        color: const Color(0xFF19181D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
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
                  ? (selected ? const Color(0xFFFF2D55) : Colors.white60)
                  : Colors.white24,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enabled
                      ? (selected ? Colors.white : Colors.white60)
                      : Colors.white24,
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
        color: const Color(0xFF1A191E),
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
                onPressed: () =>
                    setState(() => subtitle.editing = !subtitle.editing),
                icon: const Icon(Icons.edit, size: 17, color: Colors.white60),
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
              style: const TextStyle(color: Colors.white60),
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
          fillColor: const Color(0xFF0F0E12),
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
          color: const Color(0xFF19181D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(
              _isPublic ? Icons.public : Icons.lock_outline,
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
                    style: const TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
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
