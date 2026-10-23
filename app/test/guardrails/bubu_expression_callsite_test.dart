// 底線 2：步步的表情是在畫面（lib/features、lib/safety）裡決定的，那裡拿得到計畫、回顧、筆記。
// 這條測試掃每一個 `expression:` 參數（BubuView 與包著它的 _StepLayout／_SideBubu 等），
// 不准用到跟孩子做了什麼有關的識別字；要依時段或「回答了沒」變化，只能呼叫 lib/bubu 的核可函式。
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:flutter_test/flutter_test.dart';

import 'guardrail_scan.dart';

/// 識別字拆成單字後不得出現的字（`todayPlansProvider` → plans、`record?.ended` → record, ended）。
const forbiddenExpressionWords = {
  'plan', 'plans', 'planned', 'outcome', 'outcomes', 'lesson', 'lessons', 'record', 'records', 'ended',
  'end', 'mood', 'moods', 'done', 'partly', 'review', 'reviewed', 'reflection', 'result', 'completion',
  'cue', 'why', 'task', 'tasks', 'saved', 'shared', 'repo', 'repository',
};

/// lib/bubu 裡核可的表情函式，與它唯一允許的參數型別（只吃時間或一個 bool，看不到孩子的內容）。
const approvedHelpers = <String, List<String>>{
  'restingExpression': ['DateTime'],
  'listeningExpression': ['bool'],
};

/// 真的需要時才放：'檔案路徑' → 理由（同時寫進 docs/decisions.md）。目前是空的。
const allowlist = <String, String>{};

class ExpressionArg {
  ExpressionArg(this.path, this.line, this.callee, this.source, this.violations);
  final String path;
  final int line;
  final String callee;
  final String source;
  final List<String> violations;

  @override
  String toString() => '$path:$line $callee(expression: $source) → ${violations.join(', ')}';
}

/// 找出 [source] 裡所有呼叫的 `expression:` 具名參數，列出它用到的禁用識別字。
/// 核可函式的呼叫整段略過（它的參數型別另外檢查）。
List<ExpressionArg> scanExpressionArgs(String path, String source) {
  final result = parseString(content: source, path: path, throwIfDiagnostics: false);
  final v = _ArgVisitor(path, result.lineInfo);
  result.unit.accept(v);
  return v.found;
}

class _ArgVisitor extends RecursiveAstVisitor<void> {
  _ArgVisitor(this.path, this.lines);
  final String path;
  final LineInfo lines;
  final found = <ExpressionArg>[];

  void _check(String callee, ArgumentList args) {
    for (final a in args.arguments) {
      if (a is! NamedArgument || a.name.lexeme != 'expression') continue;
      final ids = _IdCollector();
      a.argumentExpression.accept(ids);
      final bad = <String>[
        for (final id in ids.names)
          if (identifierWords(id).any(forbiddenExpressionWords.contains)) id,
      ];
      found.add(ExpressionArg(path, lines.getLocation(a.offset).lineNumber, callee, a.argumentExpression.toSource(), bad));
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _check(node.methodName.name, node.argumentList);
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _check(node.constructorName.type.name.lexeme, node.argumentList);
    super.visitInstanceCreationExpression(node);
  }
}

class _IdCollector extends RecursiveAstVisitor<void> {
  final names = <String>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && approvedHelpers.containsKey(node.methodName.name)) return;
    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    names.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}

List<String> violationsIn(String path, String source) => [
      for (final a in scanExpressionArgs(path, source))
        if (a.violations.isNotEmpty && !allowlist.containsKey(path)) '$a',
    ];

/// lib/bubu 裡核可函式的參數型別。
Map<String, List<String>> helperSignatures(String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  return {
    for (final d in unit.declarations.whereType<FunctionDeclaration>())
      if (approvedHelpers.containsKey(d.name.lexeme))
        d.name.lexeme: [
          for (final p in d.functionExpression.parameters?.parameters ?? const <FormalParameter>[])
            p.functionTypedSuffix != null ? p.toSource() : (p.type?.toSource() ?? 'dynamic'),
        ],
  };
}

