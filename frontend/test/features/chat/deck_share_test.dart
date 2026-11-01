import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/chat/data/models/chat_models.dart';
import 'package:frontend/features/chat/data/services/chat_service.dart';
import 'package:frontend/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:frontend/features/chat/presentation/widgets/deck_share_card.dart';
import 'package:frontend/features/chat/presentation/widgets/message_bubble.dart';
import 'package:frontend/features/chat/presentation/widgets/share_video_sheet.dart';
import 'package:frontend/features/flashcard/data/models/flashcard_set_model.dart';
import 'package:frontend/features/flashcard/presentation/screens/deck_overview_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

Map<String, dynamic> _deckMessageJson({bool available = true, String note = ''}) => {
      'id': 9,
      'conversationId': 1,
      'senderId': 3,
      'type': 'DECK_SHARE',
      'content': note,
      'clientMsgId': '',
      'createdAt': DateTime(2026, 10, 28, 9, 5).toIso8601String(),
      'deck': available
          ? {'id': 5, 'available': true, 'title': 'N2 xàm xàm', 'cardCount': 12}
          : {'id': 5, 'available': false},
    };

// FlashcardService là singleton giữ ApiClient đầu tiên nó thấy, nên chỉ cài MockClient một lần và đổi hàm xử lý.
Future<http.Response> Function(http.Request request)? _handler;
bool _mockInstalled = false;

