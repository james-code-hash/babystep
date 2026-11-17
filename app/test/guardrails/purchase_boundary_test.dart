// 底線 8（決策 L2 改寫後）：購買只在家長端。孩子端沒有價格、沒有購買按鈕、沒有「請爸媽買」。
// 決策 L3：插件只賣家庭工具，永遠不賣步步的外觀、裝扮、驚喜盒內容。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'guardrail_scan.dart';

/// 可以碰商店（`in_app_purchase` 與 `lib/purchase/store.dart`、`purchase_sync.dart`）的地方。
bool mayUseStore(String path) =>
    path.startsWith('lib/purchase/') || path.startsWith('lib/features/parent/') || path == 'lib/app.dart';

/// 只有包裝檔可以直接 import 官方套件。
const storeWrapper = 'lib/purchase/store.dart';

/// 文案裡跟錢、購買有關的字（只在家長端的文案出現）。
final moneyWords = RegExp(r'(買|購|價格|價錢|付費|花錢|多少錢|NT\$|新台幣|台幣|元整)');

/// 家長端的文案檔。
bool isParentCopy(String path) => RegExp(r'^lib/copy/parent[^/]*\.dart$').hasMatch(path);

List<String> storeImportViolations(String path, String source) => [
      for (final t in directiveTargets(path, source))
        if (t.startsWith('package:in_app_purchase') && path != storeWrapper)
          '$path imports $t'
        else if ((t == 'lib/purchase/store.dart' || t == 'lib/purchase/purchase_sync.dart') && !mayUseStore(path))
          '$path imports $t',
    ];

List<String> moneyWordViolations(String path, String source) => [
      for (final s in dartStringLexemes(source))
        if (moneyWords.hasMatch(s)) '$path: $s',
    ];

/// 步步的外觀、裝扮、驚喜盒相關的程式（決策 L3：這些永遠不能跟購買扯上關係）。
bool isLooksCode(String path) =>
    path.startsWith('lib/bubu/') ||
    path == 'lib/features/settings/dress_up_screen.dart' ||
    path == 'lib/features/settings/shop_screen.dart' ||
    path.startsWith('lib/features/explore/');

/// 外觀相關的程式碼不得 import 購買模組，也不得讀「買了什麼」。
List<String> looksPurchaseViolations(String path, String source) {
  final code = stripDartComments(source);
  return [
    for (final t in directiveTargets(path, source))
      if (t.startsWith('lib/purchase/') || t.startsWith('package:in_app_purchase')) '$path imports $t',
    for (final id in const ['ownedPacksProvider', 'watchOwnedPacks', 'ownedPacks', 'addOwnedPack'])
      if (RegExp('\\b$id\\b').hasMatch(code)) '$path references $id',
  ];
}

/// 購買模組不得 import 外觀與裝扮（插件包裡不能放步步的東西）。
List<String> purchaseLooksViolations(String path, String source) => [
      for (final t in directiveTargets(path, source))
        if (t.startsWith('lib/bubu/') || t.startsWith('lib/copy/bubu') || t.startsWith('lib/copy/shop') || t.startsWith('lib/copy/surprise'))
          '$path imports $t',
    ];

void main() {
  group('self-test', () {
    test('store imports', () {
      const src = "import 'package:in_app_purchase/in_app_purchase.dart';\nimport '../../purchase/store.dart';";
      expect(storeImportViolations('lib/features/settings/shop_screen.dart', src), hasLength(2));
      expect(storeImportViolations('lib/features/parent/x.dart', src), hasLength(1));
      expect(storeImportViolations('lib/purchase/store.dart', "import 'package:in_app_purchase/in_app_purchase.dart';"),
          isEmpty);
    });

    test('looks and purchases stay apart', () {
      expect(looksPurchaseViolations('lib/bubu/look.dart', "import '../purchase/packs.dart';"), hasLength(1));
      expect(looksPurchaseViolations('lib/features/settings/shop_screen.dart', 'final x = ref.watch(ownedPacksProvider);'),
          hasLength(1));
      expect(purchaseLooksViolations('lib/purchase/packs.dart', "import '../bubu/shop.dart';"), hasLength(1));
      expect(isLooksCode('lib/features/explore/explore_screen.dart'), isTrue);
    });

    test('money words', () {
      expect(moneyWordViolations('lib/copy/shop.dart', "const a = '請爸媽幫你買';"), hasLength(1));
      expect(moneyWordViolations('lib/copy/shop.dart', "const a = '不評價'; // 買"), isEmpty);
    });
  });

  test('only the parent side and the app root touch the store', () {
    final violations = [
      for (final f in dartFilesUnder('lib')) ...storeImportViolations(f, File(f).readAsStringSync()),
    ];
    expect(violations, isEmpty);
  });

  test('child-facing strings never mention buying or prices', () {
    final files = [
      for (final f in dartFilesUnder('lib'))
        if (!isParentCopy(f) && !f.startsWith('lib/features/parent/') && !f.startsWith('lib/purchase/')) f,
    ];
    expect(files, isNotEmpty);
    final violations = [for (final f in files) ...moneyWordViolations(f, File(f).readAsStringSync())];
    expect(violations, isEmpty);
  });

  test('Bubu\'s looks, dress-up and the surprise box never depend on purchases (決策 L3)', () {
    final looks = [for (final f in dartFilesUnder('lib')) if (isLooksCode(f)) f];
    expect(looks, contains('lib/features/settings/shop_screen.dart'));
    final violations = [for (final f in looks) ...looksPurchaseViolations(f, File(f).readAsStringSync())];
    expect(violations, isEmpty);
  });

  test('add-on packs carry no Bubu looks (決策 L3)', () {
    final violations = [
      for (final f in dartFilesUnder('lib/purchase')) ...purchaseLooksViolations(f, File(f).readAsStringSync()),
    ];
    expect(violations, isEmpty);
  });
}
