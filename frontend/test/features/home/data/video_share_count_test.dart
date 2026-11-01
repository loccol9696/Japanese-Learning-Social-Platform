import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/home/data/datasources/home_remote_datasource.dart';

void main() {
  final dataSource = HomeRemoteDataSourceImpl();

  Map<String, dynamic> video(Map<String, dynamic> extra) => {
    'id': 9,
    'title': 'Bài 1',
    'creatorUsername': 'owner',
    'jlptLevel': 'N5',
    'viewCount': 1234,
    ...extra,
  };

  test('số chia sẻ lấy từ shareCount của backend, không phải lượt xem', () {
    final post = dataSource.toVideoPost(video({'shareCount': 7}));

    expect(post.shareCount, 7);
  });

  test('backend chưa trả shareCount thì là 0 chứ không lấy lượt xem', () {
    final post = dataSource.toVideoPost(video({}));

    expect(post.shareCount, 0);
  });
}
