import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

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
