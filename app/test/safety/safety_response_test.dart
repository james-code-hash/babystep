import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/bubu/bubu_view.dart';
import 'package:little_steps/copy/safety.dart';
import 'package:little_steps/core/copy_rules.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/safety/crisis_detector.dart';
import 'package:little_steps/safety/safety_gate.dart';
import 'package:little_steps/safety/safety_response.dart';

import '../helpers/test_app.dart';

/// 按下按鈕就對 [text] 跑一次 passesSafetyCheck，結果放進 [results]。
class _GateHarness extends ConsumerWidget {
  const _GateHarness(this.text, this.results);
  final String text;
  final List<bool> results;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: Center(
          child: TextButton(
            key: const Key('submit'),
            onPressed: () async => results.add(await passesSafetyCheck(context, ref, text)),
            child: const Text('submit'),
          ),
        ),
      );
}

/// drift 的 stream 取消時會排一個 0 秒 timer；先把樹拆掉再讓它跑完，免得測試結束時還有 timer。
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(Duration.zero);
}

void main() {
  late CopyRules rules;
  setUpAll(() => rules = loadCopyRules());

  group('safety copy', () {
    final lines = <String, dynamic>{
      for (final c in [...CrisisCategory.values, null]) ...{
        'opening($c)': SafetyCopy.opening(c),
        'bridge($c)': SafetyCopy.bridge(c),
      },
      'trustedAdult': SafetyCopy.trustedAdult,
      'helplinesTitle': SafetyCopy.helplinesTitle,
      'howToCall': SafetyCopy.howToCall,
      'notSaved': SafetyCopy.notSaved,
      'close': SafetyCopy.close,
      'lessonSafety': SafetyCopy.lessonSafety,
      'callLabel': SafetyCopy.callLabel,
    };

    test('passes copy rules (L1, L2, concise) and ≤ max chars, both tones', () {
      lines.forEach((name, line) {
        for (final tone in AgeTone.values) {
          final s = line.of(tone) as String;
          expect(rules.check(s, tone: tone, checkLength: true), isEmpty, reason: '$name: $s');
        }
      });
    });

    test('encourages a trusted adult (家人、老師、輔導老師)', () {
      for (final tone in AgeTone.values) {
        final s = SafetyCopy.trustedAdult.of(tone);
        expect(s, allOf(contains('家人'), contains('老師'), contains('輔導老師')));
      }
    });

    test('helpline texts from crisis_patterns.json pass L1 rules', () {
      for (final h in loadCrisisDetector().helplines) {
        expect(rules.check('${h.name}${h.note}'), isEmpty, reason: h.note);
      }
    });
  });

  group('SafetyResponseScreen', () {
    for (final tone in AgeTone.values) {
      for (final cat in [...CrisisCategory.values, null]) {
        testWidgets('renders $cat / $tone with caring Bubu, helplines and one close', (tester) async {
          final env = TestEnv();
          addTearDown(env.dispose);
          await env.seed();
          await env.repo.setTone(tone);
          await pumpScreen(tester, env, SafetyResponseScreen(category: cat));

          expect(find.text(SafetyCopy.opening(cat).of(tone)), findsOneWidget);
          expect(find.text(SafetyCopy.trustedAdult.of(tone)), findsOneWidget);
          final bubu = tester.widget<BubuView>(find.byType(BubuView));
          expect(bubu.expression, BubuExpression.caring);
          for (final h in loadCrisisDetector().helplines) {
            expect(find.byKey(Key('helpline-${h.id}')), findsOneWidget);
            expect(find.text(h.name), findsOneWidget);
          }
          expect(find.byType(FilledButton), findsOneWidget);
          expect(find.text(SafetyCopy.close.of(tone)), findsOneWidget);
          await _unmount(tester);
        });
      }
    }
  });

  group('passesSafetyCheck', () {
    testWidgets('crisis text → shows SafetyResponseScreen, awaits close, returns false', (tester) async {
      final env = TestEnv();
      addTearDown(env.dispose);
      final results = <bool>[];
      await pumpScreen(tester, env, _GateHarness('我 好 想 死', results));

      await tester.tap(find.byKey(const Key('submit')));
      await tester.pumpAndSettle();
      expect(find.byType(SafetyResponseScreen), findsOneWidget);
      expect(results, isEmpty, reason: 'still waiting for the child to close');
      // 孩子寫的字不會出現在安全回應上。
      expect(find.textContaining('想死'), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('safety-close')));
      await tester.tap(find.byKey(const Key('safety-close')));
      await tester.pumpAndSettle();
      expect(find.byType(SafetyResponseScreen), findsNothing);
      expect(results, [false]);
      await _unmount(tester);
    });

    testWidgets('safe text → true, no screen', (tester) async {
      final env = TestEnv();
      addTearDown(env.dispose);
      final results = <bool>[];
      await pumpScreen(tester, env, _GateHarness('先寫最討厭的', results));

      await tester.tap(find.byKey(const Key('submit')));
      await tester.pumpAndSettle();
      expect(find.byType(SafetyResponseScreen), findsNothing);
      expect(results, [true]);
      await _unmount(tester);
    });

    testWidgets('nothing is stored when the gate trips', (tester) async {
      final env = TestEnv();
      addTearDown(env.dispose);
      final results = <bool>[];
      await pumpScreen(tester, env, _GateHarness('他打我', results));
      final before = await tester.runAsync(env.repo.exportJson);

      await tester.tap(find.byKey(const Key('submit')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('safety-close')));
      await tester.tap(find.byKey(const Key('safety-close')));
      await tester.pumpAndSettle();

      expect(results, [false]);
      expect(await tester.runAsync(env.repo.exportJson), before);
      await _unmount(tester);
    });
  });
}
