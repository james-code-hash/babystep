import 'dart:math';

import '../copy/bubu.dart';
import '../copy/line.dart';
import '../domain/models.dart' show AgeTone;
import '../core/config.dart';
import 'look.dart' show DayPart, Season, dayPartOf, seasonOf;

/// 首頁問候。只能吃（語氣、日期時間、隨機）——不讀計畫、回顧、上次開啟（底線 2、3）。
///
/// 大多數時候依時段抽；偶爾（[BubuConfig.seasonalGreetingChance]）抽一句季節的話。
String greeting(AgeTone tone, DateTime now, Random random) {
  final pool = random.nextDouble() < BubuConfig.seasonalGreetingChance
      ? seasonalGreetings(seasonOf(now))
      : dayPartGreetings(dayPartOf(now));
  return pool.pick(tone, random);
}

LinePool dayPartGreetings(DayPart part) => switch (part) {
      DayPart.morning => BubuCopy.greetingsMorning,
      DayPart.day => BubuCopy.greetingsDay,
      DayPart.evening => BubuCopy.greetingsEvening,
      DayPart.night => BubuCopy.greetingsNight,
    };

LinePool seasonalGreetings(Season season) => switch (season) {
      Season.spring => BubuCopy.greetingsSpring,
      Season.summer => BubuCopy.greetingsSummer,
      Season.autumn => BubuCopy.greetingsAutumn,
      Season.winter => BubuCopy.greetingsWinter,
    };

/// 所有問候池（給測試與 copy lint 用）。
List<LinePool> get allGreetingPools => [
      BubuCopy.greetings,
      for (final p in DayPart.values) dayPartGreetings(p),
      for (final s in Season.values) seasonalGreetings(s),
    ];
