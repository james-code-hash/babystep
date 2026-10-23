import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/core/clock.dart';

/// 會自己往前走的測試時鐘：時間由測試設定，但會排過午夜的計時器。
class _TickingClock extends FixedClock {
  _TickingClock(super.fixed);
  @override
  bool get ticks => true;
}

void main() {
  testWidgets('app stays in the foreground across midnight → today key moves to the new day', (tester) async {
    final clock = _TickingClock(DateTime(2026, 10, 23, 23, 59, 50));
    final container = ProviderContainer(overrides: [clockProvider.overrideWithValue(clock)]);
    final keys = <String>[];
    container.listen<String>(todayKeyProvider, (_, next) => keys.add(next), fireImmediately: true);
    expect(keys, ['2026-10-23']);

    clock.fixed = DateTime(2026, 10, 24, 0, 0, 2);
    await tester.pump(const Duration(seconds: 11));
    container.read(todayKeyProvider);
    expect(keys.last, '2026-10-24');
    container.dispose(); // 取消下一個午夜的計時器
  });

  test('a fixed clock never schedules a midnight timer', () {
    expect(FixedClock(DateTime(2026)).ticks, isFalse);
    expect(const Clock().ticks, isTrue);
  });
}
