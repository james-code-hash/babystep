import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'packs.dart';
import 'store.dart';

/// 這台裝置用的商店。測試與桌面版用 [NoStore]。
final purchaseStoreProvider = Provider<PurchaseStore>((ref) => PlatformStore.supported ? PlatformStore() : const NoStore());

/// 商店最近一次的事件，給家長端顯示「等待確認」「沒有完成」。
final lastStoreEventProvider = NotifierProvider<LastStoreEvent, StoreEvent?>(LastStoreEvent.new);

class LastStoreEvent extends Notifier<StoreEvent?> {
  @override
  StoreEvent? build() => null;

  void report(StoreEvent e) => state = e;
}

/// 掛在 App 最上層，從頭到尾聽商店的事件（買到一半關掉 App，下次開啟時商店會再送一次）。
/// 買到或恢復了就記到本機；不通知孩子、不跳任何畫面。
class PurchaseSync extends ConsumerStatefulWidget {
  const PurchaseSync({super.key, required this.child, this.packs = AddOnPacks.all});
  final Widget child;

  /// 認得的包（測試可以換）。
  final List<AddOnPack> packs;

  @override
  ConsumerState<PurchaseSync> createState() => _PurchaseSyncState();
}

class _PurchaseSyncState extends ConsumerState<PurchaseSync> {
  StreamSubscription<StoreEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(purchaseStoreProvider).events.listen(_onEvent);
  }

  Future<void> _onEvent(StoreEvent e) async {
    final pack = AddOnPacks.byProductId(e.productId, widget.packs);
    if (e.kind == StoreEventKind.delivered && pack != null) {
      await ref.read(repositoryProvider).addOwnedPack(pack.id);
    }
    if (mounted) ref.read(lastStoreEventProvider.notifier).report(e);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
