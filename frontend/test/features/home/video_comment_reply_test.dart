import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/home/data/models/video_comment.dart';

void main() {
  test('đọc được tên người được trả lời, bình luận gốc thì không có', () {
    final reply = VideoComment.fromJson({
      'id': 2,
      'videoId': 1,
      'parentId': 1,
      'replyToName': 'Lộc Shadow',
      'userId': 3,
      'username': 'loc',
      'displayName': 'Nguyễn Hữu Lộc',
      'content': 'test con khỉ khô',
    });
    final root = VideoComment.fromJson({
      'id': 1,
      'videoId': 1,
      'parentId': null,
      'userId': 4,
      'username': 'shadow',
      'displayName': 'Lộc Shadow',
      'content': 'test',
    });

    expect(reply.replyToName, 'Lộc Shadow');
    expect(root.replyToName, isNull);
  });
}
