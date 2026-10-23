// 底線 2：步步的外觀與問候只吃（裝扮、時間、語氣、亂數），永遠不取決於孩子做了什麼。
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'guardrail_scan.dart';

/// 識別字拆成單字後，不得出現這些（`todayPlansProvider` → plans）。
const forbiddenWords = {
  'plan', 'plans', 'planned', 'outcome', 'outcomes', 'lesson', 'lessons', 'repository', 'repo',
  'reflection', 'review', 'reviewed', 'record', 'records', 'completion',
};

/// 完整比對的型別名。
const forbiddenTypes = {'Outcome', 'Plan', 'PlanDraft', 'Lesson', 'LessonResult', 'DayRecord', 'Repository', 'PlannedDay'};

List<String> dependenceViolations(String source) {
  final out = <String>[];
  for (final id in dartIdentifiers(source).toSet()) {
    if (forbiddenTypes.contains(id)) {
      out.add(id);
      continue;
    }
    final hit = identifierWords(id).where(forbiddenWords.contains);
    if (hit.isNotEmpty) out.add('$id (${hit.join(',')})');
  }
  return out;
}

class FunctionSig {
  FunctionSig(this.name, this.paramTypes, this.location);
  final String name;
  final List<String> paramTypes;
  final String location;

  @override
  String toString() => '$location $name(${paramTypes.join(', ')})';
}

/// 找出所有叫 [names] 的函式／方法（頂層、static、instance 都算），列出參數型別。
List<FunctionSig> findFunctions(String path, String source, Set<String> names) {
  final unit = parseString(content: source, path: path, throwIfDiagnostics: false).unit;
  final v = _FnVisitor(path, names);
  unit.accept(v);
  return v.found;
}

class _FnVisitor extends RecursiveAstVisitor<void> {
  _FnVisitor(this.path, this.names);
  final String path;
  final Set<String> names;
  final found = <FunctionSig>[];

  List<String> _types(FormalParameterList? list) => [
        for (final p in list?.parameters ?? const <FormalParameter>[])
          p.functionTypedSuffix != null ? p.toSource() : (p.type?.toSource() ?? 'dynamic'),
      ];

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (names.contains(node.name.lexeme)) {
      found.add(FunctionSig(node.name.lexeme, _types(node.functionExpression.parameters), path));
    }
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (names.contains(node.name.lexeme)) {
      found.add(FunctionSig(node.name.lexeme, _types(node.parameters), path));
    }
    super.visitMethodDeclaration(node);
  }
}

List<FunctionSig> findInBubu(Set<String> names) => [
      for (final f in dartFilesUnder('lib/bubu')) ...findFunctions(f, File(f).readAsStringSync(), names),
    ];

void main() {
  group('self-test', () {
    test('references to child activity are caught', () {
      const src = 'import "x.dart";\n// Plan and Outcome in a comment are fine\n'
          'Color c(Outcome o) => o == Outcome.done ? red : blue;\n'
          'final p = ref.watch(todayPlansProvider); Repository? r; List<Lesson> l = []; DayRecord? d;\n'
          'bool get hasPlanToday => false; final outcome = 1;';
      final v = dependenceViolations(src);
      expect(v.length, greaterThanOrEqualTo(7), reason: v.join('\n'));
      expect(v.join(' '), allOf(contains('Outcome'), contains('todayPlansProvider'), contains('hasPlanToday')));
    });

    test('dress-up / time / random code passes', () {
      const src = 'BubuLook look(DressUp d, DateTime now) => BubuLook(d.hat, now.month);\n'
          'String greeting(AgeTone tone, DateTime now, Random random) => "";';
      expect(dependenceViolations(src), isEmpty);
    });

    test('signature finder', () {
      const src = 'BubuLook look(DressUp d, DateTime now) => x;\n'
          'class A { static String greeting(AgeTone t, DateTime n, Random r, {Plan? p}) => ""; }';
      final sigs = findFunctions('lib/bubu/x.dart', src, {'look', 'greeting'});
      expect(sigs.map((s) => s.paramTypes.join(',')), ['DressUp,DateTime', 'AgeTone,DateTime,Random,Plan?']);
    });
  });

  test('lib/bubu/** never references plans, outcomes, lessons, records or the repository', () {
    final files = dartFilesUnder('lib/bubu');
    expect(files, isNotEmpty);
    final v = <String>[
      for (final f in files)
        for (final hit in dependenceViolations(File(f).readAsStringSync())) '$f: $hit',
    ];
    expect(v, isEmpty, reason: v.join('\n'));
  });

  test('greeting(AgeTone, DateTime, Random) is the only greeting signature', () {
    final sigs = findInBubu({'greeting'});
    expect(sigs, isNotEmpty, reason: 'lib/bubu/ must define greeting(AgeTone, DateTime, Random)');
    for (final s in sigs) {
      expect(s.paramTypes, ['AgeTone', 'DateTime', 'Random'], reason: '$s');
    }
  });

  test('look(DressUp, DateTime) exists and is the only look signature', () {
    // build-b 會在 lib/bubu/ 加上 look(DressUp, DateTime)（見 bubu_view.dart 的 TODO）。
    final sigs = findInBubu({'look'});
    expect(sigs, isNotEmpty,
        reason: 'lib/bubu/ must define look(DressUp, DateTime): Bubu\'s appearance is a pure function of '
            'dress-up and time (底線 2). Missing until build-b lands.');
    for (final s in sigs) {
      expect(s.paramTypes, ['DressUp', 'DateTime'], reason: '$s');
    }
  });
}
