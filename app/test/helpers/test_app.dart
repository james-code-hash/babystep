import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/app.dart';
import 'package:little_steps/core/clock.dart';
import 'package:little_steps/core/copy_rules.dart';
import 'package:little_steps/data/db.dart';
import 'package:little_steps/data/repository.dart';
import 'package:little_steps/providers.dart';
import 'package:little_steps/safety/crisis_detector.dart';

/// 測試共用：in-memory 資料庫、固定時鐘、固定亂數、從檔案讀規則。
/// 測試的工作目錄是 `app/`。

CopyRules loadCopyRules() => CopyRules.fromJsonString(File('assets/copy_rules.json').readAsStringSync());

CrisisDetector loadCrisisDetector() =>
    CrisisDetector.fromJsonString(File('assets/crisis_patterns.json').readAsStringSync());

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

class TestEnv {
  TestEnv({DateTime? now, int seed = 1})
      : db = memoryDb(),
        clock = FixedClock(now ?? DateTime(2026, 10, 23, 19, 30)),
        random = Random(seed);

  final AppDatabase db;
  final FixedClock clock;
  final Random random;
  late final Repository repo = Repository(db, clock: clock);

  List<Override> get overrides => [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        randomProvider.overrideWithValue(random),
        copyRulesProvider.overrideWithValue(loadCopyRules()),
        crisisDetectorProvider.overrideWithValue(loadCrisisDetector()),
      ];

  Future<void> seed() => repo.seedIfEmpty();

  ProviderContainer container({List<Override> extra = const []}) =>
      ProviderContainer(overrides: [...overrides, ...extra]);

  Future<void> dispose() => db.close();
}

/// 把整個 App 掛起來（含 router）。
Future<void> pumpApp(WidgetTester tester, TestEnv env, {List<Override> extra = const []}) async {
  await env.seed();
  await tester.pumpWidget(ProviderScope(overrides: [...env.overrides, ...extra], child: const LittleStepsApp()));
  await tester.pumpAndSettle();
}

/// 只掛一個 widget（含主題與 ProviderScope）。
Future<void> pumpScreen(WidgetTester tester, TestEnv env, Widget child, {List<Override> extra = const []}) async {
  await env.seed();
  await tester.pumpWidget(ProviderScope(
    overrides: [...env.overrides, ...extra],
    child: MaterialApp(home: child),
  ));
  await tester.pumpAndSettle();
}
