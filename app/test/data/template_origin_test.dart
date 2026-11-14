// 底線 7：家長新增範本時，不能因為「孩子自己寫過同一句」而被吃掉——那會讓家長猜出孩子的私人事情庫。
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/domain/models.dart';

import '../helpers/test_app.dart';

void main() {
  late TestEnv env;
  setUp(() async {
    env = TestEnv();
    await env.seed();
  });
  tearDown(() => env.dispose());

  const secretTask = '打電動前先寫功課';
  const secretCue = '我打完電動';

  Future<List<String>> parentTasks() async => [for (final t in (await env.repo.parentView()).taskTemplates) t.text];
  Future<List<String>> parentCues() async => [for (final c in (await env.repo.parentView()).cueTemplates) c.text];

  test('parent adding a label the child already wrote creates a parent row that ParentView shows', () async {
    await env.repo.addTaskTemplate(emoji: '⭐', text: secretTask, origin: TemplateOrigin.child);
    await env.repo.addCueTemplate(text: secretCue, origin: TemplateOrigin.child);
    expect(await parentTasks(), isNot(contains(secretTask)));
    expect(await parentCues(), isNot(contains(secretCue)));

    final t = await env.repo.addTaskTemplate(emoji: '🎮', text: secretTask, origin: TemplateOrigin.parent);
    final c = await env.repo.addCueTemplate(text: secretCue, origin: TemplateOrigin.parent);
    expect(t.origin, TemplateOrigin.parent);
    expect(c.origin, TemplateOrigin.parent);
    expect(await parentTasks(), contains(secretTask));
    expect(await parentCues(), contains(secretCue));
  });

  test('what the parent sees after adding is the same whether or not the child wrote it', () async {
    Future<(List<String>, List<String>)> run({required bool childWroteIt}) async {
      final e = TestEnv();
      await e.seed();
      if (childWroteIt) {
        await e.repo.addTaskTemplate(emoji: '⭐', text: secretTask, origin: TemplateOrigin.child);
        await e.repo.addCueTemplate(text: secretCue, origin: TemplateOrigin.child);
      }
      await e.repo.addTaskTemplate(emoji: '🎮', text: secretTask, origin: TemplateOrigin.parent);
      await e.repo.addCueTemplate(text: secretCue, origin: TemplateOrigin.parent);
      final v = await e.repo.parentView();
      final out = ([for (final t in v.taskTemplates) t.text], [for (final c in v.cueTemplates) c.text]);
      await e.dispose();
      return out;
    }

    final withChild = await run(childWroteIt: true);
    final without = await run(childWroteIt: false);
    expect(withChild.$1, without.$1);
    expect(withChild.$2, without.$2);
  });

  test('parent adding the same label twice still reuses its own row', () async {
    final a = await env.repo.addTaskTemplate(emoji: '🎮', text: '收書包', origin: TemplateOrigin.parent);
    final b = await env.repo.addTaskTemplate(emoji: '🎮', text: '收書包', origin: TemplateOrigin.parent);
    expect(b.id, a.id);
    expect((await parentTasks()).where((t) => t == '收書包'), hasLength(1));
  });

  test('child adding a label that exists as parent or preset reuses that row', () async {
    final parent = await env.repo.addTaskTemplate(emoji: '🎮', text: '收書包', origin: TemplateOrigin.parent);
    final reused = await env.repo.addTaskTemplate(emoji: '⭐', text: '收書包', origin: TemplateOrigin.child);
    expect(reused.id, parent.id);
    final preset = (await env.repo.taskTemplates(origins: {TemplateOrigin.preset})).first;
    expect((await env.repo.addTaskTemplate(emoji: '⭐', text: preset.text, origin: TemplateOrigin.child)).id, preset.id);
    final presetCue = (await env.repo.cueTemplates(origins: {TemplateOrigin.preset})).first;
    expect((await env.repo.addCueTemplate(text: presetCue.text, origin: TemplateOrigin.child)).id, presetCue.id);
  });

  test('child picker lists each label once, preferring the parent row (keeps 爸媽建議)', () async {
    await env.repo.addTaskTemplate(emoji: '⭐', text: secretTask, origin: TemplateOrigin.child);
    await env.repo.addTaskTemplate(emoji: '🎮', text: secretTask, origin: TemplateOrigin.parent);
    await env.repo.addCueTemplate(text: secretCue, origin: TemplateOrigin.child);
    await env.repo.addCueTemplate(text: secretCue, origin: TemplateOrigin.parent);

    final tasks = await env.repo.watchTaskChoices().first;
    final same = tasks.where((t) => t.text == secretTask).toList();
    expect(same, hasLength(1));
    expect(same.single.origin, TemplateOrigin.parent);
    expect(tasks.map((t) => t.text).toSet(), hasLength(tasks.length));

    final cues = await env.repo.watchCueChoices().first;
    final sameCue = cues.where((c) => c.text == secretCue).toList();
    expect(sameCue, hasLength(1));
    expect(sameCue.single.origin, TemplateOrigin.parent);

    // 匯出仍然是完整的（兩筆都在）。
    expect((await env.repo.taskTemplates()).where((t) => t.text == secretTask), hasLength(2));
  });
}
