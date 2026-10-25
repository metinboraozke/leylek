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
      // Modern, geometrik ve Türkçe karakterleri tam destekleyen gömülü yazı tipi.
      fontFamily: 'PlusJakartaSans',
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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LeylekColors.feather,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LeylekColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LeylekColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: LeylekColors.wingtip, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: LeylekColors.beak,
          foregroundColor: LeylekColors.feather,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
