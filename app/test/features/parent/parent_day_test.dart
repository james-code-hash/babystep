// 家長區開著跨過午夜：「今天的我」換成新的一天，不留著昨天的。
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/core/clock.dart';
import 'package:little_steps/features/parent/parent_providers.dart';

import '../../helpers/test_app.dart';

void main() {
  test('the parent area\'s "today" follows the day', () async {
    final env = TestEnv(now: DateTime(2026, 10, 23, 23, 50));
    await env.seed();
    await env.repo.saveFamilyToday('2026-10-23', who: '媽媽', text: '散步二十分鐘');
    final c = env.container();
    final sub = c.listen(parentViewProvider, (_, _) {});
    expect((await c.read(parentViewProvider.future)).familyToday.single.text, '散步二十分鐘');

    // 過了午夜：todayKeyProvider 自己換日（App 開著）或首頁從背景回來時 invalidate。
    env.clock.fixed = DateTime(2026, 10, 24, 0, 5);
    c.invalidate(todayKeyProvider);
    expect((await c.read(parentViewProvider.future)).familyToday, isEmpty);

    sub.close();
    c.dispose();
    await env.dispose();
  });
}
