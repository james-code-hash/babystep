// 底線 8（決策 L2 改寫後）：購買只在家長端。孩子端沒有價格、沒有購買按鈕、沒有「請爸媽買」。
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

void main() {
  group('self-test', () {
    test('store imports', () {
      const src = "import 'package:in_app_purchase/in_app_purchase.dart';\nimport '../../purchase/store.dart';";
      expect(storeImportViolations('lib/features/settings/shop_screen.dart', src), hasLength(2));
      expect(storeImportViolations('lib/features/parent/x.dart', src), hasLength(1));
      expect(storeImportViolations('lib/purchase/store.dart', "import 'package:in_app_purchase/in_app_purchase.dart';"),
          isEmpty);
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
}
