import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/clock.dart';
import 'core/copy_rules.dart';
import 'data/db.dart';
import 'data/repository.dart';
import 'domain/lesson/llm_lesson_service.dart';
import 'domain/lesson/template_lesson_service.dart';
import 'domain/lesson_service.dart';
import 'domain/models.dart';
import 'safety/crisis_detector.dart';

/// 資料庫。`main.dart` 與測試會 override（測試用 in-memory）。
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('override databaseProvider'));

/// 文案規則（`assets/copy_rules.json`）。`main.dart` 載入後 override。
final copyRulesProvider = Provider<CopyRules>((ref) => throw UnimplementedError('override copyRulesProvider'));

/// 危機偵測（`assets/crisis_patterns.json`）。`main.dart` 載入後 override。
final crisisDetectorProvider =
    Provider<CrisisDetector>((ref) => throw UnimplementedError('override crisisDetectorProvider'));

final randomProvider = Provider<Random>((ref) => Random());

final repositoryProvider = Provider<Repository>(
  (ref) => Repository(ref.watch(databaseProvider), clock: ref.watch(clockProvider)),
);

final settingsProvider = StreamProvider<AppSettings>((ref) => ref.watch(repositoryProvider).watchSettings());

/// 步步說話的方式；設定還沒載入時用活潑。
final toneProvider = Provider<AgeTone>((ref) => ref.watch(settingsProvider).value?.tone ?? AgeTone.lively);

final dressUpProvider = StreamProvider<DressUp>((ref) => ref.watch(repositoryProvider).watchDressUp());

final todayPlansProvider = StreamProvider<List<Plan>>(
  (ref) => ref.watch(repositoryProvider).watchPlans(ref.watch(todayKeyProvider)),
);

final todayRecordProvider = StreamProvider<DayRecord?>(
  (ref) => ref.watch(repositoryProvider).watchDayRecord(ref.watch(todayKeyProvider)),
);

final lessonsProvider = StreamProvider<List<Lesson>>((ref) => ref.watch(repositoryProvider).watchLessons());

final plannedDaysProvider = StreamProvider<List<PlannedDay>>((ref) => ref.watch(repositoryProvider).watchPlannedDays());

/// 孩子挑事情用：預設、家長建議、孩子自己的事情庫。
final taskChoicesProvider = StreamProvider<List<TaskTemplate>>((ref) => ref.watch(repositoryProvider).watchTaskChoices());

final cueChoicesProvider = StreamProvider<List<CueTemplate>>((ref) => ref.watch(repositoryProvider).watchCueChoices());

/// LLM 代理的 client。null = 沒有可用的 LLM（預設；沒設 emulator 也沒部署）。
final lessonLlmClientProvider = Provider<LessonLlmClient?>((ref) => null);

final templateLessonServiceProvider = Provider<TemplateLessonService>(
  (ref) => TemplateLessonService(rules: ref.watch(copyRulesProvider), random: ref.watch(randomProvider)),
);

/// 「步步學到」：家長關掉 LLM 或沒有 client → 範本；否則 LLM（失敗退回範本）。
final lessonServiceProvider = Provider<LessonService>((ref) {
  final template = ref.watch(templateLessonServiceProvider);
  final llmOn = ref.watch(settingsProvider).value?.llmEnabled ?? false;
  final client = ref.watch(lessonLlmClientProvider);
  if (!llmOn || client == null) return template;
  return LlmLessonService(
    client: client,
    fallback: template,
    rules: ref.watch(copyRulesProvider),
    crisisDetector: ref.watch(crisisDetectorProvider),
  );
});
