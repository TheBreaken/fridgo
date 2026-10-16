import 'package:flutter/material.dart';

abstract final class AppTheme {
  static final ThemeData light = _build(
    ColorScheme.fromSeed(seedColor: const Color(0xFF2E7A3A)).copyWith(
      primary: const Color(0xFF2E7A3A),
      onPrimary: const Color(0xFFFFFFFF),
      primaryContainer: const Color(0xFFDFEED8),
      onPrimaryContainer: const Color(0xFF17231A),
      tertiary: const Color(0xFFEF8A34),
      onTertiary: const Color(0xFF2B1600),
      surface: const Color(0xFFFFFFFF),
      surfaceDim: const Color(0xFFF2F7EF),
      onSurface: const Color(0xFF17231A),
      onSurfaceVariant: const Color(0xFF5A6A5D),
      outlineVariant: const Color(0xFFD4E1CF),
    ),
  );

  static final ThemeData dark = _build(
    ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7A3A),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF82D18C),
      onPrimary: const Color(0xFF0B2410),
      primaryContainer: const Color(0xFF22331F),
      onPrimaryContainer: const Color(0xFFE5EEE5),
      tertiary: const Color(0xFFFFB070),
      onTertiary: const Color(0xFF3A1D00),
      surface: const Color(0xFF18231B),
      surfaceDim: const Color(0xFF0F1712),
      onSurface: const Color(0xFFE5EEE5),
      onSurfaceVariant: const Color(0xFF9FB1A2),
      outlineVariant: const Color(0xFF2C3B2F),
    ),
  );

  // Cards sit on `surface`, the page behind them on `surfaceDim`: the one slot
  // that is darker than `surface` in both brightnesses.
  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, fontFamily: 'Nunito');
    final text = base.textTheme;
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surfaceDim,
      textTheme: text.copyWith(
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(backgroundColor: scheme.surfaceDim),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.large),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.tertiary,
        foregroundColor: scheme.onTertiary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Corners.large),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Corners.large),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Corners.small),
        ),
      ),
    );
  }
}

abstract final class Spacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class Corners {
  static const double small = 14;
  static const double large = 20;
}

abstract final class Sizes {
  static const double inlineIcon = 18;
  static const double icon = 48;
  static const double thumbnail = 64;
  static const double illustration = 72;
}
