// E2E 情境測試共用的驅動器。
//
// 兩種跑法共用同一份情境（integration_test/scenarios/）：
// - 裝置／Linux 桌面（integration_test，`tool/e2e.sh`）：App 真正的啟動方式——磁碟上的資料庫檔、
//   背景 isolate、AppRoot 的「重新開始」都是真的。每個情境開始前把裝置上的資料庫刪掉重開
//   （等於剛安裝），結束後再清一次，不在裝置上留下測試資料。
// - flutter_tester（`flutter test`，CI 護欄）：同一份流程換成 in-memory 資料庫。只有「刪檔重開」
//   這一步在假時間裡跑不完，由 [E2EApp.onDevice] 分流。
//
// 所有操作都從畫面點：資料庫只用來「檢查」與「把時間往前推之前的準備」，不拿來代替孩子或家長的動作。
import 'dart:math';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/app_root.dart';
import 'package:little_steps/bootstrap.dart';
import 'package:little_steps/core/clock.dart';
import 'package:little_steps/data/database_store.dart';
import 'package:little_steps/data/db.dart';
import 'package:little_steps/data/repository.dart';
import 'package:little_steps/features/home/home_screen.dart';
import 'package:little_steps/features/parent/parent_providers.dart';
import 'package:little_steps/providers.dart';

/// 手機直放（dp）。
const phoneSize = Size(412, 915);

class E2EApp {
  E2EApp._(this.tester, this.clock, this._memoryDb);

  final WidgetTester tester;
  final FixedClock clock;
  final AppDatabase? _memoryDb;

  /// 家長按「匯出」時交給分享面板的內容（平台的分享面板在測試裡換成這個）。
  final List<String> shared = [];

  /// 在真的裝置／桌面上跑（磁碟資料庫、真的 async）；false = flutter_tester（in-memory、假時間）。
  bool get onDevice => _memoryDb == null;

  static bool get _live => WidgetsBinding.instance is LiveTestWidgetsFlutterBinding;