void _useMock(Future<http.Response> Function(http.Request request) handler) {
  _handler = handler;
  if (_mockInstalled) return;
  _mockInstalled = true;
  ApiClient.overrideForTesting(MockClient((request) => _handler!(request)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('model', () {
    test('đọc tin DECK_SHARE kèm thông tin bộ thẻ', () {
      final message = ChatMessage.fromJson(_deckMessageJson(note: 'Học nhé'));

      expect(message.type, MessageType.deckShare);
      expect(message.deck!.id, 5);
      expect(message.deck!.available, isTrue);
      expect(message.deck!.title, 'N2 xàm xàm');
      expect(message.deck!.cardCount, 12);
      expect(message.content, 'Học nhé');
      expect(message.video, isNull);
    });

    test('bộ thẻ đã bị xoá thì available = false, không có tên', () {
      final message = ChatMessage.fromJson(_deckMessageJson(available: false));

      expect(message.deck!.available, isFalse);
      expect(message.deck!.title, isEmpty);
    });

    test('xem trước trong hộp thư: "🃏 tên bộ", thêm "Bạn: " với tin của mình, "Bộ thẻ" khi không còn khả dụng', () {
      final shared = ChatMessage.fromJson(_deckMessageJson());
      expect(shared.previewFor(7), '🃏 N2 xàm xàm');
      expect(shared.previewFor(3), 'Bạn: 🃏 N2 xàm xàm');
      expect(ChatMessage.fromJson(_deckMessageJson(available: false)).previewFor(7), '🃏 Bộ thẻ');
    });

    test('copyWith giữ nguyên bộ thẻ khi đổi trạng thái gửi', () {
      final message = ChatMessage.fromJson(_deckMessageJson());
      expect(message.copyWith(status: MessageStatus.failed).deck!.title, 'N2 xàm xàm');
    });

    test('loại tin lạ vẫn rơi về văn bản như trước', () {
      final json = _deckMessageJson()..['type'] = 'WHATEVER';
      expect(ChatMessage.fromJson(json).type, MessageType.text);
    });
  });

  group('DeckShareCard', () {
    testWidgets('hiện tên bộ và số thuật ngữ, bấm gọi onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DeckShareCard(
            deck: const SharedDeck(id: 5, available: true, title: 'N2 xàm xàm', cardCount: 12),
            onTap: () => taps++,
          ),
        ),
      ));

      expect(find.text('N2 xàm xàm'), findsOneWidget);
      expect(find.text('12 thuật ngữ'), findsOneWidget);
      await tester.tap(find.byType(DeckShareCard));
      expect(taps, 1);
    });

    testWidgets('bộ thẻ không còn khả dụng thì báo như vậy và không bấm được', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DeckShareCard(deck: const SharedDeck(id: 5, available: false), onTap: () => taps++),
        ),
      ));

      expect(find.text('Bộ thẻ không còn khả dụng'), findsOneWidget);
      await tester.tap(find.text('Bộ thẻ không còn khả dụng'));
      expect(taps, 0);
    });
  });

  group('MessageBubble', () {
    testWidgets('tin chia sẻ bộ thẻ hiện thẻ bộ + lời nhắn, bấm mở bộ thẻ', (tester) async {
      var opened = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: ChatMessage.fromJson(_deckMessageJson(note: 'Học bộ này nhé')),
            isMine: false,
            onOpenDeck: () => opened++,
          ),
        ),
      ));

      expect(find.byType(DeckShareCard), findsOneWidget);
      expect(find.text('N2 xàm xàm'), findsOneWidget);
      expect(find.text('Học bộ này nhé'), findsOneWidget);

      await tester.tap(find.byType(DeckShareCard));
      expect(opened, 1);
    });

    testWidgets('bộ thẻ không còn khả dụng: bấm không mở gì', (tester) async {
      var opened = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: ChatMessage.fromJson(_deckMessageJson(available: false)),
            isMine: true,
            onOpenDeck: () => opened++,
          ),
        ),
      ));

      await tester.tap(find.text('Bộ thẻ không còn khả dụng'));
      expect(opened, 0);
    });
  });

  group('bảng chia sẻ dùng chung', () {
    late List<http.Request> requests;
    var shareStatus = 200;
    var shareMessage = '';

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      await TokenStorage.instance.clear();
      await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
      requests = [];
      shareStatus = 200;
      shareMessage = '';
      _useMock((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('/flashcards/sets/5/share')) {
          return http.Response(
            jsonEncode({'status': shareStatus, 'message': shareMessage, 'data': <dynamic>[]}),
            shareStatus,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final Object data = path.endsWith('/chat/contacts')
            ? [
                {'id': 2, 'username': 'yuukachan', 'displayName': 'Yuuka', 'avatarUrl': ''},
                {'id': 3, 'username': 'haruto', 'displayName': 'Haruto', 'avatarUrl': ''},
              ]
            : (path.endsWith('/cards') ? <dynamic>[] : <String, dynamic>{});
        return http.Response(
          jsonEncode({'status': 200, 'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
    });

    Future<void> openDeckShare(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showShareDeckSheet(context, deckId: 5),
                child: const Text('chia sẻ'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('chia sẻ'));
      await tester.pumpAndSettle();
    }

    testWidgets('chọn bạn bè, nhập lời nhắn, gửi: gọi đúng API chia sẻ bộ thẻ rồi đóng bảng', (tester) async {
      await openDeckShare(tester);
      expect(find.text('Yuuka'), findsOneWidget);

      await tester.tap(find.text('Yuuka'));
      await tester.tap(find.text('Haruto'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Thêm lời nhắn (tuỳ chọn)').first, 'Học nhé');
      await tester.tap(find.text('Gửi (2)'));
      await tester.pumpAndSettle();

      final post = requests.lastWhere((r) => r.method == 'POST' && r.url.path.endsWith('/flashcards/sets/5/share'));
      final body = jsonDecode(post.body) as Map<String, dynamic>;
      expect(body['recipientIds'], [2, 3]);
      expect(body['note'], 'Học nhé');
      expect(find.byType(ShareFriendsSheet), findsNothing);
    });

    testWidgets('bộ thẻ riêng tư bị server từ chối: báo lỗi bằng toast, bảng vẫn mở để thử lại', (tester) async {
      shareStatus = 400;
      shareMessage = 'Bộ thẻ riêng tư chưa thể chia sẻ. Hãy chuyển sang công khai trước.';
      await openDeckShare(tester);

      await tester.tap(find.text('Yuuka'));
      await tester.pump();
      await tester.tap(find.text('Gửi (1)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('chưa thể chia sẻ'), findsOneWidget);
      expect(find.byType(ShareFriendsSheet), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('chưa chọn ai thì nút Gửi bị khoá', (tester) async {
      await openDeckShare(tester);

      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Gửi'));
      expect(button.onPressed, isNull);
    });

    test('ChatService.shareDeck gọi POST /flashcards/sets/{id}/share kèm người nhận và lời nhắn', () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      await TokenStorage.instance.clear();
      await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
      late http.Request seen;
      _useMock((request) async {
        seen = request;
        return http.Response(
          jsonEncode({'status': 200, 'data': <dynamic>[]}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await ChatService().shareDeck(5, recipientIds: [2], note: '  Học nhé  ');

      expect(seen.method, 'POST');
      expect(seen.url.path, endsWith('/flashcards/sets/5/share'));
      expect(jsonDecode(seen.body), {'recipientIds': [2], 'note': 'Học nhé'});
    });
  });

  group('màn bộ thẻ', () {
    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      await TokenStorage.instance.clear();
      await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
      _useMock((request) async {
        final path = request.url.path;
        final Object data = path.endsWith('/chat/contacts')
            ? [
                {'id': 2, 'username': 'yuukachan', 'displayName': 'Yuuka', 'avatarUrl': ''},
              ]
            : (path.endsWith('/cards') ? <dynamic>[] : <String, dynamic>{});
        return http.Response(
          jsonEncode({'status': 200, 'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
    });

    testWidgets('menu ba chấm có "Chia sẻ cho bạn bè" nằm trên "Chỉnh sửa" và "Xóa", bấm mở bảng chọn bạn bè',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: DeckOverviewScreen(deck: FlashcardSetModel(setId: 5, title: 'N2 xàm xàm')),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      final share = tester.getTopLeft(find.byKey(const ValueKey('deck-action-share'))).dy;
      final edit = tester.getTopLeft(find.byKey(const ValueKey('deck-action-edit'))).dy;
      final delete = tester.getTopLeft(find.byKey(const ValueKey('deck-action-delete'))).dy;
      expect(share, lessThan(edit));
      expect(edit, lessThan(delete));

      await tester.tap(find.byKey(const ValueKey('deck-action-share')));
      await tester.pumpAndSettle();

      expect(find.byType(ShareFriendsSheet), findsOneWidget);
      expect(find.text('Yuuka'), findsOneWidget);
    });
  });

  group('mở bộ thẻ từ khung chat', () {
    const other = ChatUser(id: 3, username: 'yuukachan', displayName: 'Yuuka', avatarUrl: '');
    const conversation = Conversation(
      id: 1,
      otherUser: other,
      lastMessage: null,
      unreadCount: 0,
      otherLastReadMessageId: null,
      canMessage: true,
      lastMessageAt: null,
    );
    late List<http.Request> requests;

    Future<void> openChat(WidgetTester tester, {required bool available}) async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      await TokenStorage.instance.clear();
      await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
      requests = [];
      _useMock((request) async {
        requests.add(request);
        final path = request.url.path;
        final Object data;
        if (path.endsWith('/chat/conversations/1/messages')) {
          data = {'content': [_deckMessageJson(available: available)], 'hasMore': false};
        } else if (path.endsWith('/chat/conversations/1')) {
          data = {
            'id': 1,
            'otherUser': {'id': 3, 'username': 'yuukachan', 'displayName': 'Yuuka', 'avatarUrl': ''},
            'unreadCount': 0,
            'canMessage': true,
          };
        } else if (path.endsWith('/flashcards/sets/5')) {
          data = {'setId': 5, 'title': 'N2 xàm xàm', 'totalCards': 12};
        } else if (path.endsWith('/cards')) {
          data = <dynamic>[];
        } else {
          data = <String, dynamic>{};
        }
        return http.Response(
          jsonEncode({'status': 200, 'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: ChatDetailScreen(conversation: conversation)));
      await tester.pumpAndSettle();
    }

    testWidgets('bấm thẻ bộ thẻ trong chat: tải bộ rồi mở màn tổng quan bộ thẻ', (tester) async {
      await openChat(tester, available: true);
      expect(find.byType(DeckShareCard), findsOneWidget);

      await tester.tap(find.byType(DeckShareCard));
      await tester.pumpAndSettle();

      expect(requests.any((r) => r.method == 'GET' && r.url.path.endsWith('/flashcards/sets/5')), isTrue);
      expect(find.byType(DeckOverviewScreen), findsOneWidget);
    });

    testWidgets('bộ thẻ không còn khả dụng: bấm không tải và không chuyển màn', (tester) async {
      await openChat(tester, available: false);

      await tester.tap(find.text('Bộ thẻ không còn khả dụng'));
      await tester.pumpAndSettle();

      expect(requests.any((r) => r.url.path.endsWith('/flashcards/sets/5')), isFalse);
      expect(find.byType(DeckOverviewScreen), findsNothing);
    });
  });
}
