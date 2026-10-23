import 'package:flutter_riverpod/flutter_riverpod.dart';

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
