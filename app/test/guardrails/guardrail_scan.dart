/// 底線測試共用的靜態掃描工具（純函式，方便對 fixture 字串自我測試）。
/// 測試的工作目錄是 `app/`。
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:path/path.dart' as p;

/// `lib/` 底下所有 `.dart`（不含 `*.g.dart`），回傳相對於 `app/` 的路徑，已排序。
List<String> dartFilesUnder(String dir, {bool includeGenerated = false}) {
  final d = Directory(dir);
  if (!d.existsSync()) return const [];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => p.posix.joinAll(p.split(f.path)))
      .where((f) => f.endsWith('.dart') && (includeGenerated || !f.endsWith('.g.dart')))
      .toList()
    ..sort();
}

/// 一個檔案 import／export／part 的目標，換算成相對於 `app/` 的路徑（`lib/...`）。
/// `package:little_steps/x.dart` → `lib/x.dart`；其他套件原樣保留（`package:flutter/...`、`dart:math`）。
List<String> directiveTargets(String filePath, String source) {
  final unit = parseString(content: source, path: filePath, throwIfDiagnostics: false).unit;
  final out = <String>[];
  for (final d in unit.directives) {
    String? uri;
    if (d is UriBasedDirective) uri = d.uri.stringValue;
    if (uri == null) continue;
    out.add(resolveUri(filePath, uri));
  }
  return out;
}

String resolveUri(String filePath, String uri) {
  if (uri.startsWith('package:little_steps/')) return 'lib/${uri.substring('package:little_steps/'.length)}';
  if (uri.startsWith('package:') || uri.startsWith('dart:')) return uri;
  return p.posix.normalize(p.posix.join(p.posix.dirname(filePath), uri));
}

/// Dart 原始碼的所有 token（不含註解）。
List<Token> dartTokens(String source) {
  final unit = parseString(content: source, throwIfDiagnostics: false).unit;
  final out = <Token>[];
  var t = unit.beginToken;
  while (!t.isEof) {
    out.add(t);
    t = t.next!;
  }
  return out;
}

/// Dart 原始碼裡的識別字（含關鍵字以外所有 identifier），不含註解與字串內容。
List<String> dartIdentifiers(String source) =>
    [for (final t in dartTokens(source)) if (t.type == TokenType.IDENTIFIER || t.isIdentifier) t.lexeme];

/// Dart 原始碼裡的字串字面值內容（不含引號；含插值的字串取原始 lexeme）。
List<String> dartStringLexemes(String source) =>
    [for (final t in dartTokens(source)) if (t.type == TokenType.STRING) t.lexeme];

/// 去掉 Dart 註解後的原始碼（保留字串）。用 token 重組，所以註解裡寫什麼都不會被掃到。
String stripDartComments(String source) => dartTokens(source).map((t) => t.lexeme).join(' ');

/// 去掉 JS／TS 的 `//` 與 `/* */` 註解（尊重字串與樣板字串）。
String stripJsComments(String s) {
  final b = StringBuffer();
  var i = 0;
  String? quote;
  while (i < s.length) {
    final c = s[i];
    final next = i + 1 < s.length ? s[i + 1] : '';
    if (quote != null) {
      b.write(c);
      if (c == r'\' && i + 1 < s.length) {
        b.write(next);
        i += 2;
        continue;
      }
      if (c == quote) quote = null;
      i++;
      continue;
    }
    if (c == '"' || c == "'" || c == '`') {
      quote = c;
      b.write(c);
      i++;
      continue;
    }
    if (c == '/' && next == '/') {
      while (i < s.length && s[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      final end = s.indexOf('*/', i + 2);
      i = end < 0 ? s.length : end + 2;
      b.write(' ');
      continue;
    }
    b.write(c);
    i++;
  }
  return b.toString();
}

/// 把識別字拆成小寫單字：`todayPlansProvider` → [today, plans, provider]、`last_open` → [last, open]。
List<String> identifierWords(String identifier) => identifier
    .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
    .replaceAllMapped(RegExp(r'([A-Z]+)([A-Z][a-z])'), (m) => '${m[1]} ${m[2]}')
    .split(RegExp(r'[\s_$]+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w.toLowerCase())
    .toList();

String camelToSnake(String s) => identifierWords(s).join('_');
