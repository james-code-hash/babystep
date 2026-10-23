// 底線 5、1、3：文案 lint（tool/copy_lint.dart）本身的測試。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/core/copy_rules.dart';
import 'package:little_steps/domain/models.dart';

import '../../tool/copy_lint_core.dart';
import '../helpers/test_app.dart';

void main() {
  late CopyRules rules;
  setUpAll(() => rules = loadCopyRules());

  List<LintIssue> lintCopy(String source) => lintSource('lib/copy/fixture.dart', source, rules);

  String wrap(String body) => "import 'line.dart';\n\n$body\n";

  test('lib/ is clean', () {
    final issues = lintDirectory(Directory.current, rules);
    expect(issues, isEmpty, reason: issues.join('\n'));
  });

  test('every location allowlist entry still exists in lib/ (keep the allowlist minimal)', () {
    // 不讓 allowlist 默默變大：這裡列出的檔案必須存在。
    for (final path in locationAllowlist.keys) {
      expect(File(path).existsSync(), isTrue, reason: 'allowlist names missing file $path');
    }
  });

  group('caught', () {
    final bad = <String, String>{
      'ability praise': "const a = Line('你好聰明！', '你很專心。');",
      'controlling': "const a = Line('加油！', '我們試試看。');",
      'streak': "const a = Line.same('連續三天了');",
      'remaining count': "const a = Line.same('還有 2 件');",
      'remaining count (interpolated)': r"String f(int n) => '還有 $n 件';",
      'guilt': "const a = Line('好久沒來了', '你來了。');",
      'guilt split across adjacent strings': "const a = Line.same('好久' '沒來了');",
      'childish word in concise': "const a = Line('嗨～', '小朋友，你好');",
      'childish word in Line.same': "const a = Line.same('小朋友，你好');",
      'childish word outside Line (strict)': "const a = '小朋友，你好';",
      'unmarked L2': "const a = Line('沒關係，下次再說', '好。');",
      'L2 in non-const Line': "final a = Line('嗨', '很好喔');",
      'L2 in LinePool': "const p = LinePool([Line('可惜呀', '這樣也行。')]);",
    };
    bad.forEach((name, body) {
      test(name, () {
        final issues = lintCopy(wrap(body));
        expect(issues.where((i) => i.kind == LintIssueKind.rule), isNotEmpty, reason: body);
      });
    });

    test('the report points at the right line and string', () {
      final issues = lintCopy(wrap("const ok = Line.same('嗨');\nconst a = Line('你好聰明！', '你很專心。');"));
      expect(issues, hasLength(1));
      expect(issues.single.line, 4);
      expect(issues.single.text, '你好聰明！');
      expect(issues.single.toString(), contains('lib/copy/fixture.dart:4'));
      expect(issues.single.toString(), contains('聰明'));
    });
  });

  group('allowed', () {
    test('childish word only in lively slot', () {
      expect(lintCopy(wrap("const a = Line('小朋友，你好', '你好。');")), isEmpty);
    });

    test('L2 with copy-allow on the same line', () {
      expect(lintCopy(wrap("const a = Line('沒關係～', '好。'); // copy-allow: 沒關係")), isEmpty);
    });

    test('L2 with copy-allow on the line above', () {
      expect(lintCopy(wrap("// copy-allow: 沒關係\nconst a = Line('沒關係～', '好。');")), isEmpty);
    });

    test('copy-allow two lines above does not count', () {
      expect(lintCopy(wrap("// copy-allow: 沒關係\n\nconst a = Line('沒關係～', '好。');")), isNotEmpty);
    });

    test('copy-allow for a different word does not count', () {
      expect(lintCopy(wrap("const a = Line('沒關係～', '好。'); // copy-allow: 很好")), isNotEmpty);
    });

    test('copy-allow with several words', () {
      expect(lintCopy(wrap("// copy-allow: 沒關係、很好\nconst a = Line('沒關係～很好', '好。');")), isEmpty);
    });

    test('placeholders and process wording', () {
      expect(
        lintCopy(wrap("const a = Line('你先做了{task}，步步看到了！', '你先做了{task}。');\n"
            "const b = Line.same('如果{cue}，我就{task}');")),
        isEmpty,
      );
    });

    test('comments are not linted', () {
      expect(lintCopy(wrap('// 你好聰明、加油、連續三天\n/* 好久沒來 */\nconst a = 1;')), isEmpty);
    });

    test('non-CJK strings are ignored', () {
      expect(lintSource('lib/features/x.dart', "const a = 'streak-free ascii';", rules), isEmpty);
    });
  });

  group('location', () {
    test('CJK string outside lib/copy is a violation', () {
      final issues = lintSource('lib/features/home/home_screen.dart', "final t = Text('今天想做什麼？');", rules);
      expect(issues.map((i) => i.kind), contains(LintIssueKind.location));
    });

    test('CJK inside a Line outside lib/copy is still a violation', () {
      final issues = lintSource('lib/features/x.dart', "const a = Line.same('你好');", rules);
      expect(issues.map((i) => i.kind), contains(LintIssueKind.location));
    });

    test('same string inside lib/copy is fine', () {
      expect(lintSource('lib/copy/home.dart', "const t = Line.same('今天想做什麼？');", rules), isEmpty);
    });

    test('allowlist is per file and per exact string', () {
      final allowed = locationAllowlist.entries.first;
      final path = allowed.key;
      final s = allowed.value.first;
      final literal = "'${s.replaceAll("'", r"\'")}'";
      expect(lintSource(path, 'final a = $literal;', rules).where((i) => i.kind == LintIssueKind.location), isEmpty);
      expect(lintSource('lib/features/other.dart', 'final a = $literal;', rules), isNotEmpty);
      expect(lintSource(path, "final a = '不在名單上的句子';", rules), isNotEmpty);
    });
  });

  test('tone routing: lively slot does not get concise rules', () {
    final issues = lintCopy(wrap("const a = Line('寶貝', '寶貝');"));
    expect(issues, hasLength(1));
    expect(issues.single.tone, AgeTone.concise);
  });
}
