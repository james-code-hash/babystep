import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_root.dart';
import '../../core/clock.dart';
import '../../core/config.dart';
import '../../data/database_store.dart';
import '../../data/pocket_photos.dart';
import '../../domain/parent_view.dart';
import '../../providers.dart';

/// 家長區唯一能讀的資料（底線 7）。
///
/// `Repository.watchParentView()` 在範本、設定、筆記、家人的資料或信有變時重發。
///
/// 「今天的我」用的是 [todayKeyProvider]，和孩子那一端同一天：家長區開著跨過午夜
/// （或從背景回來已經是隔天），就換成新的一天，不留著昨天的。
final parentViewProvider = StreamProvider.autoDispose<ParentView>(
  (ref) => ref.watch(repositoryProvider).watchParentView(day: ref.watch(todayKeyProvider)),
);

/// 把匯出檔交給系統分享面板。測試會 override，避免碰到平台。
/// [files] 是要一起送出去的檔案路徑（口袋的題目照片，M1）。
typedef ParentShare = Future<void> Function(String text, String subject, {List<String> files});

final parentShareProvider = Provider<ParentShare>(
  (ref) => (text, subject, {files = const []}) async {
    // 有照片時，很多分享目標（存到檔案、雲端硬碟）只收檔案、把文字丟掉；
    // 所以匯出的 JSON 也放成一個檔案跟照片一起送，資料才不會不見（底線 8）。
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: subject,
        files: files.isEmpty
            ? null
            : [
                XFile.fromData(utf8.encode(text), name: ParentConfig.exportFileName, mimeType: 'application/json'),
                for (final f in files) XFile(f),
              ],
      ),
    );
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
    // 口袋的題目照片在資料庫外面，整個資料夾一起刪掉（底線 8、M1）。
    await ref.read(pocketPhotoStoreProvider)?.deleteAll();
    final store = ref.read(databaseStoreProvider);
    if (startOver != null) return startOver(store);
    if (store == null) return;
    await store.reset();
    ref.invalidate(databaseProvider);
  },
);
