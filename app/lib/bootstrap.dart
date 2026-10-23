import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';

import 'core/copy_rules.dart';
import 'data/db.dart';
import 'data/repository.dart';
import 'providers.dart';
import 'safety/crisis_detector.dart';

/// 啟動時要準備好的東西：規則、危機字表、資料庫、預設範本。
/// 刻意不初始化 Firebase：LLM 預設關閉，核心循環完全離線（A2、A3）。
Future<List<Override>> bootstrapOverrides({AppDatabase? database}) async {
  final rules = CopyRules.fromJsonString(await rootBundle.loadString('assets/copy_rules.json'));
  final crisis = CrisisDetector.fromJsonString(await rootBundle.loadString('assets/crisis_patterns.json'));
  final db = database ?? AppDatabase(driftDatabase(name: 'little_steps'));
  await Repository(db).seedIfEmpty();
  return [
    databaseProvider.overrideWithValue(db),
    copyRulesProvider.overrideWithValue(rules),
    crisisDetectorProvider.overrideWithValue(crisis),
  ];
}
