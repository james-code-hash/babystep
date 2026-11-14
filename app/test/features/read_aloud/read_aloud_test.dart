// 朗讀（I6）：孩子在設定裡打開，步步的對話泡泡旁邊才有喇叭；點了才唸，只用裝置內建語音。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/line.dart';
import 'package:little_steps/features/read_aloud/read_aloud.dart';
import 'package:little_steps/features/settings/settings_screen.dart';

import '../../helpers/test_app.dart';

class FakeSpeaker implements Speaker {
  FakeSpeaker({this.available = true});

  @override
  final bool available;
  final said = <String>[];
  var stops = 0;

  @override
  Future<void> speak(String text) async => said.add(text);

  @override
  Future<void> stop() async => stops++;
}

void main() {
  tearDown(() => PetName.current = null);

  testWidgets('off by default: no speaker buttons anywhere on Home', (tester) async {
    final env = TestEnv();
    await pumpApp(tester, env, extra: [speakerProvider.overrideWithValue(FakeSpeaker())]);
    expect(find.byKey(const ValueKey('home-bubble')), findsOneWidget);
    expect(find.byKey(const ValueKey('read-aloud')), findsNothing);
    await finishTest(tester, env);
  });

  testWidgets('the child turns it on in settings; tapping the speaker reads Bubu\'s line, by the chosen name',
      (tester) async {
    final speaker = FakeSpeaker();
    final env = TestEnv();
    await env.seed();
    await tester.runAsync(() => env.repo.setPetName('小花'));
    await pumpScreen(tester, env, const ChildSettingsScreen(), extra: [speakerProvider.overrideWithValue(speaker)]);
    await tester.tap(find.byKey(const ValueKey('read-aloud-switch')));
    await settleAll(tester);
    expect((await tester.runAsync(env.repo.settings))!.readAloud, isTrue);
    await finishTest(tester, env);

    final env2 = TestEnv();
    await env2.seed();
    await tester.runAsync(() async {
      await env2.repo.setReadAloud(true);
      await env2.repo.setPetName('小花');
    });
    await pumpApp(tester, env2, extra: [speakerProvider.overrideWithValue(speaker)]);
    final bubble = find.byKey(const ValueKey('home-bubble'));
    final line = tester.widget<Text>(find.descendant(of: bubble, matching: find.byType(Text))).data!;
    await tester.tap(find.descendant(of: bubble, matching: find.byKey(const ValueKey('read-aloud'))));
    await tester.pump();
    expect(speaker.said, [line], reason: 'reads exactly what is on screen, only when tapped');
    expect(speaker.stops, 0);

    // 離開首頁（換到別的畫面）就停下來，不會唸到別的畫面上。
    await tester.tap(find.byKey(const ValueKey('nav-settings')));
    await settleAll(tester);
    await tester.pumpAndSettle();
    expect(speaker.stops, greaterThan(0));
    await finishTest(tester, env2);
  });

  testWidgets('a device without a speech engine shows neither the switch nor the buttons', (tester) async {
    final env = TestEnv();
    await env.seed();
    await tester.runAsync(() => env.repo.setReadAloud(true));
    await pumpScreen(tester, env, const ChildSettingsScreen(),
        extra: [speakerProvider.overrideWithValue(FakeSpeaker(available: false))]);
    expect(find.byKey(const ValueKey('read-aloud-switch')), findsNothing);
    await finishTest(tester, env);

    final env2 = TestEnv();
    await env2.seed();
    await tester.runAsync(() => env2.repo.setReadAloud(true));
    await pumpApp(tester, env2, extra: [speakerProvider.overrideWithValue(FakeSpeaker(available: false))]);
    expect(find.byKey(const ValueKey('read-aloud')), findsNothing);
    await finishTest(tester, env2);
  });
}
