import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Một chủ đề để chọn ở câu hỏi thứ hai.
class OnboardingTopic {
  final int id;
  final String name;

  const OnboardingTopic({required this.id, required this.name});

  factory OnboardingTopic.fromJson(Map<String, dynamic> json) {
    return OnboardingTopic(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

/// Trạng thái câu hỏi chào mừng do server trả về.
class OnboardingStatus {
  final bool needed;
  final String? jlptLevel;
  final List<int> topicIds;
  final List<OnboardingTopic> availableTopics;

  const OnboardingStatus({
    required this.needed,
    this.jlptLevel,
    this.topicIds = const [],
    this.availableTopics = const [],
  });

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) {
    final topics = json['availableTopics'];
    final ids = json['topicIds'];
    return OnboardingStatus(
      needed: json['needed'] as bool? ?? false,
      jlptLevel: json['jlptLevel']?.toString(),
      topicIds: ids is List
          ? ids.map((e) => (e as num).toInt()).toList()
          : const [],
      availableTopics: topics is List
          ? topics
                .whereType<Map<String, dynamic>>()
                .map(OnboardingTopic.fromJson)
                .toList()
          : const [],
    );
  }
}

/// Câu hỏi chào mừng: đọc trạng thái, lưu đáp án, bỏ qua. Mọi lời gọi đi kèm token của người dùng.
class OnboardingService {
  OnboardingService._();

  static final OnboardingService instance = OnboardingService._();

  Future<OnboardingStatus> getStatus() async {
    final data = await ApiClient.instance.get(ApiConstants.onboardingUrl);
    return OnboardingStatus.fromJson(data as Map<String, dynamic>);
  }

  Future<OnboardingStatus> save({
    required String jlptLevel,
    required Set<int> topicIds,
  }) async {
    final data = await ApiClient.instance.put(
      ApiConstants.onboardingUrl,
      body: {'jlptLevel': jlptLevel, 'topicIds': topicIds.toList()},
    );
    return OnboardingStatus.fromJson(data as Map<String, dynamic>);
  }

  Future<OnboardingStatus> skip() async {
    final data = await ApiClient.instance.post(ApiConstants.onboardingSkipUrl);
    return OnboardingStatus.fromJson(data as Map<String, dynamic>);
  }

  /// Có cần mở câu hỏi lúc này không. Lỗi mạng thì trả false: không bao giờ chặn người dùng vào app.
  Future<bool> needsOnboarding() async {
    try {
      return (await getStatus()).needed;
    } catch (e) {
      debugPrint('Không kiểm tra được câu hỏi chào mừng: $e');
      return false;
    }
  }
}
