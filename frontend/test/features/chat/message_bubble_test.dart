import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/data/models/chat_models.dart';
import 'package:frontend/features/chat/presentation/widgets/message_bubble.dart';
import 'package:frontend/features/chat/presentation/widgets/video_share_card.dart';

ChatMessage _text(
  String content, {
  MessageStatus status = MessageStatus.sent,
}) => ChatMessage(
  id: status == MessageStatus.sent ? 1 : null,
  conversationId: 1,
  senderId: 3,
  type: MessageType.text,
  content: content,
  clientMsgId: 'c',
  createdAt: DateTime(2026, 10, 24, 9, 5),
  status: status,
);

ChatMessage _share({bool available = true, int? startMs}) => ChatMessage(
  id: 2,
  conversationId: 1,
  senderId: 3,
  type: MessageType.videoShare,
  content: 'この文を聞いて',
  videoStartMs: startMs,
  clientMsgId: '',
  createdAt: DateTime(2026, 10, 24, 9, 6),
  video: SharedVideo(
    id: 9,
    available: available,
    title: 'Shadowing N3: 駅での会話とても長いタイトルがここに入りますよ',
    duration: 75,
    jlptLevel: 'N3',
    creatorName: 'Tanaka Sensei',
  ),
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 320,
}) async {
  tester.view.physicalSize = Size(width, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('text bubble shows content and time, mine and theirs', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        children: [
          MessageBubble(
            message: _text('Xin chào'),
            isMine: true,
            showSeen: true,
          ),
          MessageBubble(message: _text('Chào bạn ' * 30), isMine: false),
        ],
      ),
    );
    expect(find.text('Xin chào'), findsOneWidget);
    expect(find.text('Đã xem'), findsOneWidget);
    expect(find.text('09:05'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed message can be retried', (tester) async {
    var retried = 0;
    await _pump(
      tester,
      MessageBubble(
        message: _text('lỗi', status: MessageStatus.failed),
        isMine: true,
        onRetry: () => retried++,
      ),
    );
    expect(find.textContaining('bấm để gửi lại'), findsOneWidget);
    await tester.tap(find.byTooltip('Gửi lại'));
    expect(retried, 1);
  });

  testWidgets('video share shows card, timestamp and note without overflow', (
    tester,
  ) async {
    var opened = 0;
    await _pump(
      tester,
      MessageBubble(
        message: _share(startMs: 12500),
        isMine: false,
        onOpenVideo: () => opened++,
      ),
    );
    expect(find.textContaining('Shadowing N3'), findsOneWidget);
    expect(find.text('Xem từ 00:12'), findsOneWidget);
    expect(find.text('N3'), findsOneWidget);
    expect(find.text('01:15'), findsOneWidget);
    expect(find.text('この文を聞いて'), findsOneWidget);
    await tester.tap(find.byType(VideoShareCard));
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable shared video is not tappable', (tester) async {
    var opened = 0;
    await _pump(
      tester,
      MessageBubble(
        message: _share(available: false),
        isMine: false,
        onOpenVideo: () => opened++,
      ),
    );
    expect(find.text('Video không còn khả dụng'), findsOneWidget);
    await tester.tap(find.text('Video không còn khả dụng'));
    expect(opened, 0);
  });
}
