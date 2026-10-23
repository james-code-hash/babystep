import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:little_steps/bubu/bubu_view.dart';
import 'package:little_steps/bubu/greeting.dart';
import 'package:little_steps/bubu/look.dart';
import 'package:little_steps/copy/home.dart';
import 'package:little_steps/core/clock.dart';
import 'package:little_steps/core/config.dart';
import 'package:little_steps/core/routes.dart';
import 'package:little_steps/core/theme.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/home/home_screen.dart';
import 'package:little_steps/features/home/peek_counter.dart';

import '../../helpers/test_app.dart';

const _tone = AgeTone.lively;

Future<void> _plan(TestEnv env) async {
  await env.seed();
  await env.repo.savePlans(dayKeyOf(env.clock.now()), const [
    PlanDraft(emoji: '✏️', task: '寫數學作業', cue: '我吃完晚飯'),
    PlanDraft(emoji: '📖', task: '看一本書', cue: '我洗完澡'),
  ]);
}

/// 夠高的畫面，避免 ListView 把下面的東西延後建立。
void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// 拆掉畫面（讓 drift 的 stream 收尾 timer 跑完），再關資料庫。
Future<void> finish(WidgetTester tester, TestEnv env) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
  await tester.runAsync(env.dispose);
}

/// 同一個 ProviderScope 裡可以把首頁拆下再掛上（模擬孩子再次打開首頁）。
Future<ValueNotifier<int>> _pumpRemountableHome(WidgetTester tester, TestEnv env) async {
  await env.seed();
  final mount = ValueNotifier<int>(0);
  await tester.pumpWidget(ProviderScope(
    overrides: env.overrides,
    child: MaterialApp(
      theme: buildTheme(),
      home: ValueListenableBuilder<int>(
        valueListenable: mount,
        builder: (context, k, _) => HomeScreen(key: ValueKey('home-$k')),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return mount;
}

void main() {
  late TestEnv env;

  group('three day states', () {
    testWidgets('no plans → one invitation to plan, which opens the plan flow', (tester) async {
      tallScreen(tester);
      env = TestEnv();
      await pumpApp(tester, env);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.widgetWithText(FilledButton, HomeCopy.planInvite.of(_tone)), findsOneWidget);
      expect(find.byKey(const ValueKey('home-peek')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('home-plan')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mood-happy')), findsOneWidget);
      await finish(tester, env);
    });

    testWidgets('planned → if-then cards and one review button, no counts or progress', (tester) async {
      tallScreen(tester);
      env = TestEnv();
      await _plan(env);
      await pumpApp(tester, env);
      expect(find.text('如果我吃完晚飯，我就寫數學作業'), findsOneWidget);
      expect(find.text('如果我洗完澡，我就看一本書'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.widgetWithText(FilledButton, HomeCopy.reviewInvite.of(_tone)), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Badge), findsNothing);
      expect(find.textContaining(RegExp(r'\d+\s*/\s*\d+')), findsNothing);

      final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
      await tester.tap(find.byKey(const ValueKey('home-review')));
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.last.matchedLocation, Routes.review);
      await finish(tester, env);
    });

    testWidgets('ended → 「今天聊完了」 and no call to action at all', (tester) async {
      tallScreen(tester);
      env = TestEnv();
      await _plan(env);
      await env.repo.endDay(dayKeyOf(env.clock.now()));
      await pumpApp(tester, env);
      expect(find.text(HomeCopy.dayEnded.of(_tone)), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byKey(const ValueKey('home-replan')), findsNothing);
      expect(find.byKey(const ValueKey('home-peek')), findsNothing);
      await finish(tester, env);
    });

    testWidgets('quiet navigation reaches notebook, path, settings and parent; no badges', (tester) async {
      tallScreen(tester);
      env = TestEnv();
      await pumpApp(tester, env);
      final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
      for (final (key, target) in [
        ('nav-notebook', Routes.notebook),
        ('nav-path', Routes.path),
        ('nav-settings', Routes.settings),
        ('nav-parent', Routes.parent),
      ]) {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(router.routerDelegate.currentConfiguration.last.matchedLocation, target, reason: key);
        router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
      }
      expect(find.byType(Badge), findsNothing);
      await finish(tester, env);
    });
  });

  group('peek reminder card', () {
    testWidgets('shows inside a reminder slot when today has plans, referencing the child’s plan', (tester) async {
      tallScreen(tester);
      env = TestEnv(); // 19:30，在預設的「吃完晚飯」時段裡
      await _plan(env);
      await pumpApp(tester, env);
      expect(find.byKey(const ValueKey('home-peek')), findsOneWidget);
      expect(find.textContaining('吃完晚飯要寫數學作業'), findsOneWidget);
      expect(find.textContaining('我吃完晚飯要'), findsNothing);
      await finish(tester, env);
    });

    testWidgets('not shown outside reminder slots', (tester) async {
      tallScreen(tester);
      env = TestEnv(now: DateTime(2026, 10, 23, 10, 0));
      await _plan(env);
      await pumpApp(tester, env);
      expect(find.byKey(const ValueKey('home-peek')), findsNothing);
      await finish(tester, env);
    });

    testWidgets('not shown without plans', (tester) async {
      tallScreen(tester);
      env = TestEnv();
      await pumpApp(tester, env);
      expect(find.byKey(const ValueKey('home-peek')), findsNothing);
      await finish(tester, env);
    });

    testWidgets('at most maxPeeksPerDay per day, counted only in memory', (tester) async {
      tallScreen(tester);
      env = TestEnv();
      await _plan(env);
      final mount = await _pumpRemountableHome(tester, env);
      for (var i = 0; i < AppConfig.maxPeeksPerDay; i++) {
        expect(find.byKey(const ValueKey('home-peek')), findsOneWidget, reason: 'visit $i');
        mount.value++;
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey('home-peek')), findsNothing);

      // 換一天就重新計算。
      env.clock.fixed = DateTime(2026, 10, 24, 19, 30);
      final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
      expect(container.read(peekCounterProvider.notifier).canShow('2026-10-24'), isTrue);
      expect(container.read(peekCounterProvider.notifier).canShow('2026-10-23'), isFalse);
      await finish(tester, env);
    });

    for (final (key, reply) in [
      ('peek-go', HomeCopy.peekGoReply),
      ('peek-later', HomeCopy.peekLaterReply),
      ('peek-not-today', HomeCopy.peekNotTodayReply),
    ]) {
      testWidgets('$key just shows one Bubu line and writes nothing', (tester) async {
        tallScreen(tester);
        env = TestEnv();
        await _plan(env);
        await pumpApp(tester, env);
        final before = await tester.runAsync(env.repo.exportJson);
        // 三個選項同一種按鈕（份量相同）。
        expect(find.descendant(of: find.byKey(const ValueKey('home-peek')), matching: find.byType(OutlinedButton)),
            findsNWidgets(3));
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('home-peek')), findsNothing);
        expect(find.text(reply.of(_tone)), findsOneWidget);
        expect(await tester.runAsync(env.repo.exportJson), before);
        // 回顧入口照舊，什麼都沒被改。
        expect(find.byKey(const ValueKey('home-review')), findsOneWidget);
        final plans = await tester.runAsync(() => env.repo.plans(dayKeyOf(env.clock.now())));
        expect(plans!.every((p) => p.outcome == null), isTrue);
        await finish(tester, env);
      });
    }
  });

  test('shouldPeek is false once the day has ended', () {
    final slots = [const ReminderSlot(id: 's', label: 'x', startMinute: 0, endMinute: 24 * 60)];
    const plan = Plan(id: 'p', dayKey: 'd', order: 0, emoji: '✏️', task: 't', cue: 'c');
    final now = DateTime(2026, 10, 23, 12);
    bool peek({DayRecord? record, bool under = true, List<Plan> plans = const [plan]}) => shouldPeek(
          now: now,
          settings: AppSettings(reminderSlots: slots),
          plans: plans,
          record: record,
          underDailyLimit: under,
        );
    expect(peek(), isTrue);
    expect(peek(record: DayRecord(dayKey: 'd', endedAt: now)), isFalse);
    expect(peek(under: false), isFalse);
    expect(peek(plans: const []), isFalse);
  });

  // 底線 2：首頁步步的表情只看時段，和今天有沒有計畫、有沒有聊完無關。
  group('Bubu on Home does not depend on what the child did', () {
    (BubuExpression, String) bubuOnHome(WidgetTester tester) {
      final view = tester.widget<BubuView>(find.byType(BubuView));
      final sem = tester.widget<Semantics>(find.descendant(of: find.byType(BubuView), matching: find.byType(Semantics)).first);
      return (view.expression, sem.properties.label!);
    }

    for (final hour in [8, 13, 18, 21]) {
      testWidgets('same face and label with 0 plans, with plans and after the day ended ($hour:00)', (tester) async {
        tallScreen(tester);
        final now = DateTime(2026, 10, 23, hour, 40); // 都不在預設提醒時段裡：沒有探頭卡
        final seen = <String, (BubuExpression, String)>{};
        for (final state in ['none', 'planned', 'ended']) {
          env = TestEnv(now: now);
          if (state != 'none') await _plan(env);
          if (state == 'ended') await env.repo.endDay(dayKeyOf(now));
          await pumpApp(tester, env);
          expect(find.byKey(const ValueKey('home-peek')), findsNothing);
          seen[state] = bubuOnHome(tester);
          await finish(tester, env);
        }
        expect(seen.values.toSet(), hasLength(1), reason: '$seen');
        expect(seen['none']!.$1, restingExpression(now));
      });
    }

    test('restingExpression only looks at the time of day', () {
      expect(restingExpression(DateTime(2026, 1, 1, 7)), BubuExpression.happy);
      expect(restingExpression(DateTime(2026, 1, 1, 13)), BubuExpression.calm);
      expect(restingExpression(DateTime(2026, 1, 1, 18)), BubuExpression.calm);
      expect(restingExpression(DateTime(2026, 1, 1, 22)), BubuExpression.relaxed);
      expect(restingExpression(DateTime(2026, 1, 1, 2)), BubuExpression.relaxed);
    });

    testWidgets('curious only while the peek question is showing, resting face after answering', (tester) async {
      tallScreen(tester);
      env = TestEnv(); // 19:30，提醒時段裡
      await _plan(env);
      await pumpApp(tester, env);
      expect(find.byKey(const ValueKey('home-peek')), findsOneWidget);
      expect(bubuOnHome(tester).$1, BubuExpression.curious);
      await tester.tap(find.byKey(const ValueKey('peek-later')));
      await tester.pumpAndSettle();
      expect(bubuOnHome(tester).$1, restingExpression(env.clock.now()));
      await finish(tester, env);
    });
  });

  group('peek card is re-checked when its inputs change', () {
    void resumeApp(WidgetTester tester) {
      for (final s in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
    }

    PeekCounter counterOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(HomeScreen))).read(peekCounterProvider.notifier);

    testWidgets('mounted outside a slot → clock moves into a slot → app resumed → card appears', (tester) async {
      tallScreen(tester);
      env = TestEnv(now: DateTime(2026, 10, 23, 10, 0));
      await _plan(env);
      await pumpApp(tester, env);
      expect(find.byKey(const ValueKey('home-peek')), findsNothing);

      env.clock.fixed = DateTime(2026, 10, 23, 19, 30);
      resumeApp(tester);
      await settleAll(tester);
      expect(find.byKey(const ValueKey('home-peek')), findsOneWidget);
      expect(counterOf(tester).shownOn('2026-10-23'), 1);

      // 卡片還開著時再從背景回來：還是同一張，不多算。
      resumeApp(tester);
      await settleAll(tester);
      expect(find.byKey(const ValueKey('home-peek')), findsOneWidget);
      expect(counterOf(tester).shownOn('2026-10-23'), 1);
      await finish(tester, env);
    });

    testWidgets('opened in the morning, resumed at night → greeting follows the new day part', (tester) async {
      tallScreen(tester);
      env = TestEnv(now: DateTime(2026, 10, 23, 8, 0));
      await pumpApp(tester, env);
      env.clock.fixed = DateTime(2026, 10, 23, 21, 30);
      resumeApp(tester);
      await settleAll(tester);
      final now = env.clock.now();
      final allowed = {
        for (final l in [...dayPartGreetings(dayPartOf(now)).lines, ...seasonalGreetings(seasonOf(now)).lines])
          l.of(AgeTone.lively),
      };
      final shown = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>();
      expect(shown.where(allowed.contains), isNotEmpty);
      await finish(tester, env);
    });

    testWidgets('resume still respects maxPeeksPerDay', (tester) async {
      tallScreen(tester);
      env = TestEnv(now: DateTime(2026, 10, 23, 10, 0));
      await _plan(env);
      await pumpApp(tester, env);
      final counter = counterOf(tester);
      for (var i = 0; i < AppConfig.maxPeeksPerDay; i++) {
        counter.markShown('2026-10-23');
      }
      env.clock.fixed = DateTime(2026, 10, 23, 19, 30);
      resumeApp(tester);
      await settleAll(tester);
      expect(find.byKey(const ValueKey('home-peek')), findsNothing);
      expect(counter.shownOn('2026-10-23'), AppConfig.maxPeeksPerDay);
      await finish(tester, env);
    });

    testWidgets('each resume is one visit: answered card, next resume can show again until the cap', (tester) async {
      tallScreen(tester);
      env = TestEnv();
      await _plan(env);
      await pumpApp(tester, env);
      var shown = 0;
      for (var i = 0; i < AppConfig.maxPeeksPerDay + 1; i++) {
        if (find.byKey(const ValueKey('home-peek')).evaluate().isNotEmpty) {
          shown++;
          await tester.tap(find.byKey(const ValueKey('peek-later')));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('home-peek')), findsNothing, reason: 'one card per visit');
        }
        resumeApp(tester);
        await settleAll(tester);
      }
      expect(shown, AppConfig.maxPeeksPerDay);
      expect(find.byKey(const ValueKey('home-peek')), findsNothing);
      await finish(tester, env);
    });

    testWidgets('plans appear while Home is mounted inside a slot → card appears', (tester) async {
      tallScreen(tester);
      env = TestEnv(); // 19:30
      await pumpApp(tester, env);
      expect(find.byKey(const ValueKey('home-peek')), findsNothing);
      await tester.runAsync(() => env.repo.savePlans(dayKeyOf(env.clock.now()), const [
            PlanDraft(emoji: '✏️', task: '寫數學作業', cue: '我吃完晚飯'),
          ]));
      await settleAll(tester);
      expect(find.byKey(const ValueKey('home-peek')), findsOneWidget);
      await finish(tester, env);
    });

    testWidgets('returning to Home from another screen re-checks', (tester) async {
      tallScreen(tester);
      env = TestEnv(now: DateTime(2026, 10, 23, 10, 0));
      await _plan(env);
      await pumpApp(tester, env);
      expect(find.byKey(const ValueKey('home-peek')), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('nav-notebook')));
      await tester.tap(find.byKey(const ValueKey('nav-notebook')));
      await settleAll(tester);
      env.clock.fixed = DateTime(2026, 10, 23, 19, 30);
      GoRouter.of(tester.element(find.byType(HomeScreen, skipOffstage: false))).pop();
      await settleAll(tester);
      expect(find.byKey(const ValueKey('home-peek')), findsOneWidget);
      await finish(tester, env);
    });
  });
}
