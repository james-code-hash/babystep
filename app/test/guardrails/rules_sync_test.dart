// 文案規則與危機字表只有一份來源（shared/），App 與 Cloud Function 的副本必須逐位元一致。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final name in ['copy_rules.json', 'crisis_patterns.json']) {
    group(name, () {
      final source = File('../shared/$name');
      final copies = {
        'app/assets/$name': File('assets/$name'),
        'functions/src/$name': File('../functions/src/$name'),
      };

      test('shared/$name exists', () {
        expect(source.existsSync(), isTrue, reason: 'missing source of truth shared/$name');
      });

      copies.forEach((label, file) {
        test('$label is byte-identical to shared/$name', () {
          expect(
            file.existsSync(),
            isTrue,
            reason: 'missing $label — copy shared/$name there (cp shared/$name $label). '
                'Every consumer must use the same rules (CLAUDE.md: 文案規則的唯一來源).',
          );
          expect(
            file.readAsBytesSync(),
            source.readAsBytesSync(),
            reason: '$label differs from shared/$name — re-copy it from shared/ (edit only shared/).',
          );
        });
      });
    });
  }
}
