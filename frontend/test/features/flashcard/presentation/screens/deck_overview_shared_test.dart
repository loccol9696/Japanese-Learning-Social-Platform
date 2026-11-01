import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/flashcard/data/models/flashcard_set_model.dart';
import 'package:frontend/features/flashcard/presentation/screens/deck_overview_screen.dart';
import 'package:frontend/features/follow/presentation/screens/user_profile_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

Map<String, dynamic> _setJson({int id = 7, int? savedSetId, bool owner = false}) => {
      'setId': id,
      'title': 'Học chung với tớ hong',
      'isPublic': true,
      'authorId': 5,
      'authorName': 'Loc fake',
      'authorAvatarUrl': '',
      'totalCards': 19,
      'isOwner': owner,
      'savedSetId': savedSetId,
      'previewCards': <dynamic>[],
    };

const _saveLabel = 'Lưu về thư viện của tôi';
const _savedLabel = 'Đã lưu trong thư viện';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  // FlashcardService giữ ApiClient của lần dùng đầu, nên chỉ cài MockClient một lần và đổi hàm xử lý theo từng test.
  late http.Response Function(http.Request request) handler;
  var installed = false;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
    requests = [];
    handler = (request) {
      if (request.url.path.endsWith('/cards')) {
        return _json([
          {'cardId': 1, 'setId': 7, 'term': '秘密', 'meaning': 'bí mật'},
        ]);
      }
      return _json(<String, dynamic>{});
    };
    if (!installed) {
      installed = true;
      ApiClient.overrideForTesting(MockClient((request) async {
        requests.add(request);
        return handler(request);
      }));
    }
  });

  Future<void> open(
    WidgetTester tester,
    FlashcardSetModel deck, {
    String? sharedBy,
    int? sharedByUserId,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      home: DeckOverviewScreen(
        deck: deck,
        sharedByName: sharedBy,
        sharedByUserId: sharedByUserId,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('bộ thẻ bạn bè chia sẻ: hiện "Chia sẻ bởi", nút lưu, không có loa, sao, bánh răng', (tester) async {
    await open(tester, FlashcardSetModel.fromJson(_setJson()), sharedBy: 'Loc fake');

    expect(find.byKey(const ValueKey('deck-shared-info')), findsOneWidget);
    expect(find.text('19 thuật ngữ · Chia sẻ bởi '), findsOneWidget);
    expect(find.text(_saveLabel), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('deck-save-button')),
        matching: find.byIcon(Icons.add_rounded),
      ),
      findsNothing,
    );
    expect(find.text(_savedLabel), findsNothing);
    // Đúng thiết kế: chỉ có nút quay lại, thẻ không có loa và sao.
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
    expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    expect(find.text('Ghép thẻ'), findsOneWidget);
  });

  testWidgets('bấm tên người chia sẻ thì mở trang cá nhân của họ', (tester) async {
    await open(
      tester,
      FlashcardSetModel.fromJson(_setJson()),
      sharedBy: 'Loc fake',
      sharedByUserId: 42,
    );

    await tester.tap(find.byKey(const ValueKey('deck-sharer-profile-link')));
    await tester.pump();

    final profile = tester.widget<UserProfileScreen>(find.byType(UserProfileScreen));
    expect(profile.userId, 42);
    expect(profile.initialName, 'Loc fake');
  });

  testWidgets('không biết ai chia sẻ thì ghi "Tác giả" theo chủ bộ thẻ', (tester) async {
    await open(tester, FlashcardSetModel.fromJson(_setJson()));

    expect(find.textContaining('Tác giả'), findsOneWidget);
    expect(find.textContaining('Chia sẻ bởi'), findsNothing);
  });

  testWidgets('người chia sẻ khác tác giả thì hiện thêm dòng tác giả', (tester) async {
    await open(tester, FlashcardSetModel.fromJson(_setJson()), sharedBy: 'Haruto');

    expect(find.textContaining('Chia sẻ bởi'), findsOneWidget);
    expect(find.text('Tác giả: Loc fake'), findsOneWidget);
  });

  testWidgets('bấm Lưu: gọi POST copy rồi đổi thành "Đã lưu trong thư viện"', (tester) async {
    handler = (request) {
      if (request.method == 'POST' && request.url.path.endsWith('/flashcards/sets/7/copy')) {
        return _json(_setJson(id: 99, owner: true));
      }
      if (request.url.path.endsWith('/cards')) return _json(<dynamic>[]);
      return _json(<String, dynamic>{});
    };
    await open(tester, FlashcardSetModel.fromJson(_setJson()), sharedBy: 'Loc fake');

    await tester.tap(find.byKey(const ValueKey('deck-save-button')));
    await tester.pumpAndSettle();

    final posts = requests.where((r) => r.method == 'POST' && r.url.path.endsWith('/flashcards/sets/7/copy'));
    expect(posts, hasLength(1));
    expect(find.text(_savedLabel), findsOneWidget);
    expect(find.text(_saveLabel), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('đã lưu từ trước (server báo savedSetId): hiện ngay "Đã lưu trong thư viện", không gọi lưu lại', (tester) async {
    handler = (request) {
      if (request.url.path.endsWith('/flashcards/sets/99')) return _json(_setJson(id: 99, owner: true));
      if (request.url.path.endsWith('/cards')) return _json(<dynamic>[]);
      return _json(<String, dynamic>{});
    };
    await open(tester, FlashcardSetModel.fromJson(_setJson(savedSetId: 99)), sharedBy: 'Loc fake');

    expect(find.text(_savedLabel), findsOneWidget);
    expect(find.text(_saveLabel), findsNothing);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });

  testWidgets('lưu lỗi thì giữ nút "Lưu" để thử lại', (tester) async {
    handler = (request) {
      if (request.method == 'POST') {
        return http.Response(
          jsonEncode({'status': 400, 'message': 'Đây đã là bộ thẻ của bạn'}),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.endsWith('/cards')) return _json(<dynamic>[]);
      return _json(<String, dynamic>{});
    };
    await open(tester, FlashcardSetModel.fromJson(_setJson()), sharedBy: 'Loc fake');

    await tester.tap(find.byKey(const ValueKey('deck-save-button')));
    await tester.pumpAndSettle();

    expect(find.text(_saveLabel), findsOneWidget);
    expect(find.text(_savedLabel), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('bộ thẻ của chính mình: không có thông tin chia sẻ và không có nút lưu', (tester) async {
    handler = (request) => request.url.path.endsWith('/cards') ? _json(<dynamic>[]) : _json(<String, dynamic>{});
    await open(tester, FlashcardSetModel.fromJson(_setJson(owner: true)));

    expect(find.byKey(const ValueKey('deck-shared-info')), findsNothing);
    expect(find.text(_saveLabel), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('chưa lưu mà bấm "Thẻ ghi nhớ" thì nhắc lưu trước, không mở màn học', (tester) async {
    await open(tester, FlashcardSetModel.fromJson(_setJson()), sharedBy: 'Loc fake');

    await tester.tap(find.text('Thẻ ghi nhớ'));
    await tester.pump();

    expect(find.textContaining('lưu bộ thẻ về thư viện'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}

http.Response _json(Object data) => http.Response(
      jsonEncode({'status': 200, 'data': data}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
