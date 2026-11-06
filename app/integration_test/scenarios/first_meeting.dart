// 情境：初次見面與幫步步取名字（文案庫 §4.1，決策 D6）。
//
// 剛安裝 → 步步自我介紹 → 孩子取名字（規則擋下的字只說「唸不出來」）→ 首頁、筆記本、設定裡
// 步步說的話都用新名字 → 在「我的設定」換回步步。
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/copy/home.dart';
import 'package:little_steps/copy/line.dart';
import 'package:little_steps/copy/onboarding.dart';
import 'package:little_steps/copy/settings.dart';
import 'package:little_steps/domain/models.dart';

import '../e2e/harness.dart';

void firstMeetingScenarios() {
  testWidgets('first meeting: Bubu says hello, the child names it, the name shows wherever Bubu is mentioned',
      (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 7, 30), meet: false);
    addTearDown(() => PetName.current = null);

    // 剛安裝：先見面，不是直接進首頁的邀請。
    expect(app.has('first-meeting'), isTrue);
    expect(app.has('home-plan'), isFalse);
    await app.tap('hello-next');
    expect(find.text(OnboardingCopy.nameAsk.fill(AgeTone.lively, {'original': '步步'})), findsOneWidget);

    // 規則擋下的字：只說唸不出來，名字不存。
    await app.enter('pet-name-field', '天才');
    await app.tap('pet-name-use');
    expect(app.has('pet-name-retry'), isTrue);
    expect((await app.read((r) => r.settings())).petName, isNull);

    await app.enter('pet-name-field', '小花');
    await app.tap('pet-name-use');
    expect(find.text('好！以後我就叫小花了。'), findsOneWidget);
    await app.tap('hello-done');

    // 首頁：一般的邀請；導覽上的「步步的筆記本」變成「小花的筆記本」。
    expect(app.has('first-meeting'), isFalse);
    expect(app.has('home-plan'), isTrue);
    expect(find.textContaining('小花的筆記本'), findsWidgets);
    expect(find.textContaining('步步的筆記本'), findsNothing);
    expect((await app.read((r) => r.settings())).onboarded, isTrue);

    // 設定：入口寫「幫小花取名字」；換回步步。
    await app.tap('nav-settings');
    expect(find.text('幫小花取名字'), findsOneWidget);
    await app.tap('open-pet-name');
    expect(find.text(OnboardingCopy.nameBack.fill(AgeTone.lively, {'original': '步步'})), findsOneWidget);
    await app.tap('pet-name-keep');
    expect((await app.read((r) => r.settings())).petName, isNull);
    expect(find.text(SettingsCopy.nameEntry.lively), findsOneWidget, reason: 'back to 步步');
    await app.back();
    expect(find.textContaining(HomeCopy.notebook.lively), findsWidgets);
  });

  testWidgets('first meeting: skipping the name keeps 步步, and the meeting does not come back', (tester) async {
    final app = await E2EApp.launch(tester, now: DateTime(2026, 11, 4, 19, 30), meet: false);
    await app.meet();
    expect((await app.read((r) => r.settings())).petName, isNull);
    expect(find.textContaining('步步的筆記本'), findsWidgets);

    // 隔天再打開：直接是首頁。
    await app.resumeAt(DateTime(2026, 11, 5, 7, 30));
    expect(app.has('first-meeting'), isFalse);
    expect(app.has('home-plan'), isTrue);
  });
}
