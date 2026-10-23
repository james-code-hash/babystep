// 底線 2（步步不讀孩子做了什麼）與底線 7（家長不是監控者）的 import 邊界。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'guardrail_scan.dart';

// ------------------------------------------------------------------ 規則

/// `lib/bubu/`（除了 bubu_inputs.dart）不得 import 的目標（前綴比對，路徑相對於 app/）。
bool bubuForbiddenTarget(String target) =>
    target == 'lib/providers.dart' ||
    target.startsWith('lib/data/') ||
    target.startsWith('lib/features/') ||
    target.startsWith('lib/domain/lesson') ||
    target.startsWith('lib/safety/');

/// bubu_inputs.dart 本身可以 import providers.dart，但仍不得碰 data/、features/、lesson、safety/。
bool bubuInputsForbiddenTarget(String target) => target != 'lib/providers.dart' && bubuForbiddenTarget(target);

/// bubu_inputs.dart 只能引用這些 provider（自己定義的 bubuDressUpProvider 也算）。
const bubuInputsAllowedProviders = {
  'dressUpProvider',
  'clockProvider',
  'randomProvider',
  'toneProvider',
  'bubuDressUpProvider',
};

/// greeting.dart 也不得 import 任何跟計畫／回顧／筆記有關的 copy 或 domain。
bool greetingForbiddenTarget(String target) =>
    bubuForbiddenTarget(target) ||
    RegExp(r'(plan|review|lesson|notebook|path|parent|repository)', caseSensitive: false).hasMatch(target);

/// `lib/features/parent/**` 不得引用的識別字（家長端只能讀 ParentView）。
final parentForbidden = <String, RegExp>{
  'watchPlans': RegExp(r'\bwatchPlans\b'),
  'plans(': RegExp(r'\bplans\s*\('),
  'setOutcome': RegExp(r'\bsetOutcome\b'),
  'watchLessons': RegExp(r'\bwatchLessons\b'),
  'watchLessonFor': RegExp(r'\bwatchLessonFor\b'),
  'lessonsProvider': RegExp(r'\blessonsProvider\b'),
  'todayPlansProvider': RegExp(r'\btodayPlansProvider\b'),
  'todayRecordProvider': RegExp(r'\btodayRecordProvider\b'),
  'plannedDaysProvider': RegExp(r'\bplannedDaysProvider\b'),
  'plannedDays': RegExp(r'\b(watchP|p)lannedDays\b'),
  'dayRecord': RegExp(r'\bdayRecord\b'),
  'watchDayRecord': RegExp(r'\bwatchDayRecord\b'),
  'Outcome': RegExp(r'\bOutcome\b'),
  'reflection': RegExp(r'\breflection\b'),
};

List<String> bubuImportViolations(String path, String source) {
  final name = path.split('/').last;
  final forbidden = switch (name) {
    'bubu_inputs.dart' => bubuInputsForbiddenTarget,
    'greeting.dart' => greetingForbiddenTarget,
    _ => bubuForbiddenTarget,
  };
  return [
    for (final t in directiveTargets(path, source))
      if (forbidden(t)) '$path imports $t',
  ];
}

/// provider 實例（小寫開頭、Provider 結尾）；`Provider`、`StreamProvider` 這些型別名不算。
bool isProviderInstance(String id) => RegExp(r'^_?[a-z]\w*Provider$').hasMatch(id);

List<String> bubuInputsProviderViolations(String source) => [
      for (final id in dartIdentifiers(source).toSet())
        if (isProviderInstance(id) && !bubuInputsAllowedProviders.contains(id)) 'bubu_inputs.dart references $id',
    ];

List<String> parentViolations(String path, String source) {
  final out = <String>[
    for (final t in directiveTargets(path, source))
      if (t == 'lib/data/db.dart' || t.startsWith('package:drift')) '$path imports $t',
  ];
  final code = stripDartComments(source);
  parentForbidden.forEach((label, re) {
    if (re.hasMatch(code)) out.add('$path references $label');
  });
  return out;
}

// ------------------------------------------------------------------ 測試

