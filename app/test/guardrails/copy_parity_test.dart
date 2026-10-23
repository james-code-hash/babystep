// 底線 5、3、2：App 的 CopyRules 與 Cloud Function 的 rules.ts 對同一份樣本判定一致（docs/decisions.md F2）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/core/copy_rules.dart';
import 'package:little_steps/domain/models.dart';

import '../helpers/test_app.dart';

void main() {
  late CopyRules rules;
  setUpAll(() => rules = loadCopyRules());

  final fixture =
      jsonDecode(File('../functions/test/parity_samples.json').readAsStringSync()) as Map<String, Object?>;
  final samples = (fixture['samples'] as List).cast<Map<String, Object?>>();

  test('fixture is there and big enough', () => expect(samples.length, greaterThan(60)));

  for (final s in samples) {
    final text = s['text'] as String;
    final tone = AgeTone.values.byName(s['tone'] as String);
    final ok = s['ok'] as bool;
    test('「$text」(${tone.name}) → $ok', () {
      expect(rules.passesGenerated(text, tone), ok, reason: rules.check(text, tone: tone, checkLength: true).join(' '));
    });
  }
}