  /// 從「剛安裝」開始，打開 App 停在首頁。
  /// 剛安裝會先「初次見面」（D6）：[meet] 為 true 時照預設走過（不取名字），停在一般首頁。
  static Future<E2EApp> launch(WidgetTester tester,
      {required DateTime now, int seed = 7, Size size = phoneSize, bool meet = true}) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    AppDatabase? memory;
    if (_live) {
      // 裝置上：先把上一次留下的資料庫檔刪掉，等於剛安裝。
      final store = await DatabaseStore.onDevice();
      await store.reset();
      await store.current.close();
    } else {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      memory = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    }
    final app = E2EApp._(tester, FixedClock(now), memory);
    final overrides = (await tester.runAsync(() => bootstrapOverrides(database: memory)))!;
    await tester.pumpWidget(AppRoot(overrides: [
      ...overrides,
      clockProvider.overrideWithValue(app.clock),
      randomProvider.overrideWithValue(Random(seed)),
      parentShareProvider.overrideWithValue((text, subject) async => app.shared.add(text)),
    ]));
    await app.settle();
    expect(find.byType(HomeScreen), findsOneWidget);
    if (meet) await app.meet();
    return app;
  }

  /// 走過初次見面：打招呼 → 不取名字（或取 [name]）→ 開始。
  Future<void> meet({String? name}) async {
    expect(has('first-meeting'), isTrue, reason: 'a fresh install starts with the first meeting');
    await tap('hello-next');
    if (name == null) {
      await tap('pet-name-keep');
    } else {
      await enter('pet-name-field', name);
      await tap('pet-name-use');
    }
    await tap('hello-done');
    expect(has('first-meeting'), isFalse);
  }

  /// 目前這一代 App 的 ProviderContainer（刪除全部之後會換一個）。
  ProviderContainer get container => ProviderScope.containerOf(tester.element(find.byType(MaterialApp).first));

  Repository get repo => container.read(repositoryProvider);

  String get today => dayKeyOf(clock.now());

  /// 讀資料庫（只用來檢查結果）。
  Future<T> read<T>(Future<T> Function(Repository repo) fn) async => (await tester.runAsync(() => fn(repo))) as T;

  /// 交替跑真的 async（drift、磁碟）與 frame，直到畫面穩定。
  Future<void> settle({int rounds = 8}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: onDevice ? 20 : 5)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  /// 畫面最上層那個往下捲的清單。
  Finder get _scrollable => find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);

  Future<Finder> _reveal(String key) async {
    final f = find.byKey(ValueKey(key));
    if (f.evaluate().isEmpty && _scrollable.evaluate().isNotEmpty) {
      // lazy 清單（家長區、探索角⋯）：捲到它被建出來為止（先往下找，找不到再往上）。
      try {
        await tester.scrollUntilVisible(f, 250, scrollable: _scrollable.last, maxScrolls: 60);
      } on StateError {
        await tester.scrollUntilVisible(f, -250, scrollable: _scrollable.last, maxScrolls: 60);
      }
    }
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    return f;
  }

  bool has(String key) => find.byKey(ValueKey(key)).evaluate().isNotEmpty;

  Future<void> tap(String key) async {
    final f = await _reveal(key);
    await tester.tap(f);
    await settle();
  }

  Future<void> enter(String key, String text) async => enterInto(await _reveal(key), text);

  /// 在 [field] 打字，確認真的換成 [text]。
  Future<void> enterInto(Finder field, String text) async {
    final editable = find.descendant(of: field, matching: find.byType(EditableText), matchRoot: true);
    String current() => tester.widget<EditableText>(editable.first).controller.text;
    await tester.enterText(field, text);
    await settle();
    if (current() != text) {
      // 裝置上（live binding）同一個欄位第二次 enterText 有時送不到（測試用的輸入法連線沒換過來）。
      // 改從鍵盤輸入真正進來的那個入口送：EditableText 收到平台輸入法的更新，onChanged 照常觸發。
      tester.state<EditableTextState>(editable.first).updateEditingValue(
            TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)),
          );
      await settle();
    }
    expect(current(), text, reason: 'typing into $field');
  }

  Future<void> tapText(String text) async {
    await tester.tap(find.text(text).last);
    await settle();
  }

  /// 按 App 列的返回鍵（或系統返回）。
  Future<void> back() async {
    final button = find.byType(BackButton);
    if (button.evaluate().isNotEmpty) {
      await tester.tap(button.last);
    } else {
      await tester.pageBack();
    }
    await settle();
  }

  Future<void> pin(String pin) async {
    for (final d in pin.split('')) {
      await tester.tap(find.byKey(ValueKey('pin-key-$d')));
      await tester.pump();
    }
    await settle();
  }

  /// 首頁 → 家長區（第一次會設定 PIN：同一組輸入兩次）。
  Future<void> openParent({String pin = '2468', bool firstTime = false}) async {
    await tap('nav-parent');
    await this.pin(pin);
    if (firstTime) await this.pin(pin);
    expect(find.byKey(const ValueKey('parent-list')), findsOneWidget);
  }

  /// 家長區上鎖，回到孩子的首頁。
  Future<void> lockParent() async {
    await tap('parent-lock');
    expect(find.byType(HomeScreen), findsOneWidget);
  }

  /// App 進背景，時間來到 [at]，再回到前景（隔天打開 App 也是這樣）。
  Future<void> resumeAt(DateTime at) async {
    final binding = tester.binding;
    for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      binding.handleAppLifecycleStateChanged(s);
    }
    await tester.pump();
    clock.fixed = at;
    for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      binding.handleAppLifecycleStateChanged(s);
    }
    await settle();
  }

  /// 所有看得到的文字（檢查「沒有數字、沒有評價」這類底線用）。
  List<String> visibleTexts() => [
        for (final e in find.byType(Text).evaluate())
          (e.widget as Text).data ?? (e.widget as Text).textSpan?.toPlainText() ?? '',
        for (final e in find.byType(RichText).evaluate()) (e.widget as RichText).text.toPlainText(),
      ];

  /// 收尾：拆掉 App；裝置上把資料庫檔刪掉，不留下測試資料。
  Future<void> close() async {
    final store = onDevice ? container.read(databaseStoreProvider) : null;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (store != null) await store.reset();
      if (store != null) await store.current.close();
      await _memoryDb?.close();
    });
  }
}
