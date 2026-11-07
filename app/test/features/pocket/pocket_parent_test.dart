// 再看一次口袋（M1）在家長區：只有孩子分享的卡；匯出時照片跟著一起送出；刪除全部連照片一起刪。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/data/pocket_photos.dart';
import 'package:little_steps/domain/pocket.dart';
import 'package:little_steps/features/parent/parent_home.dart';
import 'package:little_steps/features/parent/parent_providers.dart';
import 'package:little_steps/features/parent/parent_screen.dart';

import '../../helpers/test_app.dart';
import '../parent/parent_screen_test.dart' show enterPin, tapKey, useTallSurface;

/// 照片放在暫存資料夾的假照片資料夾。
class _TempPhotos implements PocketPhotoStore {
  _TempPhotos(this.dir);
  final Directory dir;
  var deletedAll = false;

  @override
  Future<String?> take(PhotoSource source) async => null;

  @override
  File fileOf(String name) => File('${dir.path}/$name');

  @override
  Future<void> delete(String name) async => fileOf(name).deleteSync();

  @override
  Future<void> deleteAll() async => deletedAll = true;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('pocket_photos_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  testWidgets('the parent sees only shared cards; export sends the photos along with the file', (tester) async {
    useTallSurface(tester);
    final env = TestEnv();
    final photos = _TempPhotos(tmp);
    File('${tmp.path}/a.jpg').writeAsBytesSync([1, 2, 3]);
    final shares = <(String, List<String>)>[];
    await env.seed();
    await env.repo.setParentPin('2468');
    final shared = await env.repo.savePocketCard(
      const PocketCardDraft(subject: PocketSubject.math, prompt: '分數加法', knowNow: '分母要一樣'),
    );
    await env.repo.setPocketShared(shared.id, true);
    await env.repo.savePocketCard(const PocketCardDraft(prompt: '沒分享的題目', photo: 'a.jpg'));

    await pumpScreen(tester, env, const ParentGateScreen(), extra: [
      pocketPhotoStoreProvider.overrideWithValue(photos),
      parentShareProvider.overrideWithValue((text, subject, {files = const []}) async => shares.add((text, files))),
    ]);
    await enterPin(tester, '2468');
    expect(find.byType(ParentHome), findsOneWidget);
    await settleAll(tester);

    expect(find.byKey(ValueKey('shared-pocket-${shared.id}')), findsOneWidget);
    expect(find.text('分數加法'), findsOneWidget);
    expect(find.textContaining('分母要一樣'), findsOneWidget);
    expect(find.text('沒分享的題目'), findsNothing);

    await tapKey(tester, 'export');
    expect(shares, hasLength(1));
    expect(shares.single.$1, contains('沒分享的題目'), reason: 'the export is complete (rule 8)');
    expect(shares.single.$2, [File('${tmp.path}/a.jpg').path]);
    await finishTest(tester, env);
  });

  testWidgets('without any shared card the parent area has no pocket section at all', (tester) async {
    useTallSurface(tester);
    final env = TestEnv();
    await env.seed();
    await env.repo.setParentPin('2468');
    await env.repo.savePocketCard(const PocketCardDraft(prompt: '沒分享的題目'));
    await pumpScreen(tester, env, const ParentGateScreen());
    await enterPin(tester, '2468');
    await settleAll(tester);
    expect(find.textContaining('口袋'), findsNothing);
    await finishTest(tester, env);
  });

  test('delete all also clears the photo folder', () async {
    final env = TestEnv();
    await env.seed();
    final photos = _TempPhotos(tmp);
    final container = env.container(extra: [pocketPhotoStoreProvider.overrideWithValue(photos)]);
    await container.read(deleteAllDataProvider)();
    expect(photos.deletedAll, isTrue);
    container.dispose();
    await env.dispose();
  });
}
