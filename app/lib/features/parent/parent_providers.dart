import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_root.dart';
import '../../data/database_store.dart';
import '../../domain/parent_view.dart';
import '../../providers.dart';

/// 家長區唯一能讀的資料（底線 7）。
///
/// `Repository.watchParentView()` 目前只在設定改變時重發，所以家長區每次寫入範本後
/// 會 `ref.invalidate(parentViewProvider)` 重新讀一次（已列在 neededChanges）。
final parentViewProvider = StreamProvider.autoDispose<ParentView>(
  (ref) => ref.watch(repositoryProvider).watchParentView(),
);

/// 把匯出檔交給系統分享面板。測試會 override，避免碰到平台。
typedef ParentShare = Future<void> Function(String text, String subject);

final parentShareProvider = Provider<ParentShare>(
  (ref) => (text, subject) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  },
);

/// 「刪除全部資料」（底線 8）。先清掉所有資料列（secure_delete＋VACUUM），
/// 裝置上再把整個資料庫檔刪掉、開一個新的——App 不用重開。
///
/// 有 [startOver]（App 由 `AppRoot` 掛起來，裝置上一定有）：交給它先收掉整個 App、再刪檔重開、
/// 再從首頁重建（H2）。沒有的時候（直接掛 ProviderScope 的測試）就地換資料庫並 invalidate。
typedef DeleteAllData = Future<void> Function({StartOver? startOver});

final deleteAllDataProvider = Provider<DeleteAllData>(
  (ref) => ({StartOver? startOver}) async {
    await ref.read(repositoryProvider).deleteAll();
    final store = ref.read(databaseStoreProvider);
    if (startOver != null) return startOver(store);
    if (store == null) return;
    await store.reset();
    ref.invalidate(databaseProvider);
  },
);
