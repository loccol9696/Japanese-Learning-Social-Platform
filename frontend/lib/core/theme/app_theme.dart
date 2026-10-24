import 'package:flutter/material.dart';

import 'theme_palette.dart';

/// Dựng [ThemeData] từ [ThemePalette]. Không có màu nào được viết cứng ở đây:
/// thêm / sửa màu thì sửa trong [ThemePalette].
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => fromPalette(ThemePalette.dark);
  static ThemeData get lightTheme => fromPalette(ThemePalette.light);

  static ThemeData fromPalette(ThemePalette p) {
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.accent,
      onSecondary: p.onAccent,
      tertiary: p.info,
      error: p.error,
      onError: p.onAccent,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      outline: p.textSecondary,
      outlineVariant: p.border,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceHigh,
      surfaceContainerHighest: p.surfaceHighest,
      shadow: p.shadow,
      scrim: p.scrim,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      // Font tiếng Nhật đóng gói sẵn trong app (xem pubspec.yaml) để chữ Hán
      // luôn hiển thị ngay, không bị ô vuông chờ tải font dự phòng.
      fontFamilyFallback: const ['NotoSansJP'],
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      primaryColor: p.accent,
      colorScheme: scheme,
      dividerColor: p.border,
      dividerTheme: DividerThemeData(color: p.border, thickness: 1),
      cardTheme: CardThemeData(color: p.surface, elevation: 0),
      dialogTheme: DialogThemeData(backgroundColor: p.surface),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBarrierColor: p.scrim,
      ),
      popupMenuTheme: PopupMenuThemeData(color: p.surfaceHigh),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceHigh,
        contentTextStyle: TextStyle(color: p.textPrimary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
      iconTheme: IconThemeData(color: p.textPrimary),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: p.textSecondary),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accentSoft,
        selectionHandleColor: p.accent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: p.textPrimary),
        foregroundColor: p.textPrimary,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: p.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.01,
        ),
        titleMedium: TextStyle(
          color: p.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: p.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: p.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelSmall: TextStyle(
          color: p.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.02,
        ),
      ),
    );
  }
}
