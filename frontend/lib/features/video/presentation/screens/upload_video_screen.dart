import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../subtitle_split.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../home/presentation/widgets/bottom_nav_dock.dart';
import '../../../profile/domain/models/topic_model.dart';
import '../../../topic/topic_service.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';

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

    final extension = (file.extension ?? file.name.split('.').last)
        .toLowerCase();
    final contentType = switch (extension) {
      'mp4' => MediaType('video', 'mp4'),
      'mov' => MediaType('video', 'quicktime'),
      _ => null,
    };
    if (contentType == null) {
      _showMessage('Chỉ hỗ trợ video MP4 hoặc MOV.');
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
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: file.name,
              contentType: contentType,
            ),
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
    AppToast.show(message, context: context);
  }

  /// Xanh dương nhạt cho gạch chân tab, icon tải lên và nút "Dán".
  static Color get _linkBlue => AppPalette.info;

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
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppPalette.textPrimary,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
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
      decoration: BoxDecoration(
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
      foregroundPainter: _DashedBorderPainter(
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
                Icon(
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
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  file == null
                      ? 'MP4, MOV · Tối đa 500MB'
                      : 'Chạm để chọn lại video',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
        Text(
          'Liên kết YouTube',
          style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _youtubeController,
          keyboardType: TextInputType.url,
          cursorColor: AppPalette.accent,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: AppPalette.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Dán liên kết video',
            hintStyle: TextStyle(
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
              child: Text(
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
              borderSide: BorderSide(color: AppPalette.accent, width: 1.5),
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
                Expanded(
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
                            style: TextStyle(
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
          foregroundColor: AppPalette.onAccent,
          disabledBackgroundColor:
              _isUploading ? AppPalette.accent : AppPalette.navBar,
          disabledForegroundColor: _isUploading
              ? AppPalette.onAccent
              : AppPalette.textSecondary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: _isUploading
            ? SizedBox(
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
  List<TopicModel> _topics = const [];
  int? _topicId;
  bool _isPublic = true;
  bool _isSubmitting = false;
  bool _isTranscribing = false;
  bool _isManualSubtitleMode = false;
  bool _isAnalyzingGrammar = false;

  @override
  void initState() {
    super.initState();
    final name = widget.fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    _titleController.text = name;
    _thumbnailController.text = widget.thumbnailUrl;
    _loadTopics();
  }

  /// Chủ đề là tuỳ chọn: tải lỗi thì ẩn phần chọn, vẫn đăng được video.
  Future<void> _loadTopics() async {
    try {
      final topics = await TopicService().fetchTopics();
      if (mounted) setState(() => _topics = topics);
    } catch (_) {}
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
        // Trường hợp backend bọc trong ApiResponse { code, message, data: {...} }
        final Map<String, dynamic> body = (result['data'] is Map<String, dynamic>)
            ? (result['data'] as Map<String, dynamic>)
            : result;
        final status = body['status']?.toString();
        debugPrint('[STT DEBUG] status=$status, totalSegments=${body['totalSegments']}');

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
                _isManualSubtitleMode = false;
              });
              _showMessage('Đã tạo phụ đề thành công (${drafts.length} đoạn)!');
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

  String _formatTimestamp(double seconds) => formatSubtitleTime(seconds);

  /// Tách dòng phụ đề tại vị trí con trỏ trong ô tiếng Nhật.
  void _splitSubtitle(int index) {
    final subtitle = _subtitles[index];
    final offset = subtitle.japanese.selection.baseOffset;
    final result = splitSubtitleAt(
      text: subtitle.japanese.text,
      translation: subtitle.translation.text,
      start: subtitle.start,
      end: subtitle.end,
      offset: offset,
    );
    if (result == null) {
      _showMessage('Đặt con trỏ vào giữa câu tiếng Nhật rồi bấm Tách câu.');
      return;
    }
    setState(() {
      _subtitles[index] = _SubtitleDraft(
        start: result.firstStart,
        end: result.firstEnd,
        japaneseText: result.firstText,
        translationText: result.firstTranslation,
      );
      _subtitles.insert(
        index + 1,
        _SubtitleDraft(
          start: result.secondStart,
          end: result.secondEnd,
          japaneseText: result.secondText,
          translationText: result.secondTranslation,
        ),
      );
    });
    subtitle.dispose();
  }

  double _parseTimeToSeconds(String timeStr) {
    final parts = timeStr.trim().split(':');
    if (parts.length != 2) return 0.0;
    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = double.tryParse(parts[1]) ?? 0.0;
    return (minutes * 60 + seconds);
  }

  Future<void> _analyzeGrammar() async {
    final validSubtitles = _subtitles
        .where((s) => s.japanese.text.trim().isNotEmpty)
        .toList();
    if (validSubtitles.isEmpty) {
      _showMessage('Chưa có lời thoại để phân tích ngữ pháp.');
      return;
    }

    setState(() => _isAnalyzingGrammar = true);
    try {
      final segmentsPayload = validSubtitles.map((s) {
        return {
          'startTime': _parseTimeToSeconds(s.start),
          'endTime': _parseTimeToSeconds(s.end),
          'text': s.japanese.text.trim(),
          'translatedText': s.translation.text.trim(),
        };
      }).toList();

      final response = await ApiClient.instance.post(
        ApiConstants.analyzeGrammarUrl,
        body: {'segments': segmentsPayload},
      );
      debugPrint('[GRAMMAR DEBUG] raw response: $response');
      List<dynamic>? results;
      if (response is List) {
        results = response;
      } else if (response is Map<String, dynamic>) {
        if (response['data'] is List) {
          results = response['data'] as List<dynamic>;
        } else if (response['result'] is List) {
          results = response['result'] as List<dynamic>;
        }
      }

      if (results != null && mounted) {
        setState(() {
          for (var i = 0; i < results!.length && i < validSubtitles.length; i++) {
            final item = results[i];
            if (item is Map<String, dynamic> && item['grammarPoints'] is List) {
              final points = (item['grammarPoints'] as List)
                  .whereType<Map<String, dynamic>>()
                  .map(_GrammarDraft.fromJson)
                  .toList();
              validSubtitles[i].grammarPoints = points;
            }
          }
        });
        final totalPoints = validSubtitles.fold<int>(0, (sum, s) => sum + s.grammarPoints.length);
        _showMessage('Phân tích ngữ pháp thành công! Tìm thấy $totalPoints điểm ngữ pháp.');
      }
    } catch (error, stack) {
      debugPrint("[GRAMMAR ERROR] $error\n$stack");
      if (mounted) {
        _showMessage(error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzingGrammar = false);
      }
    }
  }

  String? _grammarAnalysisJson() {
    final items = <Map<String, dynamic>>[];
    for (var i = 0; i < _subtitles.length; i++) {
      final s = _subtitles[i];
      if (s.japanese.text.trim().isEmpty) continue;
      items.add({
        'index': i,
        'startTime': _parseTimeToSeconds(s.start),
        'endTime': _parseTimeToSeconds(s.end),
        'text': s.japanese.text.trim(),
        'grammarPoints': s.grammarPoints.map((g) => g.toJson()).toList(),
      });
    }
    final hasPoints = items.any((it) => (it['grammarPoints'] as List).isNotEmpty);
    return hasPoints ? jsonEncode(items) : null;
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
          if (_topicId != null) 'topicId': _topicId,
          'videoUrl': widget.videoUrl,
          'subtitles': _subtitleJson(),
          'grammarAnalysis': _grammarAnalysisJson(),
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
    AppToast.show(message, context: context);
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
            child: Text(
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
          if (_topics.isNotEmpty) ...[
            const SizedBox(height: 22),
            _buildSectionTitle('Chủ đề (tuỳ chọn)'),
            const SizedBox(height: 10),
            _buildTopicSelector(),
          ],
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Phụ đề & Lời thoại'),
              if (_subtitles.isNotEmpty && !_isTranscribing)
                TextButton.icon(
                  onPressed: _isAnalyzingGrammar ? null : _analyzeGrammar,
                  icon: _isAnalyzingGrammar
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppPalette.accent,
                          ),
                        )
                      : Icon(Icons.psychology_outlined, size: 18, color: AppPalette.accent),
                  label: Text(
                    _isAnalyzingGrammar ? 'Đang phân tích...' : 'Phân tích ngữ pháp',
                    style: TextStyle(
                      color: AppPalette.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSubtitleModeSelector(),
          const SizedBox(height: 12),
          if (_isTranscribing || _isAnalyzingGrammar)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(color: AppPalette.accent),
                  const SizedBox(height: 6),
                  Text(
                    _isAnalyzingGrammar
                        ? 'AI đang phân tích ngữ pháp trong từng đoạn thoại...'
                        : 'AI đang nhận diện lời thoại và sinh phụ đề...',
                    style: TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          if (!_isTranscribing && _subtitles.isEmpty && !_isManualSubtitleMode)
            Padding(
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
                ? CircularProgressIndicator(color: AppPalette.onAccent)
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
                  style: TextStyle(color: AppPalette.textSecondary),
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
                style: TextStyle(
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
          style: TextStyle(color: AppPalette.textPrimary),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppPalette.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppPalette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppPalette.border),
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
                    color: selected ? AppPalette.onAccent : AppPalette.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopicSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _topics.map((topic) {
        final selected = topic.id == _topicId;
        return ChoiceChip(
          label: Text(topic.name),
          selected: selected,
          // Bấm lại chủ đề đang chọn để bỏ chọn.
          onSelected: (_) => setState(() => _topicId = selected ? null : topic.id),
          selectedColor: AppPalette.accent,
          backgroundColor: AppPalette.background,
          side: BorderSide(color: AppPalette.border),
          labelStyle: TextStyle(
            color: selected ? AppPalette.onAccent : AppPalette.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          showCheckmark: false,
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
          color: selected ? AppPalette.errorContainer : Colors.transparent,
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
                      ? (selected ? AppPalette.onAccent : AppPalette.textSecondary)
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
              Icon(Icons.access_time, size: 15, color: AppPalette.textSecondary),
              const SizedBox(width: 5),
              Text(
                '${subtitle.start} - ${subtitle.end}',
                style: TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '#${index + 1}',
                style: TextStyle(color: AppPalette.textSecondary),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    setState(() => subtitle.editing = !subtitle.editing),
                icon: Icon(Icons.edit, size: 17, color: AppPalette.textSecondary),
              ),
            ],
          ),
          if (subtitle.editing) ...[
            _subtitleInput(subtitle.japanese, 'Tiếng Nhật'),
            _subtitleInput(subtitle.translation, 'Bản dịch'),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _splitSubtitle(index),
                icon: const Icon(Icons.content_cut, size: 16),
                label: const Text('Tách câu tại con trỏ'),
              ),
            ),
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
              style: TextStyle(color: AppPalette.textSecondary),
            ),
          ],
          if (subtitle.grammarPoints.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: subtitle.grammarPoints.map((g) {
                return Tooltip(
                  message: '${g.meaning}\n${g.explanation}',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B1D28),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppPalette.accent.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppPalette.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            g.jlptLevel.isNotEmpty ? g.jlptLevel : 'JLPT',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          g.pattern,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (g.meaning.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            ': ${g.meaning}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppPalette.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
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
        style: TextStyle(color: AppPalette.textPrimary),
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
                            color: AppPalette.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Mặc định',
                            style: TextStyle(
                              color: AppPalette.like,
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
                    style: TextStyle(color: AppPalette.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppPalette.textSecondary),
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
  List<_GrammarDraft> grammarPoints;

  _SubtitleDraft({
    required this.start,
    required this.end,
    String japaneseText = '',
    String translationText = '',
    this.editing = true,
    List<_GrammarDraft>? grammarPoints,
  }) : grammarPoints = grammarPoints ?? [] {
    japanese.text = japaneseText;
    translation.text = translationText;
  }

  void dispose() {
    japanese.dispose();
    translation.dispose();
  }
}

class _GrammarDraft {
  final String pattern;
  final String matchedText;
  final String jlptLevel;
  final String meaning;
  final String explanation;

  const _GrammarDraft({
    required this.pattern,
    required this.matchedText,
    required this.jlptLevel,
    required this.meaning,
    required this.explanation,
  });

  factory _GrammarDraft.fromJson(Map<String, dynamic> json) {
    return _GrammarDraft(
      pattern: json['pattern']?.toString() ?? '',
      matchedText: json['matchedText']?.toString() ?? '',
      jlptLevel: json['jlptLevel']?.toString() ?? '',
      meaning: json['meaning']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'pattern': pattern,
    'matchedText': matchedText,
    'jlptLevel': jlptLevel,
    'meaning': meaning,
    'explanation': explanation,
  };
}
