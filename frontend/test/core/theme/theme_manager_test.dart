import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_palette.dart';
import 'package:frontend/core/theme/theme_manager.dart';
import 'package:frontend/core/theme/theme_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('đổi chế độ thì mọi getter màu đổi theo, không cần sửa nơi dùng', () async {
    await themeManager.setMode(ThemeMode.dark);
    expect(AppPalette.background, ThemePalette.dark.background);
    expect(AppColors.surface, ThemePalette.dark.surface);
    expect(AppColors.textPrimary, ThemePalette.dark.textPrimary);

    await themeManager.setMode(ThemeMode.light);
    expect(AppPalette.background, ThemePalette.light.background);
    expect(AppColors.surface, ThemePalette.light.surface);
    expect(AppColors.textPrimary, ThemePalette.light.textPrimary);
  });

  test('chế độ được lưu và khôi phục', () async {
    await themeManager.setMode(ThemeMode.light);
    await themeManager.setMode(ThemeMode.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');
  });

  test('nền tối là đen xám trung tính, nền sáng sáng hơn nền tối', () {
    for (final c in [
      ThemePalette.dark.background,
      ThemePalette.dark.surface,
      ThemePalette.dark.surfaceHigh,
    ]) {
      final r = (c.r * 255).round(), g = (c.g * 255).round(), b = (c.b * 255).round();
      expect((r - g).abs() <= 2 && (g - b).abs() <= 4, isTrue, reason: '$c lệch màu');
    }
    expect(
      ThemePalette.light.background.computeLuminance(),
      greaterThan(ThemePalette.dark.background.computeLuminance()),
    );
  });
}
