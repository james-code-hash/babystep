import 'package:drift/drift.dart';

part 'db.g.dart';

/// 本地 SQLite（drift）。孩子的資料只在這裡（A2、A4、底線 8）。
///
/// 刻意沒有的表／欄位：心情、上次開啟、使用時長、完成統計。

@DataClassName('TaskTemplateRow')
class TaskTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get emoji => text()();
  TextColumn get label => text()();

  /// preset / parent / child（見 TemplateOrigin）
  TextColumn get origin => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CueTemplateRow')
class CueTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get origin => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PlanRow')
class Plans extends Table {
  TextColumn get id => text()();
  TextColumn get dayKey => text()();
  IntColumn get position => integer()();
  TextColumn get emoji => text()();
  TextColumn get task => text()();
  TextColumn get cue => text()();
  TextColumn get why => text().nullable()();

  /// done / partly / notToday；還沒回顧是 null。
  TextColumn get outcome => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DayRecordRow')
class DayRecords extends Table {
  TextColumn get dayKey => text()();
  TextColumn get reflection => text().nullable()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {dayKey};
}

@DataClassName('LessonRow')
class Lessons extends Table {
  TextColumn get id => text()();
  TextColumn get dayKey => text()();
  TextColumn get body => text()();
  TextColumn get kind => text()();
  TextColumn get sourceQuote => text().nullable()();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  BoolColumn get sharedWithParent => boolean().withDefault(const Constant(false))();
  TextColumn get source => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 簡單的 key-value 設定（tone、llmEnabled、reminderSlots、parentPin、dressUp、onboarded）。
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [TaskTemplates, CueTemplates, Plans, DayRecords, Lessons, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // 刪掉的資料列要真的被覆寫成 0，不能只標成空閒頁面還留在檔案裡（底線 8）。
        beforeOpen: (_) => customStatement('PRAGMA secure_delete = ON'),
      );
}
