import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/core/clock.dart';
import 'package:little_steps/domain/lesson_service.dart';
import 'package:little_steps/domain/models.dart';

import 'helpers/test_app.dart';

void main() {
  late TestEnv env;
  setUp(() async {
    env = TestEnv();
    await env.seed();
  });
  tearDown(() => env.dispose());

  test('seed puts presets once', () async {
    await env.seed();
    final tasks = await env.repo.taskTemplates();
    expect(tasks, isNotEmpty);
    expect(tasks.map((t) => t.id).toSet().length, tasks.length);
    final cues = await env.repo.cueTemplates();
    expect(cues.every((c) => c.text.startsWith('我')), isTrue);
    expect((await env.repo.settings()).reminderSlots, isNotEmpty);
  });

  test('a full day round-trips through the repository', () async {
    final day = dayKeyOf(env.clock.now());
    final plans = await env.repo.savePlans(day, const [
      PlanDraft(emoji: '✏️', task: '寫數學作業', cue: '吃完晚飯'),
      PlanDraft(emoji: '📖', task: '看一本書', cue: '我洗完澡', why: '我想知道結局'),
    ]);
    expect(plans.first.ifThen, '如果我吃完晚飯，我就寫數學作業');
    await env.repo.setOutcome(plans[0].id, Outcome.done);
    await env.repo.setOutcome(plans[1].id, Outcome.notToday);
    await env.repo.saveReflection(day, '先寫最難的');
    final lesson = await env.repo.saveLesson(
      day,
      const LessonResult(text: '原來可以先寫最難的。', kind: LessonKind.method, source: LessonSource.template),
    );
    expect(lesson, isNotNull);
    await env.repo.saveLesson(
      day,
      const LessonResult(text: '第二則會取代第一則。', kind: LessonKind.method, source: LessonSource.template),
    );
    expect((await env.repo.watchLessons().first).length, 1);
    await env.repo.endDay(day);
    final record = await env.repo.dayRecord(day);
    expect(record!.ended, isTrue);
    expect(record.reflection, '先寫最難的');
    expect((await env.repo.plannedDays()).single.dayKey, day);
  });

  test('safety results are never saved', () async {
    final saved = await env.repo.saveLesson(
      '2026-10-23',
      const LessonResult(text: 'x', kind: LessonKind.plainDay, source: LessonSource.safety),
    );
    expect(saved, isNull);
  });

  test('parent view only has shared lessons; export and deleteAll work', () async {
    final l = await env.repo.saveLesson(
      '2026-10-23',
      const LessonResult(text: '還沒分享', kind: LessonKind.feeling, source: LessonSource.template),
    );
    expect((await env.repo.parentView()).sharedLessons, isEmpty);
    await env.repo.setSharedWithParent(l!.id, true);
    expect((await env.repo.parentView()).sharedLessons.single.text, '還沒分享');
    await env.repo.setParentPin('1234');
    final json = await env.repo.exportJson();
    expect(json.contains('1234'), isFalse);
    await env.repo.deleteAll();
    expect(await env.repo.watchLessons().first, isEmpty);
    expect(await env.repo.taskTemplates(), isNotEmpty);
  });
}
