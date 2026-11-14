// 底線 4：「今天沒做」和「做到了」視覺權重相同、路徑一樣完整、零後果。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/core/theme.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/review/outcome_buttons.dart';

import '../features/review/review_test_utils.dart';
import '../helpers/test_app.dart';

Future<void> pumpButtons(WidgetTester tester, {Outcome? selected, double width = 400}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: OutcomeButtons(selected: selected, onChanged: (_) {}),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder button(Outcome o) => find.byKey(OutcomeButtons.keyFor(o));

Material materialOf(WidgetTester tester, Outcome o) =>
    tester.widget<Material>(find.descendant(of: button(o), matching: find.byType(Material)).first);

Text labelOf(WidgetTester tester, Outcome o) =>
    tester.widget<Text>(find.descendant(of: button(o), matching: find.byType(Text)).last);

void main() {
  group('OutcomeButtons visual parity', () {
    for (final width in [320.0, 400.0, 720.0]) {
      testWidgets('identical size, color and type at width $width', (tester) async {
        await pumpButtons(tester, width: width);
        final sizes = {for (final o in Outcome.values) tester.getSize(button(o))};
        expect(sizes, hasLength(1), reason: 'all three buttons render at the same size');
        expect(sizes.single.height, greaterThanOrEqualTo(48));

        final colors = {for (final o in Outcome.values) materialOf(tester, o).color};
        expect(colors, {AppColors.outcomeButton});

        final weights = {for (final o in Outcome.values) labelOf(tester, o).style?.fontWeight};
        final fontSizes = {for (final o in Outcome.values) labelOf(tester, o).style?.fontSize};
        final textColors = {for (final o in Outcome.values) labelOf(tester, o).style?.color};
        expect(weights, hasLength(1));
        expect(fontSizes, hasLength(1));
        expect(textColors, hasLength(1));
      });
    }

    testWidgets('fixed order done → partly → notToday, no default selection', (tester) async {
      await pumpButtons(tester);
      final xs = [for (final o in OutcomeButtons.order) tester.getTopLeft(button(o)).dx];
      expect(xs, orderedEquals([...xs]..sort()));
      expect(OutcomeButtons.order, [Outcome.done, Outcome.partly, Outcome.notToday]);
      for (final o in Outcome.values) {
        expect(tester.getSemantics(button(o)).flagsCollection.isSelected, isNot(true));
      }
    });

    testWidgets('no red or green anywhere; selecting any one looks the same', (tester) async {
      final shapes = <String>{};
      for (final sel in Outcome.values) {
        await pumpButtons(tester, selected: sel);
        final m = materialOf(tester, sel);
        expect(m.color, AppColors.outcomeButton, reason: 'selection does not change the fill');
        shapes.add((m.shape as RoundedRectangleBorder).side.toString());
        expect({for (final o in Outcome.values) tester.getSize(button(o))}, hasLength(1));
        for (final o in Outcome.values) {
          final c = materialOf(tester, o).color!;
          final r = (c.r * 255).round(), g = (c.g * 255).round(), b = (c.b * 255).round();
          final reddish = r > 180 && g < 120 && b < 120;
          final greenish = g > 160 && r < 120 && b < 140;
          expect(reddish || greenish, isFalse);
        }
      }
      expect(shapes, hasLength(1), reason: 'the selected border is identical whichever is chosen');
    });
  });

  group('flow parity', () {
    late TestEnv env;
    setUp(() => env = TestEnv());
    tearDown(() => env.dispose());

    Future<List<String>> run(WidgetTester tester, Outcome o) async {
      final service = CountingLessonService();
      final steps = await runFullReview(tester, env, service, o);
      expect(service.calls, hasLength(1), reason: 'Bubu learns something on a $o day too');
      expect((await db(tester, () => env.repo.dayRecord(todayOf(env))))?.ended, isTrue);
      expect(await db(tester, () => env.repo.watchLessons().first), hasLength(1), reason: 'the $o lesson can be saved');
      return steps;
    }

    final expected = [
      'review-start',
      'review-question',
      'review-lesson',
      'review-save-yes',
      'review-save-no',
      'review-ending',
      'review-end-ok',
    ];

    dbTestWidgets('done reaches question, lesson, save option, ending', (tester) async {
      expect(await run(tester, Outcome.done), expected);
    });

    dbTestWidgets('partly reaches the same steps', (tester) async {
      expect(await run(tester, Outcome.partly), expected);
    });

    dbTestWidgets('notToday reaches exactly the same steps as done', (tester) async {
      expect(await run(tester, Outcome.notToday), expected);
    });
  });
}
