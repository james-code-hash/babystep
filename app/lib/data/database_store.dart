import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'db.dart';
import 'repository.dart';

/// 裝置上的資料庫檔，以及「整個刪掉、重開一個新的」（底線 8、A4）。
///
/// [reset] 會關掉目前的資料庫、刪掉 `.sqlite` 與旁邊的 `-wal`／`-shm`／`-journal`，
/// 再在同一個位置開一個全新的資料庫並放入預設範本。呼叫端接著要
/// `ref.invalidate(databaseProvider)`，讓所有 provider 換到新的資料庫（App 不用重開）。
class DatabaseStore {
  DatabaseStore({required this.path, required AppDatabase Function(String path) open})
      : _open = open,
        _current = open(path);

  /// 裝置上的位置：Application Support（iOS 的 `Library/Application Support`、Android 的 `files/`）。
  /// 這個資料夾不進 iCloud／Google 備份：iOS 由 AppDelegate 設 isExcludedFromBackup，
  /// Android 由 manifest 關掉 allowBackup 並排除所有 domain（見 decisions.md G4）。
  static Future<DatabaseStore> onDevice({String name = 'little_steps'}) async {
    final dir = await getApplicationSupportDirectory();
    return DatabaseStore(
      path: p.join(dir.path, '$name.sqlite'),
      open: (path) => AppDatabase(driftDatabase(
        name: name,
        native: DriftNativeOptions(databasePath: () async => path),
      )),
    );
  }

  final String path;
  final AppDatabase Function(String path) _open;
  AppDatabase _current;

  AppDatabase get current => _current;

  /// 資料庫本體與 SQLite 會在旁邊產生的檔案。
  List<File> get files => [for (final suffix in const ['', '-wal', '-shm', '-journal']) File('$path$suffix')];

  Future<void> reset() async {
    await _current.close();
    for (final f in files) {
      if (await f.exists()) await f.delete();
    }
    _current = _open(path);
    await Repository(_current).seedIfEmpty();
  }
}

/// 裝置上才有（`bootstrap.dart` override）；測試的 in-memory 資料庫是 null，刪除時只清資料列。
final databaseStoreProvider = Provider<DatabaseStore?>((ref) => null);
