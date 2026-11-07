// 再看一次口袋（M1）的資料：存、改、收好、分享、刪、匯出、刪除全部。
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:little_steps/data/pocket_photos.dart';
import 'package:little_steps/domain/pocket.dart';

import '../helpers/test_app.dart';

void main() {
  late TestEnv env;
  setUp(() async {
    env = TestEnv();
    await env.seed();
  });
  tearDown(() => env.dispose());

  test('a new card keeps what the child wrote; blanks are stored as nothing', () async {
    final c = await env.repo.savePocketCard(const PocketCardDraft(
      subject: PocketSubject.math,
      prompt: '  7×8  ',
      thought: '   ',
      stuck: PocketStuck.tooFast,
    ));
    expect(c.prompt, '7×8');
    expect(c.thought, isNull);
    expect(c.stuck, PocketStuck.tooFast);
    expect(c.filedAway, isFalse);
    expect(c.sharedWithParent, isFalse, reason: 'sharing is the child\'s own action (rule 7)');
  });

  test('editing a card does not touch filed-away or shared', () async {
    final c = await env.repo.savePocketCard(const PocketCardDraft(prompt: '7×8'));
    await env.repo.setPocketFiledAway(c.id, true);
    await env.repo.setPocketShared(c.id, true);
    final edited = await env.repo.savePocketCard(PocketCardDraft(id: c.id, prompt: '7×8', knowNow: '是 56'));
    expect(edited.knowNow, '是 56');
    expect(edited.filedAway, isTrue);
    expect(edited.sharedWithParent, isTrue);
    expect(await env.repo.pocketCards(), hasLength(1));
  });

  test('deleting a group keeps its cards, just without a group', () async {
    final g = await env.repo.addPocketGroup('11/7 數學小考');
    final c = await env.repo.savePocketCard(PocketCardDraft(groupId: g.id, prompt: '7×8'));
    await env.repo.deletePocketGroup(g.id);
    final again = await env.repo.pocketCard(c.id);
    expect(again, isNotNull);
    expect(again!.groupId, isNull);
  });

  test('deleting a card returns its photo name so the photo can go too', () async {
    final c = await env.repo.savePocketCard(const PocketCardDraft(prompt: '7×8', photo: 'abc.jpg'));
    expect(await env.repo.pocketPhotoNames(), {'abc.jpg'});
    expect(await env.repo.deletePocketCard(c.id), 'abc.jpg');
    expect(await env.repo.pocketCards(), isEmpty);
    expect(await env.repo.pocketPhotoNames(), isEmpty);
  });

  test('the export carries every card and group (rule 8)', () async {
    final g = await env.repo.addPocketGroup('小考');
    final c = await env.repo.savePocketCard(PocketCardDraft(groupId: g.id, prompt: '7×8', photo: 'abc.jpg'));
    await env.repo.setPocketFiledAway(c.id, true);
    final j = jsonDecode(await env.repo.exportJson()) as Map<String, Object?>;
    expect((j['pocketGroups'] as List).single, containsPair('name', '小考'));
    final card = (j['pocketCards'] as List).single as Map<String, Object?>;
    expect(card, containsPair('prompt', '7×8'));
    expect(card, containsPair('photo', 'abc.jpg'));
    expect(card, containsPair('filedAway', true));
  });

  test('delete all removes every card and group', () async {
    await env.repo.addPocketGroup('小考');
    await env.repo.savePocketCard(const PocketCardDraft(prompt: '7×8'));
    await env.repo.setPocketHidden(true);
    await env.repo.deleteAll();
    expect(await env.repo.pocketCards(), isEmpty);
    expect((await env.repo.settings()).pocketHidden, isFalse);
  });

  test('the child\'s words for the safety check include every free-text field', () {
    const d = PocketCardDraft(prompt: 'a', thought: 'b', knowNow: 'c', ifCue: 'd', thenAction: 'e');
    expect(d.childWords.split('\n'), ['a', 'b', 'c', 'd', 'e']);
  });

  group('photos', () {
    test('cleaning drops EXIF (location, time, device) and shrinks the long side', () {
      final big = img.Image(width: 3200, height: 1600);
      big.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(25, 1);
      big.exif.imageIfd['Model'] = img.IfdValueAscii('Phone');
      final withExif = img.encodeJpg(big);
      expect(img.decodeJpgExif(withExif)?.isEmpty, isFalse, reason: 'the fixture really has EXIF');

      final clean = cleanPhotoBytes(Uint8List.fromList(withExif), maxSide: 800)!;
      final exif = img.decodeJpgExif(clean);
      expect(exif == null || exif.isEmpty, isTrue);
      final out = img.decodeJpg(clean)!;
      expect(out.width, 800);
      expect(out.height, 400);
    });

    test('a file that is not an image is refused', () {
      expect(cleanPhotoBytes(Uint8List.fromList(utf8.encode('not an image'))), isNull);
    });
  });
}
