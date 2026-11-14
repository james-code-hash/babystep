// 底線 1、3：程式裡不該有 streak／徽章／解鎖／完成率／「上次開啟」之類的概念。
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'guardrail_scan.dart';

/// 比對時先把識別字轉小寫、去掉底線。
const forbiddenFragments = [
  'streak',
  'leaderboard',
  'badge',
  'completionrate',
  'lastopen',
  'lastopened',
  'lastseen',
  'dayssince',
  'coins',
  'unlock',
];

String _squash(String s) => s.toLowerCase().replaceAll(RegExp(r'[_\-$]'), '');

List<String> forbiddenIn(Iterable<String> words) => [
      for (final w in words)
        for (final f in forbiddenFragments)
          if (_squash(w).contains(f)) '$w ($f)',
    ];

/// Dart：識別字＋（非中文的）字串內容；註解不掃。
List<String> scanDart(String source) {
  final strings = [
    for (final s in dartStringLexemes(source)) ...RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*').allMatches(s).map((m) => m[0]!),
  ];
  return forbiddenIn([...dartIdentifiers(source), ...strings]);
}

/// JS／TS：去掉註解後的所有 word。
List<String> scanJs(String source) =>
    forbiddenIn(RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*').allMatches(stripJsComments(source)).map((m) => m[0]!));

List<String> jsFilesUnder(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return const [];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => p.posix.joinAll(p.split(f.path)))
      .where((f) => RegExp(r'\.(ts|js|mjs|cjs)$').hasMatch(f))
      // 測試檔會故意放違規字串當反例。
      .where((f) => !RegExp(r'(\.test\.|\.spec\.|/__tests__/|/test/)').hasMatch(f))
      .toList()
    ..sort();
}

/// drift schema 的欄位／表名（getter 名轉 snake_case，就是 SQLite 的欄位名）。
List<String> schemaNames(String dbSource) {
  final unit = parseString(content: dbSource, throwIfDiagnostics: false).unit;
  final out = <String>[];
  for (final c in unit.declarations.whereType<ClassDeclaration>()) {
    final ext = c.extendsClause?.superclass.name.lexeme;
    if (ext != 'Table') continue;
    out.add(camelToSnake(c.namePart.typeName.lexeme));
    for (final m in c.body.members.whereType<MethodDeclaration>()) {
      if (m.isGetter) out.add(camelToSnake(m.name.lexeme));
    }
  }
  return out;
}

final forbiddenColumn = RegExp(
  r'(last_?open|opened_?at|last_?seen|last_?active|mood|feeling|streak|usage|duration|session|completion|score|points|coins|badge)',
);

void main() {
  group('self-test', () {
    test('dart identifiers and strings are caught; comments are not', () {
      const src = '// streak is forbidden; no badges, no unlock\n'
          '/* lastOpen */\n'
          'int streakCount = 0;\n'
          'final x = prefs.getString("last_open");\n'
          'void unlockHat() {}\n'
          'class LeaderBoard {}\n'
          'const coins = 1; int daysSinceLast = 0; double completionRate = 0; Widget b = Badge();\n';
      final v = scanDart(src);
      expect(v.length, 8, reason: v.join('\n'));
    });

    test('ordinary code passes', () {
      expect(scanDart("final plans = repo.plans(day); const s = 'dressUp';"), isEmpty);
    });

    test('js comments are stripped but strings are kept', () {
      const js = '// no streak here\nconst url = "https://x"; /* badge */ const lastOpen = 1;\n'
          "const s = 'unlock'; const t = `a // not a comment streak`;";
      final v = scanJs(js);
      expect(v.length, 3, reason: v.join('\n'));
    });

    test('schema scanner', () {
      const db = 'class Plans extends Table {\n  TextColumn get id => text()();\n'
          '  DateTimeColumn get lastOpenedAt => dateTime()();\n  TextColumn get mood => text()();\n}\n';
      final names = schemaNames(db);
      expect(names, containsAll(['plans', 'id', 'last_opened_at', 'mood']));
      expect(names.where(forbiddenColumn.hasMatch), hasLength(2));
    });
  });

  test('lib/ has no streak / badge / unlock / lastOpen identifiers', () {
    final v = <String>[
      for (final f in dartFilesUnder('lib'))
        for (final hit in scanDart(File(f).readAsStringSync())) '$f: $hit',
    ];
    expect(v, isEmpty, reason: v.join('\n'));
  });

  test('functions/src has no streak / badge / unlock / lastOpen identifiers', () {
    // functions/ 由另一部分建立；還沒有的時候這份清單是空的。
    final v = <String>[
      for (final f in jsFilesUnder('../functions/src'))
        for (final hit in scanJs(File(f).readAsStringSync())) '$f: $hit',
    ];
    expect(v, isEmpty, reason: v.join('\n'));
  });

  test('drift schema has no last_open / opened_at / mood / usage columns', () {
    final names = schemaNames(File('lib/data/db.dart').readAsStringSync());
    expect(names, containsAll(['plans', 'lessons', 'settings']));
    expect(names.where(forbiddenColumn.hasMatch), isEmpty);
  });

  test('generated drift code has no forbidden column names either', () {
    final g = File('lib/data/db.g.dart').readAsStringSync();
    final columnNames = [for (final m in RegExp(r"GeneratedColumn<\w+>\(\s*'(\w+)'").allMatches(g)) m.group(1)!];
    expect(columnNames, isNotEmpty);
    expect(columnNames.where(forbiddenColumn.hasMatch), isEmpty);
  });
}
