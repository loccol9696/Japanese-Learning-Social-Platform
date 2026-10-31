import 'dart:convert';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/models/ruby_segment.dart';
import '../../domain/models/video_post.dart';

abstract class HomeRemoteDataSource {
  Future<List<VideoPost>> fetchForYouFeed();
  Future<List<VideoPost>> fetchFollowingFeed();
  /// Đặt trạng thái thích / lưu mong muốn (idempotent): gọi lại hay bấm đúp không làm đảo trạng thái.
  Future<bool> setLiked(String postId, {required bool liked});
  Future<bool> setSaved(String postId, {required bool saved});
  Future<bool> setFollow(int creatorId, {required bool follow});
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final ApiClient _apiClient;

  HomeRemoteDataSourceImpl({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  @override
  Future<List<VideoPost>> fetchForYouFeed() {
    // "recommended" = for-you xếp theo trình độ/sở thích; server tự quay về feed thường nếu chưa có.
    return _fetchFeed('recommended');
  }

  @override
  Future<List<VideoPost>> fetchFollowingFeed() {
    return _fetchFeed('following');
  }

  Future<List<VideoPost>> _fetchFeed(String feed) async {
    // Người xem (để biết đã thích / đã lưu) do server lấy từ access token.
    final response = await _apiClient.get(
      '${ApiConstants.baseUrl}/videos?feed=$feed&size=20',
    );

    if (response is! Map<String, dynamic>) {
      throw const FormatException('Backend trả về dữ liệu video không hợp lệ.');
    }

    final content = response['content'];
    if (content is! List) {
      throw const FormatException(
        'Backend không trả về danh sách video trong feed.',
      );
    }

    return content.whereType<Map<String, dynamic>>().map(_toVideoPost).toList();
  }

  @override
  Future<bool> setLiked(String postId, {required bool liked}) async {
    final url = '${ApiConstants.baseUrl}/videos/$postId/likes';
    if (liked) {
      await _apiClient.post(url);
    } else {
      await _apiClient.delete(url);
    }
    return liked;
  }

  @override
  Future<bool> setSaved(String postId, {required bool saved}) async {
    final url = '${ApiConstants.baseUrl}/videos/$postId/saves';
    if (saved) {
      await _apiClient.post(url);
    } else {
      await _apiClient.delete(url);
    }
    return saved;
  }

  /// Theo dõi / bỏ theo dõi người đăng. Trả về trạng thái follow sau khi server xử lý.
  @override
  Future<bool> setFollow(int creatorId, {required bool follow}) async {
    final response = follow
        ? await _apiClient.post(ApiConstants.followUrl(creatorId))
        : await _apiClient.delete(ApiConstants.followUrl(creatorId));
    return response is Map<String, dynamic> ? response['isFollowing'] == true : follow;
  }

  VideoPost _toVideoPost(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final title = json['title']?.toString() ?? 'Video bài học';
    final creatorName =
        (json['creatorDisplayName']?.toString().trim().isNotEmpty ?? false)
        ? json['creatorDisplayName'].toString()
        : (json['creatorUsername']?.toString() ?? 'JLSP Creator');
    final creatorUsername = json['creatorUsername']?.toString() ?? '';
    final creatorTag = creatorUsername.startsWith('@')
        ? creatorUsername
        : '@$creatorUsername';
    final thumbnailUrl = json['thumbnailUrl']?.toString() ?? '';
    final videoUrl = json['videoUrl']?.toString() ?? '';
    final creatorAvatarUrl = json['creatorAvatarUrl']?.toString() ?? '';
    final jlpt = json['jlptLevel']?.toString() ?? 'N5';
    final subtitleCues = _parseSubtitles(
      json['subtitles'],
      json['grammarAnalysis'],
    );
    final likes = _toInt(json['likeCount']);
    final views = _toInt(json['viewCount']);

    return VideoPost(
      id: id,
      backgroundImageUrl: _previewImageUrl(videoUrl, thumbnailUrl),
      videoUrl: videoUrl,
      creatorId: (json['creatorId'] as num?)?.toInt(),
      creatorName: creatorName,
      creatorTag: creatorTag,
      creatorAvatarUrl: creatorAvatarUrl,
      accentInfo: 'Japanese Learning',
      jlptLevel: jlpt.startsWith('JLPT') ? jlpt : 'JLPT $jlpt',
      topicTag: title,
      audioTitle: title,
      audioDiscImageUrl: creatorAvatarUrl.isNotEmpty
          ? creatorAvatarUrl
          : thumbnailUrl,
      rubySegments: subtitleCues.isNotEmpty
          ? [_toRubySegment(subtitleCues.first)]
          : const [],
      subtitleCues: subtitleCues,
      translation: subtitleCues.isNotEmpty
          ? subtitleCues.first.translation
          : json['description']?.toString() ?? '',
      likeCount: likes,
      commentCount: _toInt(json['commentCount']),
      shareCount: views,
      isLiked: json['isLiked'] == true,
      isSaved: json['isSaved'] == true,
      isFollowing: json['isFollowing'] == true,
      progress: 0,
      isLightBackground: false,
    );
  }

  VideoPost toVideoPost(Map<String, dynamic> json) => _toVideoPost(json);

  List<SubtitleCue> _parseSubtitles(
    dynamic rawSubtitles, [
    dynamic rawGrammarAnalysis,
  ]) {
    if (rawSubtitles is! String || rawSubtitles.trim().isEmpty) {
      return const [];
    }

    final grammarByIndex = <int, List<GrammarPointInfo>>{};
    final grammarByText = <String, List<GrammarPointInfo>>{};
    if (rawGrammarAnalysis is String && rawGrammarAnalysis.trim().isNotEmpty) {
      try {
        final decodedGa = jsonDecode(rawGrammarAnalysis);
        if (decodedGa is List) {
          for (var i = 0; i < decodedGa.length; i++) {
            final item = decodedGa[i];
            if (item is Map<String, dynamic> && item['grammarPoints'] is List) {
              final points = (item['grammarPoints'] as List)
                  .whereType<Map<String, dynamic>>()
                  .map(GrammarPointInfo.fromJson)
                  .where((p) => p.matchedText.isNotEmpty || p.pattern.isNotEmpty)
                  .toList();
              final idx = (item['index'] as num?)?.toInt() ?? i;
              grammarByIndex[idx] = points;
              final txt = item['text']?.toString().trim() ?? '';
              if (txt.isNotEmpty) {
                grammarByText[txt] = points;
              }
            }
          }
        }
      } catch (_) {}
    }

    try {
      final decoded = jsonDecode(rawSubtitles);
      if (decoded is! List) return const [];

      final cues = <SubtitleCue>[];
      final rawItems = decoded.whereType<Map<String, dynamic>>().toList();
      for (var i = 0; i < rawItems.length; i++) {
        final subtitle = rawItems[i];
        final text = subtitle['text']?.toString() ?? '';
        final translation =
            (subtitle['translation'] ?? subtitle['translatedText'])?.toString() ??
            '';
        final start = _parseTimestamp(subtitle['start'] ?? subtitle['startTime']);
        final end = _parseTimestamp(subtitle['end'] ?? subtitle['endTime']);
        if (text.isEmpty || end <= start) continue;

        List<GrammarPointInfo> points = const [];
        if (subtitle['grammarPoints'] is List) {
          points = (subtitle['grammarPoints'] as List)
              .whereType<Map<String, dynamic>>()
              .map(GrammarPointInfo.fromJson)
              .toList();
        }
        if (points.isEmpty) {
          points = grammarByIndex[i] ?? grammarByText[text.trim()] ?? const [];
        }

        cues.add(
          SubtitleCue(
            start: start,
            end: end,
            text: text,
            translation: translation,
            grammarPoints: points,
          ),
        );
      }
      return cues;
    } on FormatException {
      return const [];
    }
  }

  RubySegment _toRubySegment(SubtitleCue cue) {
    return RubySegment(kanji: cue.text, furigana: '');
  }

  Duration _parseTimestamp(dynamic value) {
    if (value is num) {
      return Duration(milliseconds: (value * 1000).round());
    }

    final parts = (value?.toString().trim() ?? '').split(':');
    if (parts.length != 2) return Duration.zero;

    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = double.tryParse(parts[1]) ?? 0;
    return Duration(milliseconds: ((minutes * 60 + seconds) * 1000).round());
  }

  int _toInt(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _previewImageUrl(String videoUrl, String thumbnailUrl) {
    const marker = '/video/upload/';
    final markerIndex = videoUrl.indexOf(marker);
    if (markerIndex >= 0 && videoUrl.endsWith('.mp4')) {
      final prefix = videoUrl.substring(0, markerIndex + marker.length);
      final publicId = videoUrl.substring(markerIndex + marker.length);
      final versionIndex = publicId.indexOf('/');
      final path = versionIndex >= 0
          ? publicId.substring(versionIndex + 1)
          : publicId;
      return '$prefix'
          'so_5/'
          '${path.substring(0, path.length - 4)}.jpg';
    }
    return thumbnailUrl;
  }
}
