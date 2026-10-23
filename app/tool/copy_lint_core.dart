/// 文案 lint 的核心邏輯（`tool/copy_lint.dart` 與 `test/guardrails/copy_lint_test.dart` 共用）。
///
/// 用 package:analyzer 解析 Dart 原始碼，找出所有含 CJK 字的字串字面值，
/// 用 App 執行期同一份 [CopyRules] 檢查。另外：`lib/copy/` 以外出現 CJK 字串本身就是違規
/// （使用者看得到的句子只能放在 `lib/copy/`），除了 [locationAllowlist] 明列的少數例外。
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:little_steps/core/copy_rules.dart';
import 'package:little_steps/domain/models.dart';

/// 中日韓漢字（含擴充 A）與注音。
final RegExp cjkPattern = RegExp(r'[㐀-䶿一-鿿豈-﫿㄀-ㄯ]');

bool containsCjk(String s) => cjkPattern.hasMatch(s);

/// `// copy-allow: 沒關係, 很好`（逗號、頓號或空白分隔）。
final RegExp _allowComment = RegExp(r'//\s*copy-allow:\s*(.+)$');

/// `lib/copy/` 以外允許出現 CJK 字串的地方：`{相對於 app/ 的路徑: {完整字串}}`。
///
/// 每一筆都必須是「不是給孩子看的句子」或「Foundation 尚未搬進 copy/ 的字串（已列在 neededChanges）」。
/// 要讓它越小越好；新增前先想能不能搬進 `lib/copy/`。
const Map<String, Set<String>> locationAllowlist = {
  // 開發者例外訊息（ArgumentError），不會出現在畫面上。
  // TODO(integrator): 改成英文或搬進 copy/。
  'lib/data/repository.dart': {
    '一天 \${AppConfig.minPlansPerDay}–\${AppConfig.maxPlansPerDay} 件',
  },
  // 「如果⋯我就⋯」的句型與時間點正規化的文字處理（資料格式的一部分，也被存進資料庫）。
  // TODO(integrator): 句型骨架搬進 copy/（例如 PlanCopy.ifThen），normalize 的關鍵字也一起。
  'lib/domain/models.dart': {
    '如果\$cue，我就\$task',
    '如果',
    '我',
    '我\$t',
  },
  // Foundation 的 stub（TODO(build-c) 會換成 copy/ 裡的句子池）。換掉後這筆會變成 stale，lint 會提醒刪掉。
  'lib/domain/lesson/template_lesson_service.dart': {
    '今天沒什麼特別要記的，就是普通的一天。',
  },
};

enum LintIssueKind {
  /// 違反 copy_rules.json（L1／L2／concise）。
  rule,

  /// CJK 字串出現在 `lib/copy/` 以外。
  location,
}

class LintIssue {
  const LintIssue({
    required this.path,
    required this.line,
    required this.text,
    required this.kind,
    required this.violations,
    this.tone,
  });

  final String path;
  final int line;
  final String text;
  final LintIssueKind kind;
  final List<String> violations;

  /// 用哪種語氣檢查（lively／concise）。
  final AgeTone? tone;

  @override
  String toString() => '$path:$line  「$text」  ${violations.join(' ')}';
}

/// 字串是在 `Line(...)` 的哪個位置。
enum _Slot { lively, concise, other }

/// 檢查一個 Dart 檔。[path] 用相對於 `app/` 的路徑（例如 `lib/copy/home.dart`），
/// 決定這個檔案在不在 `lib/copy/` 裡。
List<LintIssue> lintSource(String path, String source, CopyRules rules) {
  final normalizedPath = path.replaceAll('\\', '/');
  final result = parseString(content: source, path: normalizedPath, throwIfDiagnostics: false);
  final lineInfo = result.lineInfo;
  final lines = source.split('\n');
  final inCopyDir = normalizedPath.startsWith('lib/copy/') || normalizedPath.contains('/lib/copy/');
  final allow = locationAllowlist[normalizedPath] ?? const <String>{};

  final collector = _StringCollector();
  result.unit.accept(collector);

  final issues = <LintIssue>[];
  for (final found in collector.found) {
    final checkText = found.text;
    if (!containsCjk(checkText)) continue;
    final startLine = lineInfo.getLocation(found.node.offset).lineNumber;
    final endLine = lineInfo.getLocation(found.node.end).lineNumber;
    final display = found.display;

    if (!inCopyDir && !allow.contains(display)) {
      issues.add(LintIssue(
        path: normalizedPath,
        line: startLine,
        text: display,
        kind: LintIssueKind.location,
        violations: const ['[location] 使用者看得到的句子要放在 lib/copy/'],
      ));
    }

    final allowL2 = _allowedL2(lines, startLine, endLine);
    final tone = found.slot == _Slot.lively ? AgeTone.lively : AgeTone.concise;
    final violations = rules.check(checkText, tone: tone, allowL2: allowL2);
    if (violations.isNotEmpty) {
      issues.add(LintIssue(
        path: normalizedPath,
        line: startLine,
        text: display,
        kind: LintIssueKind.rule,
        tone: tone,
        violations: [for (final v in violations) v.toString()],
      ));
    }
  }
  return issues;
}

