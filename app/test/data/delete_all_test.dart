// 底線 8：「刪除全部」要真的從磁碟上消失，不能只是資料列看不到、位元組還留在 SQLite 檔裡。
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/core/clock.dart';
import 'package:little_steps/data/database_store.dart';
import 'package:little_steps/data/db.dart';
import 'package:little_steps/data/repository.dart';
import 'package:little_steps/domain/lesson_service.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/parent/parent_providers.dart';
import 'package:little_steps/providers.dart';

const _sentence = '我先把最難的那一題寫完再去玩積木';
const _task = '練習寫毛筆字給阿嬤看';
const _lesson = '原來先做最難的那一題，後面就輕鬆很多';

bool _contains(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

/// 資料庫檔與旁邊的 -wal／-shm／-journal 裡，有沒有出現 [text] 的 UTF-8 位元組。
bool onDisk(String dbPath, String text) {
  final needle = utf8.encode(text);
  for (final suffix in ['', '-wal', '-shm', '-journal']) {
    final f = File('$dbPath$suffix');
    if (f.existsSync() && _contains(f.readAsBytesSync(), needle)) return true;
  }
  return false;
}

Future<void> _writeChildData(Repository repo, String day) async {
  await repo.seedIfEmpty();
  await repo.savePlans(day, const [PlanDraft(emoji: '✏️', task: _task, cue: '我吃完晚飯')]);
  await repo.saveReflection(day, _sentence);
  await repo.saveLesson(day, const LessonResult(text: _lesson, kind: LessonKind.method, source: LessonSource.template));
  await repo.addTaskTemplate(emoji: '⭐', text: _task, origin: TemplateOrigin.child);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory tmp;
  final clock = FixedClock(DateTime(2026, 10, 23, 19, 30));
  final day = dayKeyOf(clock.now());

  setUp(() => tmp = Directory.systemTemp.createTempSync('little_steps_delete_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('Repository.deleteAll overwrites the bytes (secure_delete + VACUUM), even without deleting the file', () async {
    final path = '${tmp.path}/a.sqlite';
    final db = AppDatabase(NativeDatabase(File(path)));
    final repo = Repository(db, clock: clock);
    await _writeChildData(repo, day);
    expect(onDisk(path, _sentence), isTrue, reason: 'control: the sentence really was written to the file');

    await repo.deleteAll();
    for (final text in [_sentence, _task, _lesson]) {
      expect(onDisk(path, text), isFalse, reason: '$text still readable on disk');
    }
    // 回到剛安裝的狀態，還能用。
    expect(await repo.taskTemplates(), isNotEmpty);
    expect(await repo.dayRecord(day), isNull);
    await db.close();
  });

  test('DatabaseStore.reset removes the files and opens a fresh, seeded database', () async {
    final path = '${tmp.path}/b.sqlite';
    final store = DatabaseStore(path: path, open: (p) => AppDatabase(NativeDatabase(File(p))));
    final old = store.current;
    await _writeChildData(Repository(old, clock: clock), day);
    // 留一個假的 -journal，確認旁邊的檔案也會被刪。
    File('$path-journal').writeAsStringSync(_sentence);

    await store.reset();
    expect(identical(store.current, old), isFalse);
    expect(File('$path-journal').existsSync(), isFalse);
    expect(onDisk(path, _sentence), isFalse);
    final repo = Repository(store.current, clock: clock);
    expect(await repo.taskTemplates(), isNotEmpty, reason: 'fresh database is seeded');
    expect(await repo.plans(day), isEmpty);
    await store.current.close();
  });

  test('deleteAllDataProvider: app keeps working on the new database without a restart', () async {
    final path = '${tmp.path}/c.sqlite';
    final store = DatabaseStore(path: path, open: (p) => AppDatabase(NativeDatabase(File(p))));
    final container = ProviderContainer(overrides: [
      databaseStoreProvider.overrideWithValue(store),
      databaseProvider.overrideWith((ref) => ref.watch(databaseStoreProvider)!.current),
      clockProvider.overrideWithValue(clock),
    ]);
    addTearDown(container.dispose);

    final before = container.read(repositoryProvider);
    await _writeChildData(before, day);
    await before.setParentPin('1234');
    expect(onDisk(path, _sentence), isTrue);

    await container.read(deleteAllDataProvider)();

    for (final text in [_sentence, _task, _lesson]) {
      expect(onDisk(path, text), isFalse, reason: '$text still readable on disk');
    }
    final after = container.read(repositoryProvider);
    expect(identical(after, before), isFalse, reason: 'providers moved to the new database');
    expect(container.read(databaseProvider), same(store.current));
    expect((await after.settings()).parentPin, isNull);
    expect(await after.exportJson(), isNot(contains(_sentence)));
    // 照常可以再排計畫。
    await after.savePlans(day, const [PlanDraft(emoji: '📖', task: '看一本書', cue: '我洗完澡')]);
    expect((await after.plans(day)).single.task, '看一本書');
    await store.current.close();
  });

  test('without a DatabaseStore (in-memory, tests) deleteAll still clears every row', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(clock),
    ]);
    addTearDown(container.dispose);
    await _writeChildData(container.read(repositoryProvider), day);
    await container.read(deleteAllDataProvider)();
    final repo = container.read(repositoryProvider);
    expect(await repo.dayRecord(day), isNull);
    expect(await repo.plans(day), isEmpty);
    await db.close();
  });
}
