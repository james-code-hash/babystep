import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/domain/models.dart';

import '../../helpers/test_app.dart';

/// 小路、家長區、孩子設定的文案都要過同一套規則（整合後 tool/copy_lint.dart 也會掃）。
final _literal = RegExp("'([^'\\\\]|\\\\.)*'");
final _cjk = RegExp(r'[一-鿿]');

Iterable<(int, String)> cjkLiterals(String path) sync* {
  for (final (i, line) in File(path).readAsLinesSync().indexed) {
    final code = line.trimLeft().startsWith('//') ? '' : line.split(' // ').first;
    for (final m in _literal.allMatches(code)) {
      if (_cjk.hasMatch(m.group(0)!)) yield (i + 1, m.group(0)!);
    }
  }
}

void main() {
  final rules = loadCopyRules();

  test('every sentence in copy/path, copy/parent, copy/settings passes the copy rules (strict)', () {
    final problems = <String>[];
    var seen = 0;
    for (final f in ['lib/copy/path.dart', 'lib/copy/parent.dart', 'lib/copy/settings.dart']) {
      for (final (n, s) in cjkLiterals(f)) {
        seen++;
        final v = rules.check(s, tone: AgeTone.concise);
        if (v.isNotEmpty) problems.add('$f:$n $s $v');
      }
    }
    expect(seen, greaterThan(50), reason: 'scanner must actually see the copy');
    expect(problems, isEmpty);
  });

  test('feature screens keep their Chinese sentences in lib/copy/', () {
    final found = <String>[];
    for (final dir in ['lib/features/path', 'lib/features/parent', 'lib/features/settings']) {
      for (final f in Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        for (final (n, s) in cjkLiterals(f.path)) {
          found.add('${f.path}:$n $s');
        }
      }
    }
    expect(found, isEmpty);
  });
}
