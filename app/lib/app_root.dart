import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'app.dart';
import 'core/theme.dart';
import 'data/database_store.dart';

/// 「重新開始」：先把整個 App 收掉，再（裝置上）把資料庫檔刪掉重開，最後從首頁重建。
typedef StartOver = Future<void> Function(DatabaseStore? store);

/// App 的最外層：一個 [ProviderScope] 加上 [LittleStepsApp]，可以在 App 裡「重新開始」。
///
/// 「刪除全部資料」用它（稽核 bug 1；docs/decisions.md H2）：
/// 1. 收掉整個 ProviderScope 與畫面堆疊，所有 drift 查詢的訂閱都取消；
/// 2. 這時才關掉資料庫、刪檔、開一個新的（有訂閱掛著時——例如被家長區蓋住、暫停中的首頁——
///    關資料庫會一直等下去，畫面就停在舊的資料）；
/// 3. 用同一份啟動設定（同一個 DatabaseStore，裡面已經是新的資料庫）重建，回到首頁。
/// 結果和重開 App 一樣乾淨。
class AppRoot extends StatefulWidget {
  const AppRoot({super.key, required this.overrides});

  final List<Override> overrides;

  /// 有 [AppRoot] 時回傳「重新開始」；測試直接掛 ProviderScope 時是 null。
  static StartOver? startOverOf(BuildContext context) =>
      context.findAncestorStateOfType<_AppRootState>()?._startOver;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  int _generation = 0;
  bool _down = false;

  Future<void> _startOver(DatabaseStore? store) async {
    if (!mounted || _down) return;
    setState(() => _down = true);
    // 等這一個 frame 把舊的 ProviderScope 拆掉（訂閱全部取消）。
    await WidgetsBinding.instance.endOfFrame;
    try {
      await store?.reset();
    } finally {
      if (mounted) {
        setState(() {
          _down = false;
          _generation++;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _down
      // 只有一瞬間：和 App 底色一樣的空白。
      ? const ColoredBox(color: AppColors.paper)
      : ProviderScope(
          key: ValueKey(_generation),
          overrides: widget.overrides,
          child: const LittleStepsApp(),
        );
}
