/// 文案 lint：`cd app && fvm dart run tool/copy_lint.dart`
///
/// 掃 `lib/` 所有 Dart 檔的中文字串，用 `assets/copy_rules.json`（同 App 執行期）檢查。
/// 有任何違規 → exit code 1。規則與例外見 `tool/copy_lint_core.dart`。
library;

import 'dart:io';

import 'package:little_steps/core/copy_rules.dart';

import 'copy_lint_core.dart';

void main(List<String> args) {
  final appRoot = Directory.current;
  final rulesFile = File('${appRoot.path}/assets/copy_rules.json');
  if (!rulesFile.existsSync()) {
    stderr.writeln('copy_lint: 找不到 assets/copy_rules.json，請在 app/ 目錄執行。');
    exitCode = 2;
    return;
  }
  final rules = CopyRules.fromJsonString(rulesFile.readAsStringSync());
  final issues = lintDirectory(appRoot, rules);
  for (final i in issues) {
    stdout.writeln(i);
  }
  for (final s in staleAllowlistEntries(appRoot)) {
    stdout.writeln('copy_lint: note — allowlist entry no longer needed, remove it from tool/copy_lint_core.dart: $s');
  }
  final files = countLintedFiles(appRoot);
  if (issues.isEmpty) {
    stdout.writeln('copy_lint: OK — $files files, 0 violations.');
    exitCode = 0;
  } else {
    stdout.writeln('copy_lint: FAILED — $files files, ${issues.length} violations.');
    exitCode = 1;
  }
}
