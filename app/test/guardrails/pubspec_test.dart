// 底線 8：沒有第三方追蹤／廣告／內購 SDK。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 長字：名稱裡任何位置出現就算。
const _substrings = [
  'analytics',
  'crashlytics',
  'admob',
  'in_app_purchase',
  'purchases',
  'tracking',
  'sentry',
  'mixpanel',
  'amplitude',
  'appsflyer',
  'facebook',
];

/// 短字：要是名稱裡獨立的一段（`google_mobile_ads`、`@adjust/sdk`），避免 `threads`、`uploads` 誤判。
const _tokens = ['ads', 'adjust'];

bool isForbiddenPackage(String name) {
  final n = name.toLowerCase();
  if (_substrings.any(n.contains)) return true;
  final parts = n.split(RegExp(r'[_\-/@.]+'));
  return parts.any(_tokens.contains);
}

/// 讀 pubspec.yaml 的 `dependencies:`／`dev_dependencies:`（以及 dependency_overrides）底下的套件名。
/// 只解析這兩層縮排，不需要 yaml 套件。
Map<String, List<String>> pubspecDependencies(String yaml) {
  final out = <String, List<String>>{};
  String? section;
  for (final raw in const LineSplitter().convert(yaml)) {
    final line = raw.replaceFirst(RegExp(r'\s+#.*$'), '');
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    final top = RegExp(r'^([A-Za-z_]+):').firstMatch(line);
    if (top != null) {
      final key = top.group(1)!;
      section = const {'dependencies', 'dev_dependencies', 'dependency_overrides'}.contains(key) ? key : null;
      if (section != null) out.putIfAbsent(section, () => []);
      continue;
    }
    if (section == null) continue;
    final dep = RegExp(r'^  ([A-Za-z0-9_]+):').firstMatch(line);
    if (dep != null) out[section]!.add(dep.group(1)!);
  }
  return out;
}

void main() {
  group('self-test', () {
    test('forbidden names', () {
      for (final n in [
        'firebase_analytics',
        'firebase_crashlytics',
        'google_mobile_ads',
        'in_app_purchase',
        'purchases_flutter',
        'sentry_flutter',
        'mixpanel_flutter',
        'amplitude_flutter',
        'appsflyer_sdk',
        'adjust_sdk',
        'facebook_app_events',
        'app_tracking_transparency',
        '@sentry/node',
        '@adjust/sdk',
      ]) {
        expect(isForbiddenPackage(n), isTrue, reason: n);
      }
      for (final n in ['threads', 'uploads', 'flutter_riverpod', 'firebase_core', 'cloud_functions', 'drift']) {
        expect(isForbiddenPackage(n), isFalse, reason: n);
      }
    });

    test('pubspec parser', () {
      const y = 'name: x\ndependencies:\n  flutter:\n    sdk: flutter\n  google_mobile_ads: ^5.0.0 # ads\n'
          '\ndev_dependencies:\n  firebase_analytics: any\nflutter:\n  uses-material-design: true\n';
      final d = pubspecDependencies(y);
      expect(d['dependencies'], ['flutter', 'google_mobile_ads']);
      expect(d['dev_dependencies'], ['firebase_analytics']);
    });
  });

  test('app/pubspec.yaml has no tracking / ads / IAP packages', () {
    final deps = pubspecDependencies(File('pubspec.yaml').readAsStringSync());
    expect(deps['dependencies'], isNotEmpty);
    final all = [for (final l in deps.values) ...l];
    expect(all.where(isForbiddenPackage), isEmpty);
  });

  test('app/pubspec.lock has no tracking / ads / IAP packages (transitive too)', () {
    final lock = File('pubspec.lock');
    expect(lock.existsSync(), isTrue);
    final names = [
      for (final m in RegExp(r'^  ([A-Za-z0-9_]+):', multiLine: true).allMatches(lock.readAsStringSync())) m.group(1)!,
    ];
    expect(names, isNotEmpty);
    expect(names.where(isForbiddenPackage), isEmpty);
  });

  test('functions/package.json has no tracking / ads packages', () {
    final f = File('../functions/package.json');
    if (!f.existsSync()) return; // functions/ 由另一部分建立；不存在時這一段沒有東西可檢查。
    final j = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
    final names = [
      for (final k in ['dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies'])
        ...((j[k] as Map<String, Object?>?) ?? const {}).keys,
    ];
    expect(names.where(isForbiddenPackage), isEmpty);
  });
}
