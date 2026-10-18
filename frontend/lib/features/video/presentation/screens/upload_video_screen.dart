import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/upload_video_widgets.dart';
import 'publish_video_screen.dart';

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
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov'],
    );

    if (!mounted || file == null) {
      return;
    }

    setState(() => _selectedFile = file);
  }

  Future<void> _uploadVideo() async {
    final file = _selectedFile;
    if (file == null) {
      _showMessage('Vui lòng chọn tệp video trước khi tải lên.');
      return;
    }

    setState(() => _isUploading = true);
    try {
      final bytes = await file.readAsBytes();
      final data = await ApiClient.instance.postMultipart(
        ApiConstants.mediaUploadUrl(folder: 'jlsp/videos'),
        fieldName: 'file',
        bytes: bytes,
        filename: file.name,
      );
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
    final onSubmit = _isUploading
        ? null
        : (youtube ? _importYoutubeVideo : _uploadVideo);
    return Scaffold(
      backgroundColor: AppColors.studioBackground,
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
            onPressed: onSubmit,
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
          UploadSourceTabs(
            isYoutubeMode: youtube,
            onChanged: (value) => setState(() => _isYoutubeMode = value),
          ),
          const SizedBox(height: 20),
          if (youtube)
            YoutubeLinkCard(controller: _youtubeController)
          else
            VideoFilePickerCard(
              selectedFileName: _selectedFile?.name,
              onPick: _pickVideo,
            ),
          const SizedBox(height: 16),
          if (youtube) ...[
            const YoutubeImportInfo(),
            const SizedBox(height: 16),
          ],
          const UploadNoticeCard(),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onSubmit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: AppColors.brandPink,
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
}
