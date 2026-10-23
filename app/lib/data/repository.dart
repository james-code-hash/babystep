import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../copy/common.dart';
import '../core/clock.dart';
import '../core/config.dart';
import '../domain/lesson_service.dart';
import '../domain/models.dart';
import '../domain/parent_view.dart';
import 'db.dart';

/// 成長小路上的一天：只有「有計畫的日子」才會出現（C5）。刻意不帶 outcome。
class PlannedDay {
  const PlannedDay({required this.dayKey, required this.emojis, required this.tasks, required this.cues});
  final String dayKey;
  final List<String> emojis;
  final List<String> tasks;
  final List<String> cues;
}

/// 所有資料存取都經過這裡。家長區只能用 [parentView]／[watchParentView] 與範本、設定的寫入。
class Repository {
  Repository(this._db, {Clock clock = const Clock(), Uuid uuid = const Uuid()})
      // ignore: prefer_initializing_formals
      : _clock = clock,
        // ignore: prefer_initializing_formals
        _uuid = uuid;

  final AppDatabase _db;
  final Clock _clock;
  final Uuid _uuid;

  String _id() => _uuid.v4();

  // ---------------------------------------------------------------- 初始化

  /// 第一次開啟時放入預設範本與提醒時段。重複呼叫不會重複放。
  Future<void> seedIfEmpty() async {
    final seeded = await _getSetting(_kSeeded);
    if (seeded != null) return;
    await _db.transaction(() async {
      await _insertPresets();
      final slots = [
        for (final (i, s) in DefaultTemplates.reminderSlots.indexed)
          ReminderSlot(id: 'preset-slot-$i', label: s.$1, startMinute: s.$2, endMinute: s.$3),
      ];
      await _setSetting(_kReminderSlots, jsonEncode([for (final s in slots) s.toJson()]));
      await _setSetting(_kSeeded, 'true');
    });
  }

  Future<void> _insertPresets() async {
    for (final (i, t) in DefaultTemplates.tasks.indexed) {
      await _db.into(_db.taskTemplates).insertOnConflictUpdate(TaskTemplatesCompanion.insert(
            id: 'preset-task-$i',
            emoji: t.$1,
            label: t.$2,
            origin: TemplateOrigin.preset.name,
            sortOrder: Value(i),
          ));
    }
    for (final (i, c) in DefaultTemplates.cues.indexed) {
      await _db.into(_db.cueTemplates).insertOnConflictUpdate(CueTemplatesCompanion.insert(
            id: 'preset-cue-$i',
            label: c,
            origin: TemplateOrigin.preset.name,
            sortOrder: Value(i),
          ));
    }
  }

  // ---------------------------------------------------------------- 範本

  TaskTemplate _task(TaskTemplateRow r) => TaskTemplate(
        id: r.id,
        emoji: r.emoji,
        text: r.label,
        origin: enumByName(TemplateOrigin.values, r.origin, TemplateOrigin.preset),
        sortOrder: r.sortOrder,
      );

  CueTemplate _cue(CueTemplateRow r) => CueTemplate(
        id: r.id,
        text: r.label,
        origin: enumByName(TemplateOrigin.values, r.origin, TemplateOrigin.preset),
        sortOrder: r.sortOrder,
      );

