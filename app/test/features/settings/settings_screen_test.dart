import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:little_steps/bubu/catalog.dart';
import 'package:little_steps/copy/settings.dart';
import 'package:little_steps/core/routes.dart';
import 'package:little_steps/core/theme.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/settings/dress_up_screen.dart';
import 'package:little_steps/features/settings/settings_routes.dart';
import 'package:little_steps/features/settings/settings_screen.dart';

import '../../helpers/test_app.dart';

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// 在 widget 測試的假時間裡，drift 的 watch().first 不會自己完成，要用真的 async 讀。
Future<T> read<T>(WidgetTester tester, Future<T> Function() fn) async => (await tester.runAsync(fn)) as T;

void main() {
  testWidgets('tone toggle persists and each option previews its own tone', (tester) async {
    final env = TestEnv();
    await pumpScreen(tester, env, const ChildSettingsScreen());

    expect(find.text(SettingsCopy.previewLively.lively), findsOneWidget);
    expect(find.text(SettingsCopy.previewConcise.concise), findsOneWidget);
    // 不標年齡。
    expect(find.textContaining('歲'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('tone-concise')));
    await tester.pumpAndSettle();
    expect((await read(tester, env.repo.settings)).tone, AgeTone.concise);
    expect(find.text(SettingsCopy.title.concise), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tone-lively')));
    await tester.pumpAndSettle();
    expect((await read(tester, env.repo.settings)).tone, AgeTone.lively);
    await unmount(tester);
    await tester.runAsync(env.dispose);
  });

  testWidgets('settings opens dress-up through the router', (tester) async {
    final env = TestEnv();
    await env.seed();
    final router = GoRouter(initialLocation: Routes.settings, routes: settingsRoutes);
    await tester.pumpWidget(ProviderScope(
      overrides: env.overrides,
      child: MaterialApp.router(theme: buildTheme(), routerConfig: router),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-dress-up')));
    await tester.pumpAndSettle();
    expect(find.byType(DressUpScreen), findsOneWidget);
    await unmount(tester);
    await tester.runAsync(env.dispose);
  });

  testWidgets('every catalog item is selectable and the choice persists', (tester) async {
    useTallSurface(tester);
    final env = TestEnv();
    await pumpScreen(tester, env, const DressUpScreen());

    final groups = <String, List<Accessory>>{
      'hat': BubuCatalog.hats,
      'neck': BubuCatalog.necks,
      'color': BubuCatalog.colors,
    };
    // 每一樣都在畫面上、都能按（沒有鎖、沒有條件）。
    groups.forEach((slot, items) {
      for (final a in items) {
        final chip = tester.widget<ChoiceChip>(find.byKey(ValueKey('$slot-${a.id}')));
        expect(chip.onSelected, isNotNull, reason: '$slot-${a.id}');
      }
    });

    for (final entry in groups.entries) {
      for (final a in entry.value.reversed) {
        await tester.tap(find.byKey(ValueKey('${entry.key}-${a.id}')));
        await tester.pumpAndSettle();
        final d = await read(tester, env.repo.dressUp);
        final picked = switch (entry.key) { 'hat' => d.hat, 'neck' => d.neck, _ => d.color };
        expect(picked, a.id);
        expect(tester.widget<ChoiceChip>(find.byKey(ValueKey('${entry.key}-${a.id}'))).selected, isTrue);
      }
    }

    final last = DressUp(
      hat: BubuCatalog.hats.first.id,
      neck: BubuCatalog.necks.first.id,
      color: BubuCatalog.colors.first.id,
    );
    expect(await read(tester, env.repo.dressUp), last);
    await unmount(tester);
    await tester.runAsync(env.dispose);
  });
}
