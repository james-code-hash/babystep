import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';

import 'core/copy_rules.dart';
import 'data/db.dart';
import 'data/repository.dart';
import 'domain/lesson/firebase_llm_client.dart';
import 'providers.dart';
import 'safety/crisis_detector.dart';

/// 啟動時要準備好的東西：規則、危機字表、資料庫、預設範本。
/// Firebase 只有在開發時帶了 `--dart-define=LLM_EMULATOR_HOST=...` 才會初始化（只連 emulator）；
/// 其他情況 App 完全不碰 Firebase，核心循環離線、走範本（A2、A3）。
Future<List<Override>> bootstrapOverrides({AppDatabase? database}) async {
  final rules = CopyRules.fromJsonString(await rootBundle.loadString('assets/copy_rules.json'));
  final crisis = CrisisDetector.fromJsonString(await rootBundle.loadString('assets/crisis_patterns.json'));
  final db = database ?? AppDatabase(driftDatabase(name: 'little_steps'));
  await Repository(db).seedIfEmpty();
  final llmClient = await createLessonLlmClient();
  return [
    databaseProvider.overrideWithValue(db),
    copyRulesProvider.overrideWithValue(rules),
    crisisDetectorProvider.overrideWithValue(crisis),
    lessonLlmClientProvider.overrideWithValue(llmClient),
  ];
}
