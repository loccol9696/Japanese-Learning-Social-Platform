import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_palette.dart';
import '../chat/presentation/screens/shared_video_screen.dart';
import 'report_service.dart';

/// Kết quả một báo cáo, mở từ thông báo. [videoId] là video liên quan (nếu có) để xem lại.
class ReportResultScreen extends StatefulWidget {
  final int reportId;
  final int? videoId;
  final ReportService? service;

  const ReportResultScreen({
    super.key,
    required this.reportId,
    this.videoId,
    this.service,
  });

  @override
  State<ReportResultScreen> createState() => _ReportResultScreenState();
}

class _ReportResultScreenState extends State<ReportResultScreen> {
  late final ReportService _service = widget.service ?? ReportService();
  ReportResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _result = null;
      _error = null;
    });
    try {
      final result = await _service.fetchResult(widget.reportId);
      if (mounted) setState(() => _result = result);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể tải kết quả báo cáo. Vui lòng thử lại.');
    }
  }

  void _openVideo(int videoId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SharedVideoScreen(videoId: videoId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        foregroundColor: AppPalette.textPrimary,
        elevation: 0,
        title: const Text('Kết quả báo cáo'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppPalette.textSecondary),
              ),
              TextButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    final result = _result;
    if (result == null) {
      return Center(child: CircularProgressIndicator(color: AppPalette.accent));
    }
    final videoId = widget.videoId;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _OutcomeCard(result: result),
        if (result.note.isNotEmpty)
          _Section(title: 'Ghi chú của kiểm duyệt viên', body: result.note),
        _Section(
          title: 'Nội dung bị báo cáo (${result.targetLabel})',
          body: result.content.isNotEmpty ? result.content : 'Nội dung không còn tồn tại',
        ),
        if (result.reasonLabel.isNotEmpty)
          _Section(title: 'Lý do báo cáo', body: result.reasonLabel),
        if (result.detail.isNotEmpty)
          _Section(title: 'Mô tả của bạn', body: result.detail),
        if (result.createdAt != null)
          _Section(title: 'Gửi báo cáo lúc', body: _formatTime(result.createdAt!)),
        if (result.resolvedAt != null)
          _Section(title: 'Xử lý lúc', body: _formatTime(result.resolvedAt!)),
        if (videoId != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _openVideo(videoId),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.textPrimary,
              side: BorderSide(color: AppPalette.border),
              minimumSize: const Size.fromHeight(46),
            ),
            icon: const Icon(Icons.play_circle_outline_rounded),
            label: const Text('Xem video'),
          ),
        ],
      ],
    );
  }

  static String _formatTime(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)} '
        '${two(local.day)}/${two(local.month)}/${local.year}';
  }
}

/// Kết quả nổi bật ở đầu màn: màu theo việc đã xử lý, không vi phạm hay còn chờ.
class _OutcomeCard extends StatelessWidget {
  final ReportResult result;

  const _OutcomeCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, Color background) = switch (result.status) {
      ReportResultStatus.resolved => (
        Icons.check_circle_rounded,
        AppPalette.success,
        AppPalette.successContainer,
      ),
      ReportResultStatus.dismissed => (
        Icons.info_rounded,
        AppPalette.info,
        AppPalette.infoContainer,
      ),
      ReportResultStatus.pending => (
        Icons.schedule_rounded,
        AppPalette.warning,
        AppPalette.warningContainer,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.outcome,
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;

  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: AppPalette.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(color: AppPalette.textPrimary, fontSize: 14.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}
