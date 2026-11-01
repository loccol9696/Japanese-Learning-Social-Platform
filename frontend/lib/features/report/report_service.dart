import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';

/// Loại đối tượng báo cáo, khớp enum `ReportTargetType` của backend.
enum ReportTarget {
  video('Video'),
  comment('Bình luận'),
  user('Người dùng'),
  message('Tin nhắn'),
  translation('Bản dịch'),
  grammar('Ngữ pháp');

  const ReportTarget(this.label);

  final String label;

  /// Các lý do hợp với loại đối tượng này, hiện theo thứ tự trong bảng báo cáo.
  List<ReportReason> get reasons => switch (this) {
    translation || grammar => const [
      ReportReason.inaccurate,
      ReportReason.inappropriate,
      ReportReason.spam,
      ReportReason.other,
    ],
    message => const [
      ReportReason.harassment,
      ReportReason.spam,
      ReportReason.inappropriate,
      ReportReason.other,
    ],
    _ => const [
      ReportReason.spam,
      ReportReason.inappropriate,
      ReportReason.harassment,
      ReportReason.misinformation,
      ReportReason.copyright,
      ReportReason.other,
    ],
  };
}

/// Lý do báo cáo, khớp enum `ReportReason` của backend.
enum ReportReason {
  spam('SPAM', 'Spam hoặc quảng cáo'),
  inappropriate('INAPPROPRIATE', 'Nội dung không phù hợp'),
  harassment('HARASSMENT', 'Quấy rối hoặc thù ghét'),
  misinformation('MISINFORMATION', 'Thông tin sai lệch'),
  copyright('COPYRIGHT', 'Vi phạm bản quyền'),
  inaccurate('INACCURATE', 'Dịch hoặc giải thích sai'),
  other('OTHER', 'Lý do khác');

  const ReportReason(this.code, this.label);

  final String code;
  final String label;
}

enum ReportResultStatus { pending, resolved, dismissed }

/// Kết quả một báo cáo, khớp `ReportResultResponse` của backend.
class ReportResult {
  final ReportResultStatus status;
  final String outcome;
  final String targetLabel;
  final String content;
  final String reasonLabel;
  final String detail;
  final String note;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  const ReportResult({
    required this.status,
    required this.outcome,
    required this.targetLabel,
    required this.content,
    required this.reasonLabel,
    required this.detail,
    required this.note,
    this.createdAt,
    this.resolvedAt,
  });

  factory ReportResult.fromJson(Map<String, dynamic> json) {
    final targetCode = json['targetType']?.toString() ?? '';
    final reasonCode = json['reason']?.toString();
    return ReportResult(
      status: switch (json['status']?.toString()) {
        'RESOLVED' => ReportResultStatus.resolved,
        'DISMISSED' => ReportResultStatus.dismissed,
        _ => ReportResultStatus.pending,
      },
      outcome: json['outcome']?.toString() ?? '',
      targetLabel: ReportTarget.values.asNameMap()[targetCode.toLowerCase()]?.label ?? 'Nội dung',
      content: json['content']?.toString() ?? '',
      reasonLabel: ReportReason.values
              .where((reason) => reason.code == reasonCode)
              .firstOrNull
              ?.label ??
          '',
      detail: json['detail']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      resolvedAt: DateTime.tryParse(json['resolvedAt']?.toString() ?? ''),
    );
  }
}

class ReportService {
  ReportService({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<ReportResult> fetchResult(int reportId) async {
    final data = await _api.get(ApiConstants.reportResultUrl(reportId));
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Backend trả về kết quả báo cáo không hợp lệ.');
    }
    return ReportResult.fromJson(data);
  }

  /// Gửi báo cáo; ném [ApiException] khi bị từ chối (báo cáo trùng, nội dung của chính mình...).
  Future<void> submit({
    required ReportTarget target,
    required int targetId,
    required ReportReason reason,
    String? detail,
    int? segmentIndex,
    String? grammarPattern,
  }) async {
    final trimmed = detail?.trim();
    await _api.post(
      ApiConstants.reportsUrl,
      body: {
        'targetType': target.name.toUpperCase(),
        'targetId': targetId,
        'reason': reason.code,
        if (trimmed != null && trimmed.isNotEmpty) 'detail': trimmed,
        'segmentIndex': ?segmentIndex,
        'grammarPattern': ?grammarPattern,
      },
    );
  }
}
