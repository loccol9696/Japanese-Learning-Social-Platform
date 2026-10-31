import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/video/presentation/screens/upload_video_screen.dart';

const _note1 = 'Độ dài tối ưu dưới 60 giây giúp ghi nhớ ngắt quãng (SRS) hiệu quả hơn.';
const _note2 = 'Phụ đề và Furigana được tạo tự động sau khi tải lên.';
const _note3 = 'Tuân thủ bản quyền và tiêu chuẩn cộng đồng.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(home: UploadVideoScreen()));
  }

  FilledButton submitButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Tải video lên'));

  testWidgets('tab "Tải tệp lên": khung chọn video, ghi chú gập, nút bị mờ', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Tải video lên'), findsNWidgets(2)); // tiêu đề + nút
    expect(find.text('Tải tệp lên'), findsOneWidget);
    expect(find.text('Liên kết YouTube'), findsOneWidget);
    expect(find.text('Chạm để chọn video'), findsOneWidget);
    expect(find.text('MP4, MOV · Tối đa 500MB'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);

    // Ghi chú đang gập
    expect(find.text('Lưu ý khi đăng video'), findsOneWidget);
    expect(find.text(_note1), findsNothing);

    // Chưa chọn video nên nút chưa bấm được
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('ghi chú mở ra 3 đoạn và gập lại khi bấm lần nữa', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Lưu ý khi đăng video'));
    await tester.pumpAndSettle();
    expect(find.text(_note1), findsOneWidget);
    expect(find.text(_note2), findsOneWidget);
    expect(find.text(_note3), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);

    await tester.tap(find.text('Lưu ý khi đăng video'));
    await tester.pumpAndSettle();
    expect(find.text(_note1), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
  });

  testWidgets('tab YouTube: ô dán liên kết, nút chỉ bấm được khi đã có liên kết', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Liên kết YouTube'));
    await tester.pumpAndSettle();

    // Nhãn của ô nhập (ngoài tên tab) và gợi ý
    expect(find.text('Liên kết YouTube'), findsNWidgets(2));
    expect(find.text('Dán liên kết video'), findsOneWidget);
    expect(find.text('Dán'), findsOneWidget);
    expect(find.text('Chạm để chọn video'), findsNothing);
    expect(submitButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    expect(submitButton(tester).onPressed, isNotNull);

    // Liên kết không phải YouTube
    await tester.tap(find.widgetWithText(FilledButton, 'Tải video lên'));
    await tester.pump();
    expect(find.text('Vui lòng nhập một đường link YouTube hợp lệ.'), findsOneWidget);

    // Liên kết YouTube hợp lệ (backend chưa hỗ trợ nên báo rõ cho người dùng)
    await tester.enterText(find.byType(TextField), 'https://youtu.be/abc123');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Tải video lên'));
    await tester.pump();
    expect(find.text('Backend chưa có API nhập video từ YouTube.'), findsOneWidget);
  });

  testWidgets('nút "Dán" lấy liên kết từ clipboard', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': '  https://youtube.com/shorts/xyz  '};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await pumpScreen(tester);

    await tester.tap(find.text('Liên kết YouTube'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dán'));
    await tester.pumpAndSettle();

    expect(find.text('https://youtube.com/shorts/xyz'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNotNull);
  });
}
