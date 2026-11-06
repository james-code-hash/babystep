import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../copy/plan.dart';
import '../../core/config.dart';
import '../../domain/models.dart';

/// 探頭提醒今天出現過幾次（D4）。只在記憶體，App 重開就歸零；不寫入資料庫、不給家長、不影響回顧。
class PeekCount {
  const PeekCount(this.dayKey, this.shown);
  final String dayKey;
  final int shown;
}

class PeekCounter extends Notifier<PeekCount> {
  @override
  PeekCount build() => const PeekCount('', 0);

  int shownOn(String dayKey) => state.dayKey == dayKey ? state.shown : 0;

  bool canShow(String dayKey) => shownOn(dayKey) < AppConfig.maxPeeksPerDay;

  void markShown(String dayKey) => state = PeekCount(dayKey, shownOn(dayKey) + 1);
}

final peekCounterProvider = NotifierProvider<PeekCounter, PeekCount>(PeekCounter.new);

/// 要不要探頭：現在在某個提醒時段內、今天有計畫、還沒聊完、今天還沒探頭到上限。
bool shouldPeek({
  required DateTime now,
  required AppSettings settings,
  required List<Plan> plans,
  required DayRecord? record,
  required bool underDailyLimit,
}) =>
    underDailyLimit &&
    plans.isNotEmpty &&
    !(record?.ended ?? false) &&
    settings.reminderSlots.any((s) => s.contains(now));

const _cueWindows = [
  (PlanCopy.cueHintsMorning, CueTimeConfig.morning),
  (PlanCopy.cueHintsNoon, CueTimeConfig.noon),
  (PlanCopy.cueHintsDinner, CueTimeConfig.dinner),
  (PlanCopy.cueHintsNight, CueTimeConfig.night),
  (PlanCopy.cueHintsAfterSchool, CueTimeConfig.afterSchool),
];

/// 時間點大概落在一天的哪一段；看不出來就回傳 null（隨時都可能）。
({int start, int end})? cueWindow(String cue) {
  for (final (hints, window) in _cueWindows) {
    if (hints.any(cue.contains)) return window;
  }
  return null;
}

/// 探頭要提哪一件、要不要帶時間點（README 已知問題 1）：
/// 1. 時間點落在現在的那一件；2. 看不出時段的時間點；3. 都對不上就提第一件，不提時間點。
({Plan plan, bool withCue}) pickPeek(DateTime now, List<Plan> plans) {
  final m = now.hour * 60 + now.minute;
  for (final p in plans) {
    final w = cueWindow(p.cue);
    if (w != null && m >= w.start && m < w.end) return (plan: p, withCue: true);
  }
  for (final p in plans) {
    if (cueWindow(p.cue) == null) return (plan: p, withCue: true);
  }
  return (plan: plans.first, withCue: false);
}