  /// 事情範本。[origins] 不給就是全部（含孩子的事情庫）。
  Stream<List<TaskTemplate>> watchTaskTemplates({Set<TemplateOrigin>? origins}) {
    final q = _db.select(_db.taskTemplates)
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder), (t) => OrderingTerm(expression: t.label)]);
    if (origins != null) q.where((t) => t.origin.isIn(origins.map((o) => o.name)));
    return q.watch().map((rows) => rows.map(_task).toList());
  }

  Future<List<TaskTemplate>> taskTemplates({Set<TemplateOrigin>? origins}) =>
      watchTaskTemplates(origins: origins).first;

  Stream<List<CueTemplate>> watchCueTemplates({Set<TemplateOrigin>? origins}) {
    final q = _db.select(_db.cueTemplates)
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder), (t) => OrderingTerm(expression: t.label)]);
    if (origins != null) q.where((t) => t.origin.isIn(origins.map((o) => o.name)));
    return q.watch().map((rows) => rows.map(_cue).toList());
  }

  Future<List<CueTemplate>> cueTemplates({Set<TemplateOrigin>? origins}) =>
      watchCueTemplates(origins: origins).first;

  Future<int> _nextOrder(String table) async {
    final row = await _db.customSelect('SELECT COALESCE(MAX(sort_order), -1) + 1 AS n FROM $table').getSingle();
    return row.read<int>('n');
  }

  /// 新增事情範本。孩子自己寫的事情用 [TemplateOrigin.child]（孩子的事情庫）。
  /// 同樣文字已經存在就直接回傳那一筆。
  Future<TaskTemplate> addTaskTemplate({required String emoji, required String text, required TemplateOrigin origin}) async {
    final clean = text.trim();
    final existing = await (_db.select(_db.taskTemplates)..where((t) => t.label.equals(clean))).getSingleOrNull();
    if (existing != null) return _task(existing);
    final id = _id();
    final order = await _nextOrder('task_templates');
    await _db.into(_db.taskTemplates).insert(TaskTemplatesCompanion.insert(
          id: id,
          emoji: emoji,
          label: clean,
          origin: origin.name,
          sortOrder: Value(order),
        ));
    return TaskTemplate(id: id, emoji: emoji, text: clean, origin: origin, sortOrder: order);
  }

  Future<void> updateTaskTemplate(TaskTemplate t) =>
      (_db.update(_db.taskTemplates)..where((r) => r.id.equals(t.id))).write(TaskTemplatesCompanion(
        emoji: Value(t.emoji),
        label: Value(t.text.trim()),
        sortOrder: Value(t.sortOrder),
      ));

  Future<void> deleteTaskTemplate(String id) => (_db.delete(_db.taskTemplates)..where((r) => r.id.equals(id))).go();

  /// 新增時間點範本；文字會補成「我⋯」開頭。
  Future<CueTemplate> addCueTemplate({required String text, required TemplateOrigin origin}) async {
    final clean = CueTemplate.normalize(text);
    final existing = await (_db.select(_db.cueTemplates)..where((t) => t.label.equals(clean))).getSingleOrNull();
    if (existing != null) return _cue(existing);
    final id = _id();
    final order = await _nextOrder('cue_templates');
    await _db.into(_db.cueTemplates).insert(CueTemplatesCompanion.insert(
          id: id,
          label: clean,
          origin: origin.name,
          sortOrder: Value(order),
        ));
    return CueTemplate(id: id, text: clean, origin: origin, sortOrder: order);
  }

  Future<void> updateCueTemplate(CueTemplate c) =>
      (_db.update(_db.cueTemplates)..where((r) => r.id.equals(c.id))).write(CueTemplatesCompanion(
        label: Value(CueTemplate.normalize(c.text)),
        sortOrder: Value(c.sortOrder),
      ));

  Future<void> deleteCueTemplate(String id) => (_db.delete(_db.cueTemplates)..where((r) => r.id.equals(id))).go();

  /// 家長區的「還原預設」：家長與預設範本回到出廠狀態；孩子自己的事情庫不動。
  Future<void> restoreDefaultTemplates() => _db.transaction(() async {
        final keep = TemplateOrigin.child.name;
        await (_db.delete(_db.taskTemplates)..where((t) => t.origin.equals(keep).not())).go();
        await (_db.delete(_db.cueTemplates)..where((t) => t.origin.equals(keep).not())).go();
        await _insertPresets();
      });

  // ---------------------------------------------------------------- 計畫與回顧

  Plan _plan(PlanRow r) => Plan(
        id: r.id,
        dayKey: r.dayKey,
        order: r.position,
        emoji: r.emoji,
        task: r.task,
        cue: r.cue,
        why: r.why,
        outcome: r.outcome == null ? null : enumByName(Outcome.values, r.outcome!, Outcome.notToday),
      );

  Stream<List<Plan>> watchPlans(String dayKey) => (_db.select(_db.plans)
        ..where((p) => p.dayKey.equals(dayKey))
        ..orderBy([(p) => OrderingTerm(expression: p.position)]))
      .watch()
      .map((rows) => rows.map(_plan).toList());

  Future<List<Plan>> plans(String dayKey) => watchPlans(dayKey).first;

  /// 存今天的計畫（覆蓋這一天原本的計畫）。最多 [AppConfig.maxPlansPerDay] 件。
  Future<List<Plan>> savePlans(String dayKey, List<PlanDraft> drafts) async {
    if (drafts.length < AppConfig.minPlansPerDay || drafts.length > AppConfig.maxPlansPerDay) {
      throw ArgumentError('一天 ${AppConfig.minPlansPerDay}–${AppConfig.maxPlansPerDay} 件');
    }
    final saved = <Plan>[];
    await _db.transaction(() async {
      await (_db.delete(_db.plans)..where((p) => p.dayKey.equals(dayKey))).go();
      for (final (i, d) in drafts.indexed) {
        final plan = Plan(
          id: _id(),
          dayKey: dayKey,
          order: i,
          emoji: d.emoji,
          task: d.task.trim(),
          cue: CueTemplate.normalize(d.cue),
          why: (d.why?.trim().isEmpty ?? true) ? null : d.why!.trim(),
        );
        await _db.into(_db.plans).insert(PlansCompanion.insert(
              id: plan.id,
              dayKey: dayKey,
              position: i,
              emoji: plan.emoji,
              task: plan.task,
              cue: plan.cue,
              why: Value(plan.why),
            ));
        saved.add(plan);
      }
    });
    return saved;
  }

  /// 每件計畫各自回顧。三種狀態在資料層完全對等。
  Future<void> setOutcome(String planId, Outcome outcome) =>
      (_db.update(_db.plans)..where((p) => p.id.equals(planId))).write(PlansCompanion(outcome: Value(outcome.name)));

  DayRecord _day(DayRecordRow r) => DayRecord(dayKey: r.dayKey, reflection: r.reflection, endedAt: r.endedAt);

  Stream<DayRecord?> watchDayRecord(String dayKey) =>
      (_db.select(_db.dayRecords)..where((d) => d.dayKey.equals(dayKey))).watchSingleOrNull().map((r) => r == null ? null : _day(r));

  Future<DayRecord?> dayRecord(String dayKey) => watchDayRecord(dayKey).first;

  /// 存晚上歷程問題的原話（跳過就傳 null）。危機內容在呼叫前就要攔下，不會存進來。
  Future<void> saveReflection(String dayKey, String? reflection) async {
    final clean = (reflection?.trim().isEmpty ?? true) ? null : reflection!.trim();
    await _db.into(_db.dayRecords).insert(
          DayRecordsCompanion.insert(dayKey: dayKey, reflection: Value(clean)),
          onConflict: DoUpdate((_) => DayRecordsCompanion(reflection: Value(clean))),
        );
  }

  /// 「今天就到這裡囉」：標記這一天聊完了。
  Future<void> endDay(String dayKey) async {
    final now = _clock.now();
    await _db.into(_db.dayRecords).insert(
          DayRecordsCompanion.insert(dayKey: dayKey, endedAt: Value(now)),
          onConflict: DoUpdate((_) => DayRecordsCompanion(endedAt: Value(now))),
        );
  }

  // ---------------------------------------------------------------- 筆記本

  Lesson _lesson(LessonRow r) => Lesson(
        id: r.id,
        dayKey: r.dayKey,
        text: r.body,
        kind: enumByName(LessonKind.values, r.kind, LessonKind.plainDay),
        sourceQuote: r.sourceQuote,
        favorite: r.favorite,
        sharedWithParent: r.sharedWithParent,
        source: enumByName(LessonSource.values, r.source, LessonSource.template),
        createdAt: r.createdAt,
      );

  /// 孩子選了「記進筆記本」才呼叫。每天最多 [AppConfig.maxLessonsPerDay] 則：同一天再記就覆蓋。
  /// safety 來源的結果不會被存（C6）。
  Future<Lesson?> saveLesson(String dayKey, LessonResult result) async {
    if (result.source == LessonSource.safety) return null;
    final lesson = Lesson(
      id: _id(),
      dayKey: dayKey,
      text: result.text,
      kind: result.kind,
      sourceQuote: result.sourceQuote,
      source: result.source,
      createdAt: _clock.now(),
    );
    await _db.transaction(() async {
      final existing = await (_db.select(_db.lessons)
            ..where((l) => l.dayKey.equals(dayKey))
            ..orderBy([(l) => OrderingTerm(expression: l.createdAt)]))
          .get();
      final overflow = existing.length - AppConfig.maxLessonsPerDay + 1;
      for (final r in existing.take(overflow < 0 ? 0 : overflow)) {
        await (_db.delete(_db.lessons)..where((l) => l.id.equals(r.id))).go();
      }
      await _db.into(_db.lessons).insert(LessonsCompanion.insert(
            id: lesson.id,
            dayKey: dayKey,
            body: lesson.text,
            kind: lesson.kind.name,
            sourceQuote: Value(lesson.sourceQuote),
            source: lesson.source.name,
            createdAt: lesson.createdAt,
          ));
    });
    return lesson;
  }

  /// 筆記本：新的在前。不提供數量（畫面也不顯示數量，C4）。
  Stream<List<Lesson>> watchLessons() => (_db.select(_db.lessons)
        ..orderBy([(l) => OrderingTerm(expression: l.createdAt, mode: OrderingMode.desc)]))
      .watch()
      .map((rows) => rows.map(_lesson).toList());

  Stream<Lesson?> watchLessonFor(String dayKey) =>
      (_db.select(_db.lessons)..where((l) => l.dayKey.equals(dayKey))..limit(1))
          .watchSingleOrNull()
          .map((r) => r == null ? null : _lesson(r));

  Future<void> setFavorite(String lessonId, bool favorite) =>
      (_db.update(_db.lessons)..where((l) => l.id.equals(lessonId))).write(LessonsCompanion(favorite: Value(favorite)));

  /// 分享給家長是孩子主動做的動作，預設不分享（底線 7）。
  Future<void> setSharedWithParent(String lessonId, bool shared) => (_db.update(_db.lessons)
        ..where((l) => l.id.equals(lessonId)))
      .write(LessonsCompanion(sharedWithParent: Value(shared)));

  // ---------------------------------------------------------------- 成長小路

  /// 只列出有計畫的日子（舊的在前）。不帶 outcome：小路的石頭不因完成度上色（C5）。
  Stream<List<PlannedDay>> watchPlannedDays() => (_db.select(_db.plans)
        ..orderBy([(p) => OrderingTerm(expression: p.dayKey), (p) => OrderingTerm(expression: p.position)]))
      .watch()
      .map((rows) {
        final byDay = <String, List<PlanRow>>{};
        for (final r in rows) {
          byDay.putIfAbsent(r.dayKey, () => []).add(r);
        }
        return [
          for (final e in byDay.entries)
            PlannedDay(
              dayKey: e.key,
              emojis: [for (final r in e.value) r.emoji],
              tasks: [for (final r in e.value) r.task],
              cues: [for (final r in e.value) r.cue],
            ),
        ];
      });

  Future<List<PlannedDay>> plannedDays() => watchPlannedDays().first;

  // ---------------------------------------------------------------- 設定

  static const _kTone = 'tone';
  static const _kLlm = 'llmEnabled';
  static const _kReminderSlots = 'reminderSlots';
  static const _kPin = 'parentPin';
  static const _kOnboarded = 'onboarded';
  static const _kDressUp = 'dressUp';
  static const _kSeeded = 'seeded';

  Future<String?> _getSetting(String key) async =>
      (await (_db.select(_db.settings)..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> _setSetting(String key, String value) =>
      _db.into(_db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  AppSettings _settingsFrom(Map<String, String> m) => AppSettings(
        tone: enumByName(AgeTone.values, m[_kTone] ?? '', AgeTone.lively),
        llmEnabled: m[_kLlm] == null ? AppConfig.llmEnabledByDefault : m[_kLlm] == 'true',
        reminderSlots: m[_kReminderSlots] == null
            ? const []
            : [
                for (final s in (jsonDecode(m[_kReminderSlots]!) as List).cast<Map<String, Object?>>())
                  ReminderSlot.fromJson(s),
              ],
        parentPin: m[_kPin],
        onboarded: m[_kOnboarded] == 'true',
      );

  Stream<Map<String, String>> _watchSettingMap() =>
      _db.select(_db.settings).watch().map((rows) => {for (final r in rows) r.key: r.value});

  Stream<AppSettings> watchSettings() => _watchSettingMap().map(_settingsFrom);

  Future<AppSettings> settings() => watchSettings().first;

  Future<void> setTone(AgeTone tone) => _setSetting(_kTone, tone.name);
  Future<void> setLlmEnabled(bool enabled) => _setSetting(_kLlm, '$enabled');
  Future<void> setReminderSlots(List<ReminderSlot> slots) =>
      _setSetting(_kReminderSlots, jsonEncode([for (final s in slots) s.toJson()]));
  Future<void> setParentPin(String pin) => _setSetting(_kPin, pin);
  Future<void> setOnboarded() => _setSetting(_kOnboarded, 'true');

  Stream<DressUp> watchDressUp() => _watchSettingMap().map((m) =>
      m[_kDressUp] == null ? DressUp.initial : DressUp.fromJson(jsonDecode(m[_kDressUp]!) as Map<String, Object?>));

  Future<DressUp> dressUp() => watchDressUp().first;

  /// 只有孩子主動裝扮時呼叫（底線 2）。
  Future<void> setDressUp(DressUp d) => _setSetting(_kDressUp, jsonEncode(d.toJson()));

  // ---------------------------------------------------------------- 家長端

  /// 家長端唯一能讀的資料（底線 7）。
  Stream<ParentView> watchParentView() => _watchSettingMap().asyncMap((_) => parentView());

  Future<ParentView> parentView() async {
    final s = await settings();
    final parentOrigins = {TemplateOrigin.preset, TemplateOrigin.parent};
    final shared = await (_db.select(_db.lessons)
          ..where((l) => l.sharedWithParent.equals(true))
          ..orderBy([(l) => OrderingTerm(expression: l.createdAt, mode: OrderingMode.desc)]))
        .get();
    return ParentView(
      taskTemplates: await taskTemplates(origins: parentOrigins),
      cueTemplates: await cueTemplates(origins: parentOrigins),
      settings: ParentSettingsView(tone: s.tone, llmEnabled: s.llmEnabled, reminderSlots: s.reminderSlots),
      sharedLessons: [for (final r in shared) SharedLesson(id: r.id, dayKey: r.dayKey, text: r.body)],
    );
  }

  // ---------------------------------------------------------------- 匯出與刪除

  /// 完整匯出（底線 8）。家長 PIN 不匯出。
  Future<String> exportJson() async {
    final s = await settings();
    final data = {
      'app': 'little_steps',
      'schemaVersion': _db.schemaVersion,
      'exportedAt': _clock.now().toIso8601String(),
      'settings': {
        'tone': s.tone.name,
        'llmEnabled': s.llmEnabled,
        'reminderSlots': [for (final r in s.reminderSlots) r.toJson()],
        'dressUp': (await dressUp()).toJson(),
      },
      'taskTemplates': [for (final t in await taskTemplates()) t.toJson()],
      'cueTemplates': [for (final c in await cueTemplates()) c.toJson()],
      'plans': [for (final r in await _db.select(_db.plans).get()) _plan(r).toJson()],
      'dayRecords': [for (final r in await _db.select(_db.dayRecords).get()) _day(r).toJson()],
      'lessons': [for (final r in await _db.select(_db.lessons).get()) _lesson(r).toJson()],
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// 刪除全部資料，回到剛安裝的狀態。
  Future<void> deleteAll() async {
    await _db.transaction(() async {
      for (final table in _db.allTables) {
        await _db.delete(table).go();
      }
    });
    await seedIfEmpty();
  }
}
