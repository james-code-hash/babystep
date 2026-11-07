import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../copy/parent_add_ons.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import '../../purchase/packs.dart';
import '../../purchase/purchase_sync.dart';
import '../../purchase/store.dart';
import 'parent_dialogs.dart';

/// 商店查到的價格。查不到（沒網路、桌面版）就是空的。
final _storeProductsProvider = FutureProvider.autoDispose<Map<String, StoreProduct>>((ref) async {
  final store = ref.watch(purchaseStoreProvider);
  if (!await store.isAvailable()) return const {};
  final products = await store.products({for (final p in AddOnPacks.all) p.productId});
  return {for (final p in products) p.id: p};
});

/// 家長端「加購插件包」（決策 L2）。整個購買流程只在這裡，家長 PIN 後面。
class AddOnsSectionBody extends ConsumerWidget {
  const AddOnsSectionBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owned = ref.watch(ownedPacksProvider).value ?? const <String>{};
    final products = ref.watch(_storeProductsProvider);
    final last = ref.watch(lastStoreEventProvider);
    final store = ref.read(purchaseStoreProvider);
    final text = Theme.of(context).textTheme;
    final storeDown = products.hasValue && products.value!.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final pack in AddOnPacks.all)
          Padding(
            key: ValueKey('add-on-${pack.id}'),
            padding: const EdgeInsets.only(bottom: AppSpace.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pt(pack.name), style: text.titleSmall),
                const SizedBox(height: AppSpace.xs),
                Text(pt(pack.description), style: text.bodyMedium?.copyWith(color: AppColors.inkSoft)),
                const SizedBox(height: AppSpace.s),
                if (owned.contains(pack.id))
                  Chip(
                    key: ValueKey('add-on-owned-${pack.id}'),
                    avatar: const Icon(Icons.check, size: 18),
                    label: Text(pt(ParentAddOnsCopy.owned)),
                  )
                else if (products.value?[pack.productId] case final product?)
                  FilledButton(
                    key: ValueKey('add-on-buy-${pack.id}'),
                    onPressed: () => store.buy(product.id),
                    child: Text(ParentAddOnsCopy.buy.fill(AgeTone.concise, {'price': product.price})),
                  ),
                if (last != null && last.productId == pack.productId && !owned.contains(pack.id))
                  switch (last.kind) {
                    StoreEventKind.pending => Text(pt(ParentAddOnsCopy.pending), style: text.bodySmall),
                    StoreEventKind.failed => Text(pt(ParentAddOnsCopy.failed), style: text.bodySmall),
                    StoreEventKind.delivered => const SizedBox.shrink(),
                  },
              ],
            ),
          ),
        if (storeDown) Text(pt(ParentAddOnsCopy.storeUnavailable), key: const ValueKey('add-on-store-down')),
        const SizedBox(height: AppSpace.s),
        Text(pt(ParentAddOnsCopy.restoreNote), style: text.bodySmall?.copyWith(color: AppColors.inkSoft)),
        const SizedBox(height: AppSpace.xs),
        OutlinedButton.icon(
          key: const ValueKey('add-on-restore'),
          onPressed: storeDown ? null : store.restore,
          icon: const Icon(Icons.restore),
          label: Text(pt(ParentAddOnsCopy.restore)),
        ),
      ],
    );
  }
}
