import 'dart:convert';

import '../../domain/models/ruby_segment.dart';
import '../../domain/models/video_post.dart';

/// Map một `VideoResponse` (JSON backend) thành [VideoPost] cho trình phát video.
VideoPost videoPostFromJson(Map<String, dynamic> json) {
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
    backgroundImageUrl: videoPreviewImageUrl(videoUrl, thumbnailUrl),
    videoUrl: videoUrl,
    creatorName: creatorName,
    creatorTag: creatorTag,
    creatorAvatarUrl: creatorAvatarUrl,
    accentInfo: '',
    jlptLevel: jlpt.startsWith('JLPT') ? jlpt : 'JLPT $jlpt',
    topicTag: title,
    audioTitle: creatorName, // UI ghép thành "Âm thanh gốc - <người đăng>"
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
    commentCount: 0,
    shareCount: 0, // backend chưa đếm lượt chia sẻ
    viewCount: views,
    isLiked: json['isLiked'] == true,
    progress: 0,
    isLightBackground: false,
  );
}

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

/// Ảnh xem trước của video Cloudinary: khung giây thứ 5 (khung đầu thường là màn
/// trắng/đen); không phải Cloudinary thì dùng [thumbnailUrl].
String videoPreviewImageUrl(String videoUrl, String thumbnailUrl) {
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
