// 情境：完整分齡（I3）。兩種說話方式在流程上就不一樣，不只是語氣。
//   活潑（小樹苗，6–8）：字大一點、選項帶圖示、兩件時軟性提示、回顧先給短答案。
//   簡潔（小探險家，9–12）：多一步可跳過的「卡住的話，我就⋯」、回顧一開始就能寫字。
// 孩子在自己的設定裡切換；家長區永遠用系統字級。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/plan.dart';
import 'package:little_steps/core/config.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/home/home_screen.dart';

import '../e2e/harness.dart';

double _scaleOn(WidgetTester tester, Finder f) => MediaQuery.of(tester.element(f)).textScaler.scale(10) / 10;

void ageScenarios() {
  testWidgets('sprout (6–8, default): bigger text, pictures on cues, a soft note at two, no "stuck" step, '
      'short answers first', (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 19, 30));
    expect(_scaleOn(tester, find.byType(HomeScreen)), closeTo(AgeConfig.sproutTextScale, 0.001));

    await app.tap('home-plan');
    await app.tap('mood-happy');
    await app.tap('plan-next');
    await app.tap('task-preset-task-0');
    await app.tap('task-preset-task-1');
    expect(find.text(PlanCopy.chooseEnough.lively), findsOneWidget);
    await app.tap('task-preset-task-1'); // 拿掉第二件，只排一件
    await app.tap('plan-next');
    final label = (tester.widget<ChoiceChip>(find.byKey(const ValueKey('cue-preset-cue-0'))).label as Text).data!;
    expect(label.startsWith(PlanCopy.cueIcon(label.split(' ').last)!), isTrue, reason: label);
    await app.tap('cue-preset-cue-0');
    await app.tap('plan-next');
    await app.tap('why-skip');
    expect(app.has('plan-stuck-0'), isFalse);
    expect(app.has('confirm-0'), isTrue);
    await app.tap('plan-next');

    await app.tap('home-review');
    await app.tap('review-start');
    await app.tap('outcome-done');
    await app.tap('review-next');
    expect(app.has('review-text'), isFalse, reason: 'short answers first');
    expect(app.has('review-chip-0'), isTrue);

    // 家長區用系統字級。
    await app.back();
    await app.tap('nav-parent');
    expect(_scaleOn(tester, find.byKey(const ValueKey('pin-title'))), closeTo(1, 0.001));
    await app.close();
  });

  testWidgets('explorer (9–12, switched by the child): plain cue chips, a skippable "if I get stuck" step that is '
      'saved and shown, writing box open in the review', (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 19, 30));
    await app.tap('nav-settings');
    expect(find.textContaining('歲'), findsNothing, reason: 'no ages on the switch');
    await app.tap('tone-concise');
    expect((await app.read((r) => r.settings())).tone, AgeTone.concise);
    await app.back();
    expect(_scaleOn(tester, find.byType(HomeScreen)), closeTo(1, 0.001));

    await app.tap('home-plan');
    await app.tap('mood-okay');
    await app.tap('plan-next');
    await app.tap('task-preset-task-0');
    await app.tap('task-preset-task-1');
    await app.tap('plan-next');
    final label = (tester.widget<ChoiceChip>(find.byKey(const ValueKey('cue-preset-cue-0'))).label as Text).data!;
    expect(label.startsWith(PlanCopy.cueIcon(label.split(' ').last)!), isFalse, reason: label);

    // 第一件：選一個「卡住的話」；第二件：跳過。
    await app.tap('cue-preset-cue-0');
    await app.tap('plan-next');
    await app.tap('why-skip');
    expect(app.has('plan-stuck-0'), isTrue);
    await app.tap('stuck-0');
    await app.tap('plan-next');
    await app.tap('cue-preset-cue-1');
    await app.tap('plan-next');
    await app.tap('why-skip');
    expect(app.has('plan-stuck-1'), isTrue);
    await app.tap('stuck-skip');
    expect(app.has('confirm-stuck-0'), isTrue);
    expect(app.has('confirm-stuck-1'), isFalse);
    await app.tap('plan-next');

    final plans = await app.read((r) => r.plans(app.today));
    expect(plans.map((p) => p.stuck), [PlanCopy.stuckOneMinute.concise, null]);
    expect(find.text(PlanCopy.stuckLine.fill(AgeTone.concise, {'stuck': PlanCopy.stuckOneMinute.concise})),
        findsOneWidget);

    await app.tap('home-review');
    await app.tap('review-start');
    for (final o in [Outcome.partly, Outcome.notToday]) {
      await app.tap('outcome-${o.name}');
      await app.tap('review-next');
    }
    expect(app.has('review-text'), isTrue, reason: 'explorer can write right away');
    await app.enter('review-text', '一分鐘版本真的比較容易開始');
    await app.tap('review-send');
    await app.tap('review-save-yes');
    await app.tap('review-end-ok');
    expect(app.has('home-ended'), isTrue);
    expect((await app.read((r) => r.dayRecord(app.today)))!.reflection, '一分鐘版本真的比較容易開始');
    await app.close();
  });
}
