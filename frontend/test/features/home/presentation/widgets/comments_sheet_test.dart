import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/home/presentation/widgets/comments_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _ago(Duration d) => DateTime.now().subtract(d).toIso8601String();

Map<String, dynamic> _comment({
  required int id,
  required String name,
  required String content,
  required Duration age,
  int? parentId,
  List<Map<String, dynamic>> replies = const [],
}) =>
    {
      'id': id,
      'videoId': 1,
      'parentId': parentId,
      'userId': 100 + id,
      'username': name.toLowerCase(),
      'displayName': name,
      'avatarUrl': '',
      'content': content,
      'createdAt': _ago(age),
      'replies': replies,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    ApiClient.overrideForTesting(MockClient((request) async {
      return http.Response(
        jsonEncode({
          'data': [
            _comment(
              id: 1,
              name: 'Shadow',
              content: 'test',
              age: const Duration(hours: 2),
              replies: [
                _comment(
                  id: 2,
                  name: 'Loc',
                  content: 'trả lời',
                  age: const Duration(minutes: 20),
                  parentId: 1,
                ),
              ],
            ),
            _comment(id: 3, name: 'Sakura', content: 'hello', age: const Duration(seconds: 10)),
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showCommentsSheet(context, videoId: '1', initialCount: 3),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  testWidgets('phản hồi bị ẩn cho tới khi bấm "Xem N câu trả lời", bấm "Ẩn" để thu lại', (tester) async {
    await openSheet(tester);

    expect(find.text('trả lời'), findsNothing);
    expect(find.text('20 phút trước'), findsNothing);
    expect(find.text('Xem 1 câu trả lời'), findsOneWidget);
    expect(find.text('Ẩn'), findsNothing);

    await tester.tap(find.text('Xem 1 câu trả lời'));
    await tester.pumpAndSettle();

    expect(find.text('trả lời'), findsOneWidget);
    expect(find.text('Xem 1 câu trả lời'), findsNothing);

    await tester.tap(find.text('Ẩn'));
    await tester.pumpAndSettle();

    expect(find.text('trả lời'), findsNothing);
    expect(find.text('Xem 1 câu trả lời'), findsOneWidget);
  });

  testWidgets('hiện tổng số bình luận, tên, thời gian và bình luận trả lời', (tester) async {
    await openSheet(tester);
    await tester.tap(find.text('Xem 1 câu trả lời'));
    await tester.pumpAndSettle();

    expect(find.text('3 bình luận'), findsOneWidget);
    expect(find.text('Shadow'), findsOneWidget);
    expect(find.text('2 giờ trước'), findsOneWidget);
    expect(find.text('20 phút trước'), findsOneWidget);
    expect(find.text('Vừa xong'), findsOneWidget);
    expect(find.text('test'), findsOneWidget);
    expect(find.text('trả lời'), findsOneWidget);
    // Dưới mỗi bình luận chỉ còn "Trả lời"; Báo cáo / Xóa nằm trong menu nhấn giữ.
    expect(find.text('Trả lời'), findsNWidgets(3));
    expect(find.text('Báo cáo'), findsNothing);
    expect(find.text('Xóa'), findsNothing);
    expect(find.text('Thêm bình luận...'), findsOneWidget);
  });

  testWidgets('bấm "Trả lời" hiện thanh "Đang trả lời" và đổi gợi ý nhập', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Trả lời').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Đang trả lời'), findsOneWidget);
    expect(find.text('Thêm phản hồi...'), findsOneWidget);
    expect(find.text('Thêm bình luận...'), findsNothing);
  });

  testWidgets('bình luận đang được trả lời được tô nổi bật, hủy thì trở lại như cũ', (tester) async {
    await openSheet(tester);

    bool hasHighlight() => tester
        .widgetList<Container>(find.byType(Container))
        .any((c) => c.color != null && c.padding != null);
    expect(hasHighlight(), isFalse);

    await tester.tap(find.text('Trả lời').first);
    await tester.pumpAndSettle();
    expect(hasHighlight(), isTrue);

    await tester.tap(find.byTooltip('Hủy trả lời'));
    await tester.pumpAndSettle();

    expect(hasHighlight(), isFalse);
    expect(find.textContaining('Đang trả lời'), findsNothing);
    expect(find.text('Thêm bình luận...'), findsOneWidget);
  });

  testWidgets('đóng bằng nút X', (tester) async {
    await openSheet(tester);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('3 bình luận'), findsNothing);
  });
}
