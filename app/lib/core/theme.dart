import 'package:flutter/material.dart';

import 'config.dart';

/// 視覺語言（C10）：暖色紙感、圓角、大觸控目標、系統中文字型。
abstract final class AppColors {
  static const paper = Color(0xFFFBF6EC);
  static const card = Color(0xFFFFFDF8);
  static const ink = Color(0xFF3D3428);
  static const inkSoft = Color(0xFF7A6E5F);
  static const accent = Color(0xFFE59A5C); // 暖橘：主要按鈕
  static const accentSoft = Color(0xFFF7DCC3);
  static const leaf = Color(0xFF8DB596);
  static const sky = Color(0xFF9CC3D5);
  static const line = Color(0xFFE8DCC8);

  /// 家長建議、孩子還沒選的事：淡藍底＋藍邊。份量不比其他選項重（不更亮、不更大），
  /// 孩子一選就換成和自己選的一樣的顏色（企劃書模組一，決策 I4）。
  static const suggestSoft = Color(0xFFE6F0F4);
  static const suggestLine = sky;

  /// 回顧三個狀態按鈕共用同一個底色（底線 4：不用紅綠）。
  static const outcomeButton = Color(0xFFF3EAD9);

  /// 平板上步步的「舞台」：比紙色深一點的暖色底，和一圈更淡的光。
  static const stage = Color(0xFFF5E8D3);
  static const stageGlow = Color(0xFFFBF1E2);
}

abstract final class AppRadius {
  static const card = 20.0;
  static const button = 16.0;
  static const chip = 14.0;
  static const stage = 32.0;
}

abstract final class AppSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
}

/// [tablet]：平板上字、按鈕、選項都大一號（E12）。手機維持原本的大小。
ThemeData buildTheme({bool tablet = false}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    surface: AppColors.paper,
    primary: AppColors.accent,
    onSurface: AppColors.ink,
  );
  double t(double size) => tablet ? size + 2 : size;
  const tap = Size(AppConfig.minTapTarget, AppConfig.minTapTarget);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button));
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.paper,
    // 不打包字型；用系統中文字型（iOS PingFang TC／Android Noto Sans CJK）。
    fontFamilyFallback: const ['PingFang TC', 'Noto Sans CJK TC', 'Noto Sans TC'],
    textTheme: TextTheme(
      headlineSmall: TextStyle(fontSize: t(24), fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.4),
      titleMedium: TextStyle(fontSize: t(18), fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.4),
      bodyLarge: TextStyle(fontSize: t(18), color: AppColors.ink, height: 1.5),
      bodyMedium: TextStyle(fontSize: t(16), color: AppColors.ink, height: 1.5),
      labelLarge: TextStyle(fontSize: t(17), fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: tablet
            ? const Size(LayoutConfig.tabletButtonMinWidth, LayoutConfig.tabletButtonHeight)
            : const Size(160, 56),
        textStyle: TextStyle(fontSize: t(17), fontWeight: FontWeight.w600),
        shape: shape,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: tap, shape: shape, foregroundColor: AppColors.ink),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: tap, foregroundColor: AppColors.inkSoft),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.card,
      selectedColor: AppColors.accentSoft,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
      labelStyle: TextStyle(fontSize: t(17), color: AppColors.ink),
      padding: tablet
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}
