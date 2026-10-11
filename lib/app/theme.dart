import 'package:flutter/material.dart';

class TempColors {
  static const background = Color(0xFFF6F1E8);
  static const surface = Color(0xFFFFFDF8);
  static const ink = Color(0xFF1C1917);
  static const box = Color(0xFFC4A574);
  static const seal = Color(0xFF1E3A5F);
  static const accent = Color(0xFFC2410C);
  static const danger = Color(0xFF9F1239);
  static const confirm = Color(0xFF0F766E);
}

class TempTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: TempColors.background,
      colorScheme: const ColorScheme.light(
        primary: TempColors.seal,
        onPrimary: Colors.white,
        secondary: TempColors.accent,
        surface: TempColors.surface,
        error: TempColors.danger,
        onSurface: TempColors.ink,
      ),
      fontFamily: 'Noto Sans KR',
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: TempColors.ink,
        displayColor: TempColors.ink,
        fontSizeFactor: 1,
      ).copyWith(
        bodyLarge: const TextStyle(fontSize: 16, height: 1.45, color: TempColors.ink),
        bodyMedium: const TextStyle(fontSize: 16, height: 1.45, color: TempColors.ink),
        titleLarge: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: TempColors.ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: TempColors.seal,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: TempColors.seal,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: TempColors.seal,
          side: const BorderSide(color: TempColors.seal, width: 1.4),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TempColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(fontSize: 16),
        hintStyle: const TextStyle(fontSize: 16, color: Color(0xFF78716C)),
        errorStyle: const TextStyle(fontSize: 14, color: TempColors.danger),
      ),
    );
  }
}

Duration motion(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) return Duration.zero;
  return const Duration(milliseconds: 220);
}
