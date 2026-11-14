// 底線 9：App 本機的危機偵測與 Cloud Function 對同一份樣本判定一致（docs/decisions.md F3、F4）。
// 離線或 LLM 關閉時，App 端是唯一的一道檢查，所以兩邊不能漂移。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/safety/crisis_detector.dart';

import '../helpers/test_app.dart';

void main() {
  late CrisisDetector detector;
  setUpAll(() => detector = loadCrisisDetector());

  final fixture =
      jsonDecode(File('../functions/test/crisis_samples.json').readAsStringSync()) as Map<String, Object?>;
  final samples = (fixture['samples'] as List).cast<Map<String, Object?>>();

  test('fixture is there and covers zhuyin and simplified spellings', () {
    expect(samples.length, greaterThan(30));
    final texts = samples.map((s) => s['text'] as String).toList();
    expect(texts, containsAll(['我想ㄙˇ', '我想自杀', '没人爱我']));
  });

  for (final s in samples) {
    final text = s['text'] as String;
    final expected = s['category'] == null ? null : CrisisCategory.values.byName(s['category'] as String);
    test('「$text」→ ${expected?.name}', () => expect(detector.detect(text), expected));
  }
}
