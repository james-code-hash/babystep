import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/features/parent/parent_add_ons.dart';
import 'package:little_steps/purchase/packs.dart';
import 'package:little_steps/purchase/purchase_sync.dart';
import 'package:little_steps/purchase/store.dart';

import '../../helpers/test_app.dart';

/// 假商店：買或恢復都馬上送回「到貨」。
class FakeStore implements PurchaseStore {
  final _events = StreamController<StoreEvent>.broadcast();
  final bought = <String>[];
  var restored = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<StoreProduct>> products(Set<String> productIds) async =>
      [for (final id in productIds) StoreProduct(id: id, price: 'NT\$90')];

  @override
  Future<void> buy(String productId) async {
    bought.add(productId);
    _events.add(StoreEvent(StoreEventKind.delivered, productId));
  }

  @override
  Future<void> restore() async {
    restored++;
    for (final p in AddOnPacks.all) {
      _events.add(StoreEvent(StoreEventKind.delivered, p.productId));
    }
  }

  @override
  Stream<StoreEvent> get events => _events.stream;
}

Future<T> read<T>(WidgetTester tester, Future<T> Function() fn) async => (await tester.runAsync(fn)) as T;

const _body = PurchaseSync(child: Scaffold(body: SingleChildScrollView(child: AddOnsSectionBody())));

void main() {
  testWidgets('a parent buys a pack and it is recorded on the device', (tester) async {
    final env = TestEnv();
    final store = FakeStore();
    await pumpScreen(tester, env, _body, extra: [purchaseStoreProvider.overrideWithValue(store)]);
    await settleAll(tester);

    final buy = find.byKey(ValueKey('add-on-buy-${AddOnPacks.seasons.id}'));
    expect(buy, findsOneWidget);
    expect(find.textContaining('NT\$90'), findsOneWidget);

    await tester.tap(buy);
    await settleAll(tester);
    expect(store.bought, [AddOnPacks.seasons.productId]);
    expect(await read(tester, env.repo.ownedPacks), {AddOnPacks.seasons.id});
    expect(find.byKey(ValueKey('add-on-owned-${AddOnPacks.seasons.id}')), findsOneWidget);
    expect(buy, findsNothing);
    await finishTest(tester, env);
  });

  testWidgets('restore brings back packs bought before (after reinstall or delete-all)', (tester) async {
    final env = TestEnv();
    final store = FakeStore();
    await pumpScreen(tester, env, _body, extra: [purchaseStoreProvider.overrideWithValue(store)]);
    await settleAll(tester);
    await tester.tap(find.byKey(const ValueKey('add-on-restore')));
    await settleAll(tester);
    expect(store.restored, 1);
    expect(await read(tester, env.repo.ownedPacks), {for (final p in AddOnPacks.all) p.id});
    await finishTest(tester, env);
  });

  testWidgets('no store on this device: says so and offers nothing to buy', (tester) async {
    final env = TestEnv();
    await pumpScreen(tester, env, _body, extra: [purchaseStoreProvider.overrideWithValue(const NoStore())]);
    await settleAll(tester);
    expect(find.byKey(const ValueKey('add-on-store-down')), findsOneWidget);
    expect(find.byKey(ValueKey('add-on-buy-${AddOnPacks.seasons.id}')), findsNothing);
    final restore = tester.widget<ButtonStyleButton>(find.byKey(const ValueKey('add-on-restore')));
    expect(restore.onPressed, isNull);
    await finishTest(tester, env);
  });

  test('owning a pack is add-only and survives repeated deliveries', () async {
    final env = TestEnv();
    await env.repo.addOwnedPack('seasons');
    await env.repo.addOwnedPack('seasons');
    expect(await env.repo.ownedPacks(), {'seasons'});
    await env.dispose();
  });
}
