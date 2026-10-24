import 'dart:convert';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/models/ruby_segment.dart';
import '../../domain/models/video_post.dart';

abstract class HomeRemoteDataSource {
  Future<List<VideoPost>> fetchForYouFeed();
  Future<List<VideoPost>> fetchFollowingFeed();
  Future<bool> toggleLike(String postId);
  Future<bool> toggleSave(String postId);
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  final ApiClient _apiClient;

  HomeRemoteDataSourceImpl({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient.instance;

  @override
  Future<List<VideoPost>> fetchForYouFeed() {
    return _fetchFeed('for-you');
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
  Future<bool> toggleLike(String postId) async {
    final response = await _apiClient.post(
      '${ApiConstants.baseUrl}/videos/$postId/like',
    );
    return response is bool ? response : true;
  }

  @override
  Future<bool> toggleSave(String postId) async {
    final response = await _apiClient.post(
      '${ApiConstants.baseUrl}/videos/$postId/save',
    );
    return response is bool ? response : true;
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
    final subtitleCues = _parseSubtitles(json['subtitles']);
    final likes = _toInt(json['likeCount']);
    final views = _toInt(json['viewCount']);

    return VideoPost(
      id: id,
      backgroundImageUrl: _previewImageUrl(videoUrl, thumbnailUrl),
      videoUrl: videoUrl,
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
      progress: 0,
      isLightBackground: false,
    );
  }

  VideoPost toVideoPost(Map<String, dynamic> json) => _toVideoPost(json);

  List<SubtitleCue> _parseSubtitles(dynamic rawSubtitles) {
    if (rawSubtitles is! String || rawSubtitles.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawSubtitles);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map<String, dynamic>>()
          .map((subtitle) {
            return SubtitleCue(
              start: _parseTimestamp(subtitle['start']),
              end: _parseTimestamp(subtitle['end']),
              text: subtitle['text']?.toString() ?? '',
              translation: subtitle['translation']?.toString() ?? '',
            );
          })
          .where((cue) => cue.text.isNotEmpty && cue.end > cue.start)
          .toList();
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
