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

  /// 「如果卡住了，我就⋯」（MCII，簡潔模式才問，可跳過）。v3 加入。
  TextColumn get stuckPlan => text().nullable()();

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

/// 全家一起：家人自己的「今天的我」（家長在家長區寫，孩子在首頁看得到）。沒有完成狀態。
@DataClassName('FamilyTodayRow')
class FamilyTodayEntries extends Table {
  TextColumn get id => text()();
  TextColumn get dayKey => text()();

  /// 誰（爸爸、媽媽、阿嬤⋯⋯，家長自己填）。
  TextColumn get who => text()();
  TextColumn get body => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 家人留給孩子的話，由步步轉達（文案庫 §4.11）。寫入前要過文案規則。
@DataClassName('FamilyNoteRow')
class FamilyNotes extends Table {
  TextColumn get id => text()();
  TextColumn get dayKey => text()();
  TextColumn get who => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// 孩子看過了沒（只用來決定首頁要不要再轉達）。**不給家長**：家長端沒有已讀回條（底線 7）。
  BoolColumn get childRead => boolean().withDefault(const Constant(false))();

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

@DriftDatabase(tables: [TaskTemplates, CueTemplates, Plans, DayRecords, Lessons, Settings, FamilyTodayEntries, FamilyNotes])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v2：全家一起（I2）。
          if (from < 2) {
            await m.createTable(familyTodayEntries);
            await m.createTable(familyNotes);
          }
          // v3：卡住的時候的計畫（I3）。
          if (from < 3) await m.addColumn(plans, plans.stuckPlan);
        },
        // 刪掉的資料列要真的被覆寫成 0，不能只標成空閒頁面還留在檔案裡（底線 8）。
        beforeOpen: (_) => customStatement('PRAGMA secure_delete = ON'),
      );
}
