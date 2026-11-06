import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/parent_guide.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/parent/parent_guide.dart';

import '../../helpers/test_app.dart';
import 'parent_screen_test.dart' show openParent, settle, tapKey, unmount;

void main() {
  group('weekly lesson rotation', () {
    test('same lesson all week (Mon–Sun), next one the following Monday, cycles through all', () {
      final monday = DateTime(2026, 11, 2);
      final i = lessonIndexFor(monday);
      for (var d = 0; d < 7; d++) {
        expect(lessonIndexFor(monday.add(Duration(days: d, hours: 23))), i, reason: 'day $d');
      }
      expect(lessonIndexFor(monday.add(const Duration(days: 7))), (i + 1) % ParentGuideCopy.lessons.length);
      final seen = {for (var w = 0; w < ParentGuideCopy.lessons.length; w++) lessonIndexFor(monday.add(Duration(days: 7 * w)))};
      expect(seen, hasLength(ParentGuideCopy.lessons.length));
    });
  });

  group('copy', () {
    final rules = loadCopyRules();
    test('every script and lesson passes the copy rules, including the "don\'t say" examples', () {
      final lines = [
        for (final s in ParentGuideCopy.scripts) ...s.lines,
        for (final l in ParentGuideCopy.lessons) ...l.lines,
      ];
      final bad = [
        for (final l in lines)
          if (rules.check(l.concise, tone: AgeTone.concise).isNotEmpty) '${l.concise} ${rules.check(l.concise)}',
      ];
      expect(bad, isEmpty);
    });

    test('scripts cover the three situations from the proposal (§9.4)', () {
      final ids = ParentGuideCopy.scripts.map((s) => s.id).toSet();
      expect(ids, containsAll(['not-done', 'give-up', 'suggest']));
    });

    test('the guide never reads child data (only the clock)', () {
      final src = File('lib/features/parent/parent_guide.dart').readAsStringSync();
      expect(src, isNot(contains('repositoryProvider')));
      expect(src, isNot(contains('parentViewProvider')));
      expect(src, isNot(contains('settingsProvider')));
    });
  });

  testWidgets('parent opens the talk helper, picks a situation, sees feeling + choice + reason', (tester) async {
    final env = TestEnv();
    await openParent(tester, env);
    await tapKey(tester, 'open-talk');
    expect(find.byType(ParentTalkScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('talk-card-not-done')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('talk-not-done')));
    await settle(tester);
    expect(find.byKey(const ValueKey('talk-card-not-done')), findsOneWidget);
    for (final part in ['avoid', 'feeling', 'choice', 'reason', 'why']) {
      expect(find.byKey(ValueKey('talk-part-$part')), findsOneWidget);
    }
    await unmount(tester);
    await tester.runAsync(env.dispose);
  });

  testWidgets('this week\'s lesson is first and marked; all lessons are readable', (tester) async {
    final env = TestEnv(); // 2026-10-23
    await openParent(tester, env);
    final current = lessonFor(env.clock.now());
    expect(find.textContaining(current.title.concise), findsOneWidget, reason: 'entry names this week\'s lesson');
    await tapKey(tester, 'open-lessons');
    expect(find.byKey(const ValueKey('lesson-this-week')), findsOneWidget);
    final first = tester.getTopLeft(find.byKey(ValueKey('lesson-${current.id}')));
    for (final l in ParentGuideCopy.lessons) {
      final f = find.byKey(ValueKey('lesson-${l.id}'));
      expect(f, findsOneWidget);
      expect(tester.getTopLeft(f).dy, greaterThanOrEqualTo(first.dy));
    }
    await unmount(tester);
    await tester.runAsync(env.dispose);
  });
}
