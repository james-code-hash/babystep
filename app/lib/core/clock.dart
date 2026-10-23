import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 可替換的時鐘：測試用固定時間，App 用系統時間。
class Clock {
  const Clock();
  DateTime now() => DateTime.now();
}

class FixedClock extends Clock {
  FixedClock(this.fixed);
  DateTime fixed;
  @override
  DateTime now() => fixed;
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
final todayKeyProvider = Provider<String>((ref) => dayKeyOf(ref.watch(clockProvider).now()));