/// 從字串所在行與上一行（多行字串則含整段）找 `// copy-allow:` 標記。
Set<String> _allowedL2(List<String> lines, int startLine, int endLine) {
  final out = <String>{};
  for (var n = startLine - 1; n <= endLine; n++) {
    if (n < 1 || n > lines.length) continue;
    final m = _allowComment.firstMatch(lines[n - 1]);
    if (m == null) continue;
    for (final w in m.group(1)!.split(RegExp(r'[,，、\s]+'))) {
      if (w.trim().isNotEmpty) out.add(w.trim());
    }
  }
  return out;
}

class _Found {
  _Found(this.node, this.text, this.display, this.slot);
  final AstNode node;

  /// 拿去檢查規則的文字（插值換成 0，讓「還有 $n 件」也抓得到）。
  final String text;

  /// 印出來與比對 allowlist 用的原始碼寫法（去掉引號）。
  final String display;
  final _Slot slot;
}

class _StringCollector extends RecursiveAstVisitor<void> {
  final found = <_Found>[];

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    // 整段串起來檢查，不再個別檢查裡面的片段。
    final text = node.strings.map(_textOf).join();
    final display = node.strings.map(_displayOf).join();
    found.add(_Found(node, text, display, _slotOf(node)));
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    found.add(_Found(node, node.value, _displayOf(node), _slotOf(node)));
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    found.add(_Found(node, _textOf(node), _displayOf(node), _slotOf(node)));
    // 插值運算式裡可能還有字串。
    for (final e in node.elements.whereType<InterpolationExpression>()) {
      e.expression.accept(this);
    }
  }

  static String _textOf(StringLiteral s) {
    if (s is SimpleStringLiteral) return s.value;
    if (s is StringInterpolation) {
      return [
        for (final e in s.elements)
          if (e is InterpolationString) e.value else '0',
      ].join();
    }
    if (s is AdjacentStrings) return s.strings.map(_textOf).join();
    return s.stringValue ?? '';
  }

  static String _displayOf(StringLiteral s) {
    if (s is SimpleStringLiteral) return s.value;
    if (s is StringInterpolation) {
      return [
        for (final e in s.elements)
          if (e is InterpolationString) e.value else e.toSource(),
      ].join();
    }
    if (s is AdjacentStrings) return s.strings.map(_displayOf).join();
    return s.toSource();
  }

  /// 字串是不是 `Line(lively, concise)`／`Line.same(text)` 的參數。
  static _Slot _slotOf(StringLiteral node) {
    final args = node.parent;
    if (args is! ArgumentList) return _Slot.other;
    final call = args.parent;
    String? typeName;
    String? ctorName;
    if (call is InstanceCreationExpression) {
      typeName = call.constructorName.type.name.lexeme;
      ctorName = call.constructorName.name?.name;
    } else if (call is MethodInvocation) {
      final target = call.target;
      if (target == null) {
        typeName = call.methodName.name;
      } else if (target is SimpleIdentifier) {
        typeName = target.name;
        ctorName = call.methodName.name;
      }
    }
    if (typeName != 'Line') return _Slot.other;
    if (ctorName == 'same') return _Slot.concise;
    if (ctorName != null) return _Slot.other;
    final index = args.arguments.indexOf(node);
    if (index == 0) return _Slot.lively;
    if (index == 1) return _Slot.concise;
    return _Slot.other;
  }
}

/// 掃 [libDir]（預設 `lib/`）底下所有 `.dart`（不含 `*.g.dart`）。[appRoot] 是 `app/`。
List<LintIssue> lintDirectory(Directory appRoot, CopyRules rules, {String libDir = 'lib'}) {
  final root = Directory('${appRoot.path}/$libDir');
  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final issues = <LintIssue>[];
  for (final f in files) {
    final rel = f.path.substring(appRoot.path.length).replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
    issues.addAll(lintSource(rel, f.readAsStringSync(), rules));
  }
  return issues;
}

/// [locationAllowlist] 裡已經找不到的項目（檔案不見或字串已搬走）：`path: 字串`。只提醒、不算違規。
List<String> staleAllowlistEntries(Directory appRoot) {
  final out = <String>[];
  locationAllowlist.forEach((path, strings) {
    final f = File('${appRoot.path}/$path');
    final present = f.existsSync() ? cjkStringsIn(path, f.readAsStringSync()) : const <String>{};
    for (final s in strings) {
      if (!present.contains(s)) out.add('$path: $s');
    }
  });
  return out;
}

/// 一個檔案裡所有含 CJK 的字串（原始碼寫法）。
Set<String> cjkStringsIn(String path, String source) {
  final result = parseString(content: source, path: path, throwIfDiagnostics: false);
  final collector = _StringCollector();
  result.unit.accept(collector);
  return {for (final f in collector.found) if (containsCjk(f.text)) f.display};
}

/// 計算被掃過的檔案數（給 summary 用）。
int countLintedFiles(Directory appRoot, {String libDir = 'lib'}) => Directory('${appRoot.path}/$libDir')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
    .length;
