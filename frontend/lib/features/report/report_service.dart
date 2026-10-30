import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';

/// Loại đối tượng báo cáo, khớp enum `ReportTargetType` của backend.
enum ReportTarget { video, comment, user }

/// Lý do báo cáo, khớp enum `ReportReason` của backend.
enum ReportReason {
  spam('SPAM', 'Spam hoặc quảng cáo'),
  inappropriate('INAPPROPRIATE', 'Nội dung không phù hợp'),
  harassment('HARASSMENT', 'Quấy rối hoặc thù ghét'),
  misinformation('MISINFORMATION', 'Thông tin sai lệch'),
  copyright('COPYRIGHT', 'Vi phạm bản quyền'),
  other('OTHER', 'Lý do khác');

  const ReportReason(this.code, this.label);

  final String code;
  final String label;
}

class ReportService {
  ReportService({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  /// Gửi báo cáo; ném [ApiException] khi bị từ chối (báo cáo trùng, nội dung của chính mình...).
  Future<void> submit({
    required ReportTarget target,
    required int targetId,
    required ReportReason reason,
    String? detail,
  }) async {
    final trimmed = detail?.trim();
    await _api.post(
      ApiConstants.reportsUrl,
      body: {
        'targetType': target.name.toUpperCase(),
        'targetId': targetId,
        'reason': reason.code,
        if (trimmed != null && trimmed.isNotEmpty) 'detail': trimmed,
      },
    );
  }
}
