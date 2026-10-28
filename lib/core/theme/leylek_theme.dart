import 'package:flutter/material.dart';

import 'leylek_colors.dart';

/// Uygulamanın Material 3 teması.
///
/// Görsel tasarım alternatifleri ayrıca konuşulacak; burada yalnızca
/// marka renkleri ve okunur bir temel var. Bileşenler renkleri
/// `Theme.of(context)` üzerinden alır, böylece tasarım değişince tek
/// dosya değişir.
abstract final class LeylekTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: LeylekColors.sky,
      primary: LeylekColors.wingtip,
      onPrimary: LeylekColors.feather,
      secondary: LeylekColors.beak,
      onSecondary: LeylekColors.feather,
      surface: LeylekColors.feather,
      onSurface: LeylekColors.wingtip,
      outline: LeylekColors.line,
    );

    return ThemeData(
      useMaterial3: true,
      // PAX ile aynı: gömülü yazı tipi yok, sistem yazı tipi (iOS'ta SF Pro,
      // Android'de Roboto) PAX'in ölçeğiyle kullanılır.
      textTheme: _textTheme(),
      colorScheme: scheme,
      scaffoldBackgroundColor: LeylekColors.mist,
      appBarTheme: const AppBarTheme(
        backgroundColor: LeylekColors.mist,
        foregroundColor: LeylekColors.wingtip,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: LeylekColors.feather,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: LeylekColors.line),
        ),
      ),
      // PAX'in alanları: dolgulu, çerçevesiz, sıkı.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LeylekColors.skySoft,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 18,
        ),
        labelStyle: const TextStyle(color: LeylekColors.muted, fontSize: 14),
        hintStyle: const TextStyle(color: LeylekColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: LeylekColors.skyDeep, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: LeylekColors.beakText,
            width: 1.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Butonlar göğün koyu tonunda; gaga turuncusu yalnızca logo ve
          // küçük vurgularda kalır.
          backgroundColor: LeylekColors.skyDeep,
          foregroundColor: LeylekColors.feather,
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }

  /// PAX'teki ölçek birebir.
  static TextTheme _textTheme() {
    final base = ThemeData(useMaterial3: true).textTheme;
    return base
        .copyWith(
          displaySmall: base.displaySmall?.copyWith(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.6,
            height: 1.15,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          titleMedium: base.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          titleSmall: base.titleSmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: base.bodyLarge?.copyWith(fontSize: 15, height: 1.45),
          bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
          bodySmall: base.bodySmall?.copyWith(
            fontSize: 12.5,
            color: LeylekColors.muted,
            height: 1.4,
          ),
          labelLarge: base.labelLarge?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(
          bodyColor: LeylekColors.wingtip,
          displayColor: LeylekColors.wingtip,
        );
  }
}