void main() {
  group('scanner self-test', () {
    test('relative and package imports resolve', () {
      expect(resolveUri('lib/bubu/greeting.dart', '../providers.dart'), 'lib/providers.dart');
      expect(resolveUri('lib/bubu/a.dart', 'package:little_steps/data/db.dart'), 'lib/data/db.dart');
      expect(resolveUri('lib/bubu/a.dart', 'b.dart'), 'lib/bubu/b.dart');
    });

    test('bubu imports are caught', () {
      const src = "import '../providers.dart';\nimport '../data/repository.dart';\n"
          "import 'package:little_steps/features/home/home_screen.dart';\nimport '../domain/lesson_service.dart';\n"
          "import '../domain/lesson/template_lesson_service.dart';\nexport '../safety/safety_gate.dart';\n"
          "import '../domain/models.dart';\nimport 'bubu_inputs.dart';\n";
      expect(bubuImportViolations('lib/bubu/bubu_view.dart', src), hasLength(6));
    });

    test('bubu_inputs may import providers.dart but nothing else forbidden', () {
      expect(bubuImportViolations('lib/bubu/bubu_inputs.dart', "import '../providers.dart';"), isEmpty);
      expect(bubuImportViolations('lib/bubu/bubu_inputs.dart', "import '../data/db.dart';"), hasLength(1));
    });

    test('greeting cannot import plan/review copy', () {
      expect(bubuImportViolations('lib/bubu/greeting.dart', "import '../copy/review.dart';"), hasLength(1));
      expect(bubuImportViolations('lib/bubu/greeting.dart', "import '../copy/plan.dart';"), hasLength(1));
      expect(bubuImportViolations('lib/bubu/greeting.dart', "import '../copy/bubu.dart';"), isEmpty);
    });

    test('bubu_inputs provider whitelist', () {
      expect(bubuInputsProviderViolations('final a = Provider((ref) => ref.watch(todayPlansProvider));'),
          ['bubu_inputs.dart references todayPlansProvider']);
      expect(bubuInputsProviderViolations('final a = ref.watch(dressUpProvider); // todayPlansProvider'), isEmpty);
    });

    test('parent violations are caught, comments are ignored, exportJson is fine', () {
      const bad = "import '../../data/db.dart';\n"
          'void f(r) { r.watchPlans(d); r.plans (d); r.setOutcome(); ref.watch(lessonsProvider); '
          'r.plannedDays(); x.reflection; Outcome.done; ref.watch(todayRecordProvider); }';
      final v = parentViolations('lib/features/parent/parent_screen.dart', bad);
      expect(v, hasLength(9), reason: v.join('\n'));
      const ok = '// watchPlans, Outcome, reflection are forbidden here\n'
          'void f(r) { r.exportJson(); r.parentView(); r.addTaskTemplate(); }';
      expect(parentViolations('lib/features/parent/parent_screen.dart', ok), isEmpty);
    });
  });

  group('lib/bubu/', () {
    final files = dartFilesUnder('lib/bubu');

    test('exists', () => expect(files, isNotEmpty));

    test('import boundary', () {
      final v = [for (final f in files) ...bubuImportViolations(f, File(f).readAsStringSync())];
      expect(v, isEmpty, reason: v.join('\n'));
    });

    test('bubu_inputs.dart only references the allowed providers', () {
      final v = bubuInputsProviderViolations(File('lib/bubu/bubu_inputs.dart').readAsStringSync());
      expect(v, isEmpty, reason: v.join('\n'));
    });

    test('other bubu files only read providers that bubu_inputs exposes (or that bubu/ defines itself)', () {
      // bubu/ 自己定義的 provider（例如動畫用）可以用：它們能讀的東西也受上面的 import 邊界限制。
      final defined = <String>{
        for (final f in files)
          for (final m in RegExp(r'\b(\w+Provider)\s*=').allMatches(stripDartComments(File(f).readAsStringSync())))
            m.group(1)!,
      };
      final v = <String>[
        for (final f in files.where((f) => !f.endsWith('/bubu_inputs.dart')))
          for (final id in dartIdentifiers(File(f).readAsStringSync()).toSet())
            if (isProviderInstance(id) && !bubuInputsAllowedProviders.contains(id) && !defined.contains(id))
              '$f references $id',
      ];
      expect(v, isEmpty, reason: v.join('\n'));
    });
  });

  group('lib/features/parent/', () {
    test('only reads ParentView', () {
      final files = dartFilesUnder('lib/features/parent');
      expect(files, isNotEmpty);
      final v = [for (final f in files) ...parentViolations(f, File(f).readAsStringSync())];
      expect(v, isEmpty, reason: v.join('\n'));
    });
  });
}
