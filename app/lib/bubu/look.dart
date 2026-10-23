import 'dart:ui' show Color;

import '../domain/models.dart' show DressUp;
import 'bubu_config.dart';
import 'catalog.dart';

/// 季節（台灣，北半球）。
enum Season { spring, summer, autumn, winter }

/// 一天的時段。不叫 `TimeOfDay`，免得和 Flutter material 的 `TimeOfDay` 撞名。
enum DayPart { morning, day, evening, night }

/// 步步身邊的小裝飾，只跟季節與時段有關。
enum Ambient { petals, sparkle, leaf, snowflake, sunsetGlow, moon, stars }

/// 一組身體配色。
class BubuPalette {
  const BubuPalette({
    required this.body,
    required this.bodyLight,
    required this.outline,
    required this.belly,
    required this.cheek,
  });

  final Color body;
  final Color bodyLight;
  final Color outline;
  final Color belly;
  final Color cheek;

  BubuPalette lerpTo(Color target, double t) => BubuPalette(
        body: Color.lerp(body, target, t)!,
        bodyLight: Color.lerp(bodyLight, target, t)!,
        outline: Color.lerp(outline, target, t)!,
        belly: Color.lerp(belly, target, t)!,
        cheek: Color.lerp(cheek, target, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is BubuPalette &&
      other.body == body &&
      other.bodyLight == bodyLight &&
      other.outline == outline &&
      other.belly == belly &&
      other.cheek == cheek;

  @override
  int get hashCode => Object.hash(body, bodyLight, outline, belly, cheek);
}

/// 步步這一刻長什麼樣子。
///
/// 底線 2：只由（裝扮, 時間）決定。這裡沒有、也不能有任何計畫、回顧、使用紀錄的欄位。
class BubuLook {
  const BubuLook({
    required this.palette,
    required this.hat,
    required this.neck,
    required this.season,
    required this.dayPart,
    required this.ambient,
  });

  final BubuPalette palette;

  /// [BubuCatalog.hats] 的 id；不認得的 id 已經換成 `none`。
  final String hat;

  /// [BubuCatalog.necks] 的 id；不認得的 id 已經換成 `none`。
  final String neck;
  final Season season;
  final DayPart dayPart;
  final List<Ambient> ambient;

  bool get isNight => dayPart == DayPart.night;

  @override
  bool operator ==(Object other) =>
      other is BubuLook &&
      other.palette == palette &&
      other.hat == hat &&
      other.neck == neck &&
      other.season == season &&
      other.dayPart == dayPart &&
      _sameList(other.ambient, ambient);

  @override
  int get hashCode => Object.hash(palette, hat, neck, season, dayPart, Object.hashAll(ambient));

  static bool _sameList(List<Ambient> a, List<Ambient> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 每個顏色 id 的配色。key 必須和 [BubuCatalog.colors] 一致（有測試檢查）。
const bubuPalettes = <String, BubuPalette>{
  'cream': BubuPalette(
    body: Color(0xFFF2D9AE),
    bodyLight: Color(0xFFFBEBCF),
    outline: Color(0xFFC79A62),
    belly: Color(0xFFFFF8EA),
    cheek: Color(0xFFF4B39A),
  ),
  'peach': BubuPalette(
    body: Color(0xFFF5B794),
    bodyLight: Color(0xFFFAD3BC),
    outline: Color(0xFFD08460),
    belly: Color(0xFFFFF1E8),
    cheek: Color(0xFFEE9488),
  ),
  'mint': BubuPalette(
    body: Color(0xFFB9DDC4),
    bodyLight: Color(0xFFD8EEDD),
    outline: Color(0xFF7DAE8C),
    belly: Color(0xFFF4FBF5),
    cheek: Color(0xFFF2B0A0),
  ),
  'sky': BubuPalette(
    body: Color(0xFFB7D5E6),
    bodyLight: Color(0xFFD6E8F2),
    outline: Color(0xFF7BA4BD),
    belly: Color(0xFFF3F9FC),
    cheek: Color(0xFFF2B2A6),
  ),
  'lavender': BubuPalette(
    body: Color(0xFFD3C4E6),
    bodyLight: Color(0xFFE6DCF2),
    outline: Color(0xFF9F8BBE),
    belly: Color(0xFFFAF6FD),
    cheek: Color(0xFFF1AFB4),
  ),
  'cocoa': BubuPalette(
    body: Color(0xFFC79D7B),
    bodyLight: Color(0xFFDDBB9C),
    outline: Color(0xFF8E6546),
    belly: Color(0xFFF6E6D6),
    cheek: Color(0xFFEFA28E),
  ),
};

/// 晚上配色靠過去的夜色。
const nightTint = Color(0xFF5B5F86);

Season seasonOf(DateTime t) => switch (t.month) {
      3 || 4 || 5 => Season.spring,
      6 || 7 || 8 => Season.summer,
      9 || 10 || 11 => Season.autumn,
      _ => Season.winter,
    };

DayPart dayPartOf(DateTime t) {
  final h = t.hour;
  if (h >= BubuConfig.nightStartHour || h < BubuConfig.morningStartHour) return DayPart.night;
  if (h >= BubuConfig.eveningStartHour) return DayPart.evening;
  if (h >= BubuConfig.dayStartHour) return DayPart.day;
  return DayPart.morning;
}

bool _known(List<Accessory> items, String id) => items.any((a) => a.id == id);

/// 算出步步的樣子。**只吃這兩個輸入**：孩子主動選的裝扮、現在的時間。
BubuLook look(DressUp dressUp, DateTime now) {
  final season = seasonOf(now);
  final part = dayPartOf(now);

  var palette = bubuPalettes[dressUp.color] ?? bubuPalettes['cream']!;
  if (part == DayPart.night) palette = palette.lerpTo(nightTint, BubuConfig.nightSoftening);

  final ambient = <Ambient>[
    switch (season) {
      Season.spring => Ambient.petals,
      Season.summer => Ambient.sparkle,
      Season.autumn => Ambient.leaf,
      Season.winter => Ambient.snowflake,
    },
    if (part == DayPart.evening) Ambient.sunsetGlow,
    if (part == DayPart.night) ...[Ambient.moon, Ambient.stars],
  ];

  return BubuLook(
    palette: palette,
    hat: _known(BubuCatalog.hats, dressUp.hat) ? dressUp.hat : 'none',
    neck: _known(BubuCatalog.necks, dressUp.neck) ? dressUp.neck : 'none',
    season: season,
    dayPart: part,
    ambient: List.unmodifiable(ambient),
  );
}
