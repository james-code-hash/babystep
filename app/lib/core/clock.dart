import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 可替換的時鐘：測試用固定時間，App 用系統時間。
class Clock {
  const Clock();
  DateTime now() => DateTime.now();

  /// 時間會不會自己往前走。[FixedClock] 不會，所以不用排過午夜的計時器。
  bool get ticks => true;
}

class FixedClock extends Clock {
  FixedClock(this.fixed);
  DateTime fixed;
  @override
  DateTime now() => fixed;

  @override
  bool get ticks => false;
}

final clockProvider = Provider<Clock>((ref) => const Clock());

/// 一天的 key：本地日期 `YYYY-MM-DD`。
String dayKeyOf(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}';
}

DateTime dateOfDayKey(String dayKey) {
  final p = dayKey.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// 今天的 dayKey。
///
/// App 一直開在前景跨過午夜時，自己換成新的一天（從背景回來則由首頁 invalidate）。
final todayKeyProvider = Provider<String>((ref) {
  final clock = ref.watch(clockProvider);
  final now = clock.now();
  if (clock.ticks) {
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final timer = Timer(midnight.difference(now) + const Duration(seconds: 1), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return dayKeyOf(now);
});
