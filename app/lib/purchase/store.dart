import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:in_app_purchase/in_app_purchase.dart';

/// 商店上的一個商品，只留家長端要顯示的東西。
class StoreProduct {
  const StoreProduct({required this.id, required this.price});
  final String id;

  /// 商店給的、已經在地化的價格字串（例如「NT$90」）。
  final String price;
}

/// 一次購買／恢復的結果。
enum StoreEventKind { delivered, pending, failed }

class StoreEvent {
  const StoreEvent(this.kind, this.productId);
  final StoreEventKind kind;
  final String productId;
}

/// 平台商店的薄包裝（決策 L2）。只有家長端與 App 最上層的同步元件能用（有護欄測試）。
///
/// 用 Flutter 官方的 `in_app_purchase`（Apple StoreKit／Google Play Billing），不用第三方內購 SDK：
/// 不送任何孩子的資料，也沒有分析或追蹤（底線 8）。
abstract class PurchaseStore {
  Future<bool> isAvailable();
  Future<List<StoreProduct>> products(Set<String> productIds);
  Future<void> buy(String productId);
  Future<void> restore();

  /// 商店回來的事件。買成功與恢復都算 [StoreEventKind.delivered]。
  Stream<StoreEvent> get events;
}

/// 沒有商店的平台（桌面、測試）：一律「連不到商店」。
class NoStore implements PurchaseStore {
  const NoStore();
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<List<StoreProduct>> products(Set<String> productIds) async => const [];
  @override
  Future<void> buy(String productId) async {}
  @override
  Future<void> restore() async {}
  @override
  Stream<StoreEvent> get events => const Stream.empty();
}

/// iOS／Android 的真正商店。
class PlatformStore implements PurchaseStore {
  PlatformStore() : _iap = InAppPurchase.instance;

  final InAppPurchase _iap;
  final Map<String, ProductDetails> _details = {};

  static bool get supported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<List<StoreProduct>> products(Set<String> productIds) async {
    final resp = await _iap.queryProductDetails(productIds);
    for (final d in resp.productDetails) {
      _details[d.id] = d;
    }
    return [for (final d in resp.productDetails) StoreProduct(id: d.id, price: d.price)];
  }

  @override
  Future<void> buy(String productId) async {
    final d = _details[productId];
    if (d == null) return;
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: d));
  }

  @override
  Future<void> restore() => _iap.restorePurchases();

  @override
  Stream<StoreEvent> get events => _iap.purchaseStream.asyncExpand((list) async* {
        for (final p in list) {
          final kind = switch (p.status) {
            PurchaseStatus.purchased || PurchaseStatus.restored => StoreEventKind.delivered,
            PurchaseStatus.pending => StoreEventKind.pending,
            PurchaseStatus.error || PurchaseStatus.canceled => StoreEventKind.failed,
          };
          // 收據目前只在裝置上由商店處理；伺服器驗證等 Functions 部署之後再加（見決策 L2）。
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          yield StoreEvent(kind, p.productID);
        }
      });
}