List<String> _scanDirs() => [...dartFilesUnder('lib/features'), ...dartFilesUnder('lib/safety')];

void main() {
  group('self-test on fixture source', () {
    test('expressions picked from child activity are caught', () {
      const src = '''
Widget a(List<Plan> plans) => BubuView(expression: plans.isEmpty ? BubuExpression.calm : BubuExpression.happy);
Widget b(DayRecord? record) => BubuView(expression: record?.ended ?? false ? BubuExpression.relaxed : BubuExpression.calm);
Widget c(Outcome o) => _SideBubu(expression: o == Outcome.done ? BubuExpression.happy : BubuExpression.curious, wide: true);
Widget d(_Mood? mood) => _StepLayout(expression: mood == null ? BubuExpression.curious : BubuExpression.caring);
Widget e(bool hasLesson) => const BubuView(expression: hasLesson ? BubuExpression.happy : BubuExpression.calm);
Widget f(List<Plan> p) => BubuView(expression: listeningExpression(answered: true) == x ? pick(todayPlansProvider) : BubuExpression.calm);
''';
      final v = violationsIn('lib/features/x.dart', src);
      expect(v, hasLength(6), reason: v.join('\n'));
      expect(v.join('\n'), allOf(contains('plans'), contains('record'), contains('Outcome'), contains('mood'),
          contains('hasLesson'), contains('todayPlansProvider')));
    });

    test('const faces, approved helpers and conversation stage flags pass', () {
      const src = '''
Widget a() => const BubuView(expression: BubuExpression.curious, size: 64);
Widget b(DateTime now) => BubuView(expression: restingExpression(now));
Widget c(bool peekAsking, Clock clock) =>
    BubuView(expression: peekAsking ? BubuExpression.curious : restingExpression(clock.now()));
Widget d(_Mood? mood) => _StepLayout(expression: listeningExpression(answered: mood != null));
class W { final BubuExpression expression; Widget build() => BubuView(expression: expression, size: 1); }
Widget e() => BubuView(size: 56);
''';
      expect(violationsIn('lib/features/x.dart', src), isEmpty);
      expect(scanExpressionArgs('lib/features/x.dart', src), hasLength(5));
    });

    test('helper signature reader', () {
      const src = 'BubuExpression restingExpression(DateTime now) => x;\n'
          'BubuExpression listeningExpression({required bool answered}) => x;\n'
          'BubuExpression other(Plan p) => x;';
      expect(helperSignatures(src), {
        'restingExpression': ['DateTime'],
        'listeningExpression': ['bool'],
      });
    });
  });

  test('every expression: argument in lib/features and lib/safety is independent of child activity', () {
    final files = _scanDirs();
    expect(files, isNotEmpty);
    final args = [for (final f in files) ...scanExpressionArgs(f, File(f).readAsStringSync())];
    // 確定真的掃到了：首頁、計畫、回顧、安全回應都有步步。
    expect(args.map((a) => a.path).toSet(),
        containsAll(['lib/features/home/home_screen.dart', 'lib/features/plan/plan_steps.dart',
          'lib/features/review/review_screen.dart', 'lib/safety/safety_response.dart']));
    final v = [for (final f in files) ...violationsIn(f, File(f).readAsStringSync())];
    expect(v, isEmpty, reason: v.join('\n'));
  });

  test('approved helpers live in lib/bubu and only take time or a bool', () {
    final sigs = <String, List<String>>{
      for (final f in dartFilesUnder('lib/bubu')) ...helperSignatures(File(f).readAsStringSync()),
    };
    expect(sigs, approvedHelpers);
  });

  test('allowlist entries point at real files', () {
    for (final path in allowlist.keys) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
