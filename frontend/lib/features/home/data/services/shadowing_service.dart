import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/models/shadowing_models.dart';

/// Gọi API chấm điểm luyện nói nhại theo từng dòng phụ đề.
class ShadowingService {
  ShadowingService._();
  static final ShadowingService instance = ShadowingService._();

  final ApiClient _api = ApiClient.instance;

  /// Gửi câu nhận dạng được trên thiết bị để server chấm với dòng [lineIndex].
  Future<ShadowingLineScore> scoreLine({
    required String videoId,
    required int lineIndex,
    required String recognizedText,
  }) async {
    final res = await _api.post(
      ApiConstants.shadowingScoreUrl(videoId, lineIndex),
      body: {'recognizedText': recognizedText},
      withAuth: true,
    );
    return ShadowingLineScore.fromJson(res as Map<String, dynamic>);
  }

  Future<ShadowingSummary> summary(String videoId) async {
    final res = await _api.get(
      ApiConstants.shadowingSummaryUrl(videoId),
      withAuth: true,
    );
    return ShadowingSummary.fromJson(res as Map<String, dynamic>);
  }
}
