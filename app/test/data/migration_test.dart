// PR #1 的裝置上是 v1 的資料庫檔；升到 v5（全家一起、卡住的時候、月回顧的信、再看一次口袋）時，
// 舊資料要留著，新的表和欄位要能用。
import 'dart:io';

import 'package:drift/drift.dart' show OpeningDetails, QueryExecutor, QueryExecutorUser, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/data/db.dart';
import 'package:little_steps/data/repository.dart';
import 'package:little_steps/domain/pocket.dart';

/// PR #1（schemaVersion 1）時 drift 建出來的表，原樣抄下來。
const _v1 = [
  'CREATE TABLE "task_templates" ("id" TEXT NOT NULL, "emoji" TEXT NOT NULL, "label" TEXT NOT NULL, "origin" TEXT NOT NULL, "sort_order" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY ("id"))',
  'CREATE TABLE "cue_templates" ("id" TEXT NOT NULL, "label" TEXT NOT NULL, "origin" TEXT NOT NULL, "sort_order" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY ("id"))',
  'CREATE TABLE "plans" ("id" TEXT NOT NULL, "day_key" TEXT NOT NULL, "position" INTEGER NOT NULL, "emoji" TEXT NOT NULL, "task" TEXT NOT NULL, "cue" TEXT NOT NULL, "why" TEXT NULL, "outcome" TEXT NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "day_records" ("day_key" TEXT NOT NULL, "reflection" TEXT NULL, "ended_at" INTEGER NULL, PRIMARY KEY ("day_key"))',
  'CREATE TABLE "lessons" ("id" TEXT NOT NULL, "day_key" TEXT NOT NULL, "body" TEXT NOT NULL, "kind" TEXT NOT NULL, "source_quote" TEXT NULL, "favorite" INTEGER NOT NULL DEFAULT 0 CHECK ("favorite" IN (0, 1)), "shared_with_parent" INTEGER NOT NULL DEFAULT 0 CHECK ("shared_with_parent" IN (0, 1)), "source" TEXT NOT NULL, "created_at" INTEGER NOT NULL, PRIMARY KEY ("id"))',
  'CREATE TABLE "settings" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, PRIMARY KEY ("key"))',
];

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('little_steps_migrate_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('a v1 database from PR #1 upgrades to the current schema and keeps its data', () async {
    final file = File('${tmp.path}/v1.sqlite');
    final v1 = NativeDatabase(
      file,
      setup: (raw) {
        for (final sql in _v1) {
          raw.execute(sql);
        }
        raw.execute('''INSERT INTO plans (id, day_key, position, emoji, task, cue, why, outcome)
          VALUES ('p1', '2026-10-20', 0, '📖', '看一本書', '我吃完晚飯', NULL, 'done')''');
        raw.execute('PRAGMA user_version = 1');
      },
    );
    await v1.ensureOpen(_NoUser());
    await v1.close();

    final db = AppDatabase(NativeDatabase(file));
    final repo = Repository(db);
    // SQLite 會把不存在的 "欄位" 當成字串，所以直接看表的欄位，不靠查詢失敗。
    final cols = [for (final r in await db.customSelect('PRAGMA table_info(plans)').get()) r.data['name']];
    expect(cols, contains('stuck_plan'));
    for (final table in ['family_today_entries', 'family_notes', 'month_letters', 'pocket_groups', 'pocket_cards']) {
      final found = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
            variables: [Variable.withString(table)],
          )
          .get();
      expect(found, hasLength(1), reason: '$table was not created');
    }
    final plans = await repo.plans('2026-10-20');
    expect(plans.single.task, '看一本書');
    expect(plans.single.stuck, isNull);
    expect(await repo.familyNotes(), isEmpty);
    expect(await repo.familyToday('2026-10-20'), isEmpty);
    expect(await repo.monthLetters(), isEmpty);
    // 新的表真的能寫。
    await repo.addFamilyNote(who: '阿嬤', text: '週末一起去公園');
    expect(await repo.familyNotes(), hasLength(1));
    // v5：再看一次口袋（M1）。
    await repo.savePocketCard(const PocketCardDraft(prompt: '7×8'));
    expect(await repo.pocketCards(), hasLength(1));
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.single, db.schemaVersion);
    await db.close();
  });
}

class _NoUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
