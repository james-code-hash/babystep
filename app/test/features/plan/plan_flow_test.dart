import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/safety/safety_response.dart';
import 'package:little_steps/copy/plan.dart';
import 'package:little_steps/core/clock.dart';
import 'package:little_steps/core/config.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/home/home_screen.dart';
import 'package:little_steps/features/plan/plan_screen.dart';

import '../../helpers/test_app.dart';

const _tone = AgeTone.lively;

void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _finish(WidgetTester tester, TestEnv env) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
  await tester.runAsync(env.dispose);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(find.byKey(ValueKey(key))).onPressed != null;

/// 從首頁點進排計畫流程。
Future<void> _openPlan(WidgetTester tester, TestEnv env) async {
  _tallScreen(tester);
  await pumpApp(tester, env);
  await _tap(tester, 'home-plan');
  expect(find.byType(PlanFlowScreen), findsOneWidget);
}

String _day(TestEnv env) => dayKeyOf(env.clock.now());

Future<T> _q<T>(WidgetTester tester, Future<T> Function() f) async => (await tester.runAsync(f)) as T;

void main() {
  testWidgets('full flow via chips saves the child’s if-then plans and returns home', (tester) async {
    final env = TestEnv();
    await _openPlan(tester, env);

    // 1. 心情暖身 → 一句回應 → 下一步
    await _tap(tester, 'mood-happy');
    expect(find.text(PlanCopy.moodHappyReply.of(_tone)), findsOneWidget);
    await _tap(tester, 'plan-next');

    // 2. 選事情：一件時有中性的一句話；還沒選不能往下。
    expect(_enabled(tester, 'plan-next'), isFalse);
    await _tap(tester, 'task-preset-task-0'); // ✏️ 寫數學作業
    expect(find.text(PlanCopy.chooseOne.of(_tone)), findsOneWidget);
    await _tap(tester, 'task-preset-task-1'); // 📖 看一本書
    expect(find.text(PlanCopy.chooseOne.of(_tone)), findsNothing);
    await _tap(tester, 'plan-next');

    // 3. 第一件的「如果⋯」：沒有預選的時間點，選了才能往下。
    expect(find.byKey(const ValueKey('ifthen-sentence')), findsNothing);
    expect(_enabled(tester, 'plan-next'), isFalse);
    await _tap(tester, 'cue-preset-cue-0'); // 我吃完晚飯
    expect(find.text('如果我吃完晚飯，我就寫數學作業'), findsOneWidget);
    await _tap(tester, 'plan-next');

    // 4. 為什麼：選一個短答案。
    await _tap(tester, 'why-0'); // 我想試試看
    await _tap(tester, 'plan-next');

    // 第二件
    await _tap(tester, 'cue-preset-cue-2'); // 我洗完澡
    expect(find.text('如果我洗完澡，我就看一本書'), findsOneWidget);
    await _tap(tester, 'plan-next');
    await _tap(tester, 'why-skip');

    // 5. 確認：功勞還給孩子。
    expect(find.text(PlanCopy.confirmTitle.of(_tone)), findsOneWidget);
    expect(find.text('如果我吃完晚飯，我就寫數學作業'), findsOneWidget);
    expect(find.text('如果我洗完澡，我就看一本書'), findsOneWidget);
    await _tap(tester, 'plan-next');

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(PlanFlowScreen), findsNothing);
    final plans = await _q(tester, () => env.repo.plans(_day(env)));
    expect(plans.map((p) => p.ifThen), ['如果我吃完晚飯，我就寫數學作業', '如果我洗完澡，我就看一本書']);
    expect(plans.map((p) => p.emoji), ['✏️', '📖']);
    expect(plans[0].why, PlanCopy.whyTry.of(_tone));
    expect(plans[1].why, isNull);
    expect(plans.every((p) => p.outcome == null), isTrue);
    // 首頁顯示今天的計畫卡。
    expect(find.text('如果我吃完晚飯，我就寫數學作業'), findsOneWidget);
    await _finish(tester, env);
  });

  testWidgets('cannot choose more than maxPlansPerDay; a gentle line instead', (tester) async {
    final env = TestEnv();
    await _openPlan(tester, env);
    await _tap(tester, 'mood-unsaid');
    await _tap(tester, 'plan-next');
    for (var i = 0; i <= AppConfig.maxPlansPerDay; i++) {
      await _tap(tester, 'task-preset-task-$i');
    }
    final selected = tester.widgetList<FilterChip>(find.byType(FilterChip)).where((c) => c.selected);
    expect(selected.length, AppConfig.maxPlansPerDay);
    expect(find.text(PlanCopy.chooseFull.fill(_tone, {'max': '${AppConfig.maxPlansPerDay}'})), findsOneWidget);
    // 取消一件就能換。
    await _tap(tester, 'task-preset-task-0');
    await _tap(tester, 'task-preset-task-${AppConfig.maxPlansPerDay}');
    expect(tester.widgetList<FilterChip>(find.byType(FilterChip)).where((c) => c.selected).length,
        AppConfig.maxPlansPerDay);
    await _finish(tester, env);
  });

  testWidgets('a custom task goes into the child’s own library and is selected', (tester) async {
    final env = TestEnv();
    await _openPlan(tester, env);
    await _tap(tester, 'mood-okay');
    await _tap(tester, 'plan-next');
    await _tap(tester, 'task-write-own');
    await _tap(tester, 'emoji-🎨');
    await _enter(tester, 'task-custom-field', '畫一張圖');
    await _tap(tester, 'task-custom-add');

    final mine = await _q(tester, () => env.repo.taskTemplates(origins: {TemplateOrigin.child}));
    expect(mine.single.text, '畫一張圖');
    expect(mine.single.emoji, '🎨');
    expect(find.text(PlanCopy.sectionMine.of(_tone)), findsOneWidget);
    final chip = tester.widget<FilterChip>(find.byKey(ValueKey('task-${mine.single.id}')));
    expect(chip.selected, isTrue);

    // 自己寫的時間點：補成「我⋯」，存進孩子的時間點庫。
    await _tap(tester, 'plan-next');
    await _tap(tester, 'cue-write-own');
    await _enter(tester, 'cue-custom-field', '寫完功課');
    await _tap(tester, 'cue-custom-use');
    expect(find.text('如果我寫完功課，我就畫一張圖'), findsOneWidget);
    final cues = await _q(tester, () => env.repo.cueTemplates(origins: {TemplateOrigin.child}));
    expect(cues.single.text, '我寫完功課');

    // 換個說法（只改這次的計畫）。
    await _tap(tester, 'ifthen-edit-task');
    await _enter(tester, 'ifthen-task-field', '畫一張貓的圖');
    await _tap(tester, 'ifthen-task-done');
    expect(find.text('如果我寫完功課，我就畫一張貓的圖'), findsOneWidget);
    await _tap(tester, 'plan-next');

    // 自己寫的為什麼。
    await _tap(tester, 'why-write-own');
    await _enter(tester, 'why-custom-field', '我喜歡貓');
    await _tap(tester, 'why-custom-use');
    await _tap(tester, 'plan-next');
    await _tap(tester, 'plan-next');

    final plans = await _q(tester, () => env.repo.plans(_day(env)));
    expect(plans.single.ifThen, '如果我寫完功課，我就畫一張貓的圖');
    expect(plans.single.emoji, '🎨');
    expect(plans.single.why, '我喜歡貓');
    await _finish(tester, env);
  });

  testWidgets('crisis text in a custom task is never saved', (tester) async {
    final env = TestEnv();
    await _openPlan(tester, env);
    await _tap(tester, 'mood-unsaid');
    await _tap(tester, 'plan-next');
    await _tap(tester, 'task-write-own');
    await _enter(tester, 'task-custom-field', '我想死');
    await tester.tap(find.byKey(const ValueKey('task-custom-add')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final all = await _q(tester, () => env.repo.taskTemplates());
    expect(all.where((t) => t.text.contains('想死')), isEmpty);
    expect(all.where((t) => t.origin == TemplateOrigin.child), isEmpty);
    await _finish(tester, env);
  });

  testWidgets('crisis text as a custom cue or why is never used', (tester) async {
    final env = TestEnv();
    await _openPlan(tester, env);
    await _tap(tester, 'mood-unsaid');
    await _tap(tester, 'plan-next');
    await _tap(tester, 'task-preset-task-0');
    await _tap(tester, 'plan-next');
    await _tap(tester, 'cue-write-own');
    await _enter(tester, 'cue-custom-field', '我不想活了');
    await tester.tap(find.byKey(const ValueKey('cue-custom-use')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // 真的安全閘門會先蓋上預寫的安全回應，孩子關掉之後才回到計畫。
    expect(find.byType(SafetyResponseScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-close')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final cues = await _q(tester, () => env.repo.cueTemplates());
    expect(cues.where((c) => c.origin == TemplateOrigin.child), isEmpty);
    expect(find.textContaining('不想活'), findsNothing);
    await _finish(tester, env);
  });

  testWidgets('mood is never persisted or exported', (tester) async {
    final env = TestEnv();
    await _openPlan(tester, env);
    await _tap(tester, 'mood-low');
    // 心情低：兩個同樣份量的選項。
    expect(find.text(PlanCopy.moodLowReply.of(_tone)), findsOneWidget);
    expect(find.byKey(const ValueKey('mood-rest')), findsOneWidget);
    expect(tester.widget(find.byKey(const ValueKey('mood-rest'))).runtimeType,
        tester.widget(find.byKey(const ValueKey('mood-plan-anyway'))).runtimeType);
    await _tap(tester, 'mood-plan-anyway');
    await _tap(tester, 'task-preset-task-0');
    await _tap(tester, 'plan-next');
    await _tap(tester, 'cue-preset-cue-0');
    await _tap(tester, 'plan-next');
    await _tap(tester, 'why-4'); // 不知道
    expect(find.text(PlanCopy.whyDontKnowReply.of(_tone)), findsOneWidget);
    await _tap(tester, 'plan-next');
    await _tap(tester, 'plan-next');

    final json = await _q(tester, env.repo.exportJson);
    expect(json.toLowerCase().contains('mood'), isFalse);
    expect(json.contains(PlanCopy.moodLow.of(_tone)), isFalse);
    expect(json.contains('🌧'), isFalse);
    expect((await _q(tester, () => env.repo.plans(_day(env)))).single.why, PlanCopy.whyDontKnow.of(_tone));
    await _finish(tester, env);
  });

  testWidgets('low mood → 「今天先不排」 just goes home, nothing saved', (tester) async {
    final env = TestEnv();
    await _openPlan(tester, env);
    final before = await _q(tester, env.repo.exportJson);
    await _tap(tester, 'mood-tired');
    await _tap(tester, 'mood-rest');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(PlanFlowScreen), findsNothing);
    expect(await _q(tester, env.repo.exportJson), before);
    await _finish(tester, env);
  });

  testWidgets('back button walks back through the steps', (tester) async {
    final env = TestEnv();
    await _openPlan(tester, env);
    await _tap(tester, 'mood-happy');
    await _tap(tester, 'plan-next');
    await _tap(tester, 'task-preset-task-0');
    await _tap(tester, 'plan-next');
    expect(find.byKey(const ValueKey('cue-preset-cue-0')), findsOneWidget);
    await _tap(tester, 'plan-back');
    // 選擇還在。
    expect(tester.widget<FilterChip>(find.byKey(const ValueKey('task-preset-task-0'))).selected, isTrue);
    await _tap(tester, 'plan-back');
    expect(find.byKey(const ValueKey('mood-happy')), findsOneWidget);
    await _tap(tester, 'plan-back');
    expect(find.byType(HomeScreen), findsOneWidget);
    await _finish(tester, env);
  });

  testWidgets('re-planning starts fresh and replaces today’s plans on confirm', (tester) async {
    final env = TestEnv();
    await env.seed();
    await env.repo.savePlans(_day(env), const [PlanDraft(emoji: '📖', task: '看一本書', cue: '我洗完澡')]);
    _tallScreen(tester);
    await pumpApp(tester, env);
    await _tap(tester, 'home-replan');
    expect(find.byKey(const ValueKey('mood-happy')), findsOneWidget);
    await _tap(tester, 'mood-unsaid');
    await _tap(tester, 'plan-next');
    await _tap(tester, 'task-preset-task-0');
    await _tap(tester, 'plan-next');
    await _tap(tester, 'cue-preset-cue-1');
    await _tap(tester, 'plan-next');
    await _tap(tester, 'why-skip');
    await _tap(tester, 'plan-next');
    final plans = await _q(tester, () => env.repo.plans(_day(env)));
    expect(plans.single.ifThen, '如果我放學回到家，我就寫數學作業');
    await _finish(tester, env);
  });

  testWidgets('day already ended → calm message and a way back, no plan flow', (tester) async {
    final env = TestEnv();
    await env.seed();
    await env.repo.endDay(_day(env));
    await pumpScreen(tester, env, const PlanFlowScreen());
    expect(find.byKey(const ValueKey('plan-ended')), findsOneWidget);
    expect(find.text(PlanCopy.dayEnded.of(_tone)), findsOneWidget);
    expect(find.byKey(const ValueKey('mood-happy')), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    await _finish(tester, env);
  });
}
