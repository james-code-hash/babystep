import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/bubu/bubu_inputs.dart';
import 'package:little_steps/bubu/bubu_painter.dart';
import 'package:little_steps/bubu/bubu_view.dart';
import 'package:little_steps/bubu/catalog.dart';
import 'package:little_steps/bubu/look.dart';
import 'package:little_steps/core/clock.dart';
import 'package:little_steps/domain/models.dart';

import '../helpers/test_app.dart';

Finder _painterOf<T extends CustomPainter>() =>
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is T);

void main() {
  test('painter paints every expression × hat × neck × color × time without throwing', () {
    final times = [
      DateTime(2026, 4, 1, 8), // 春天早上
      DateTime(2026, 7, 1, 13), // 夏天白天
      DateTime(2026, 10, 23, 18), // 秋天傍晚
      DateTime(2026, 1, 10, 23), // 冬天晚上
    ];
    var count = 0;
    for (final e in BubuExpression.values) {
      for (final hat in BubuCatalog.hats) {
        for (final neck in BubuCatalog.necks) {
          for (final color in BubuCatalog.colors) {
            for (final t in times) {
              final painter = BubuPainter(
                look: look(DressUp(hat: hat.id, neck: neck.id, color: color.id), t),
                expression: e,
              );
              final rec = ui.PictureRecorder();
              painter.paint(Canvas(rec), const Size(160, 160));
              rec.endRecording().dispose();
              count++;
            }
          }
        }
      }
    }
    expect(count, greaterThan(0));
  });

  test('shouldRepaint only when look or expression changes', () {
    final now = DateTime(2026, 10, 23, 12);
    BubuPainter p(DressUp d, BubuExpression e, [DateTime? t]) => BubuPainter(look: look(d, t ?? now), expression: e);
    final a = p(DressUp.initial, BubuExpression.calm);
    expect(a.shouldRepaint(p(DressUp.initial, BubuExpression.calm)), isFalse);
    expect(a.shouldRepaint(p(DressUp.initial, BubuExpression.happy)), isTrue);
    expect(a.shouldRepaint(p(const DressUp(hat: 'leaf'), BubuExpression.calm)), isTrue);
    expect(a.shouldRepaint(p(DressUp.initial, BubuExpression.calm, DateTime(2026, 10, 23, 22))), isTrue);
    const d = ThinkingDotsPainter(phase: 0.1);
    expect(d.shouldRepaint(const ThinkingDotsPainter(phase: 0.1)), isFalse);
    expect(d.shouldRepaint(const ThinkingDotsPainter(phase: 0.4)), isTrue);
  });

  group('BubuView', () {
    final clock = FixedClock(DateTime(2026, 10, 23, 19, 30));

    // 大部分測試不碰資料庫：直接給裝扮與語氣，只換時鐘。
    Widget scoped(Widget child, {DressUp dressUp = DressUp.initial, AgeTone tone = AgeTone.lively}) =>
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            clockProvider.overrideWithValue(clock),
            toneProvider.overrideWithValue(tone),
            bubuDressUpProvider.overrideWithValue(dressUp),
          ],
          child: MaterialApp(home: child),
        );

    setUp(() => clock.fixed = DateTime(2026, 10, 23, 19, 30));

    testWidgets('DressUp.initial renders from the real provider and settles (static by default)', (tester) async {
      final env = TestEnv();
      await pumpScreen(tester, env, const Scaffold(body: Center(child: BubuView())));
      expect(find.byType(BubuView), findsOneWidget);
      expect(find.bySemanticsLabel('步步安安靜靜地陪著你'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final l = (tester.widget<CustomPaint>(_painterOf<BubuPainter>()).painter as BubuPainter).look;
      expect(l, look(DressUp.initial, env.clock.now()));
      // 預設沒有無限動畫：pumpAndSettle 已經結束，也沒有排著的 frame。
      expect(tester.binding.hasScheduledFrame, isFalse);
      // 拆掉 widget tree，讓 drift 的 stream 收乾淨再關資料庫。
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 10));
      await env.dispose();
    });

    testWidgets('every expression × accessory renders inside the widget tree', (tester) async {
      Future<void> show(DressUp d, BubuExpression e) async {
        await tester.pumpWidget(scoped(Scaffold(body: Center(child: BubuView(expression: e, size: 120))), dressUp: d));
        expect(tester.takeException(), isNull, reason: '${d.toJson()} $e');
        final l = (tester.widget<CustomPaint>(_painterOf<BubuPainter>()).painter as BubuPainter).look;
        expect(l, look(d, clock.now()));
      }

      for (final e in BubuExpression.values) {
        for (final hat in BubuCatalog.hats) {
          await show(DressUp(hat: hat.id), e);
        }
        for (final neck in BubuCatalog.necks) {
          await show(DressUp(neck: neck.id), e);
        }
        for (final color in BubuCatalog.colors) {
          await show(DressUp(color: color.id), e);
        }
      }
    });

    testWidgets('semantics label follows expression and tone', (tester) async {
      await tester.pumpWidget(scoped(const BubuView(expression: BubuExpression.relaxed), tone: AgeTone.concise));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('步步很放鬆'), findsOneWidget);
      await tester.pumpWidget(scoped(const BubuView(expression: BubuExpression.happy)));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('步步笑咪咪的'), findsOneWidget);
    });

    testWidgets('thinking shows animated dots; use pump(duration), not pumpAndSettle', (tester) async {
      await tester.pumpWidget(scoped(const BubuView(thinking: true)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.bySemanticsLabel('步步在想事情'), findsOneWidget);
      final dots = _painterOf<ThinkingDotsPainter>();
      expect(dots, findsOneWidget);
      final p1 = (tester.widget<CustomPaint>(dots).painter as ThinkingDotsPainter).phase;
      await tester.pump(const Duration(milliseconds: 300));
      final p2 = (tester.widget<CustomPaint>(dots).painter as ThinkingDotsPainter).phase;
      expect(p1, isNotNull);
      expect(p2, isNot(p1));
      expect(tester.binding.hasScheduledFrame, isTrue);

      // 想完了 → 動畫拿掉，又可以 settle。
      await tester.pumpWidget(scoped(const BubuView()));
      await tester.pumpAndSettle();
      expect(dots, findsNothing);
    });

    testWidgets('reduce-motion keeps thinking dots and breathing static', (tester) async {
      await tester.pumpWidget(scoped(const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: BubuView(thinking: true, breathe: true),
      )));
      await tester.pumpAndSettle();
      final dots = _painterOf<ThinkingDotsPainter>();
      expect((tester.widget<CustomPaint>(dots).painter as ThinkingDotsPainter).phase, isNull);
    });

    testWidgets('breathe opts into a gentle repeating animation', (tester) async {
      await tester.pumpWidget(scoped(const BubuView(breathe: true)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.binding.hasScheduledFrame, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('look follows the clock: night uses the softer palette', (tester) async {
      clock.fixed = DateTime(2026, 10, 23, 22);
      await tester.pumpWidget(scoped(const BubuView()));
      await tester.pumpAndSettle();
      final l = (tester.widget<CustomPaint>(_painterOf<BubuPainter>()).painter as BubuPainter).look;
      expect(l.dayPart, DayPart.night);
      expect(l, look(DressUp.initial, clock.now()));
    });
  });
}
