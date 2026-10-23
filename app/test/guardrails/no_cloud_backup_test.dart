// 底線 8：本地優先。孩子的資料不能被系統的雲端備份（Google 雲端硬碟／iCloud）或裝置轉移帶走，
// 否則「刪除全部」也刪不乾淨（decisions.md G4）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `<application ...>` 開頭標籤裡的屬性。
Map<String, String> applicationAttributes(String manifest) {
  final tag = RegExp(r'<application\b([^>]*)>', dotAll: true).firstMatch(manifest);
  if (tag == null) return const {};
  return {
    for (final m in RegExp(r'([\w:]+)\s*=\s*"([^"]*)"').allMatches(tag.group(1)!)) m.group(1)!: m.group(2)!,
  };
}

/// data_extraction_rules.xml 的問題：沒有排除全部 domain、或有任何 include。
List<String> extractionRuleProblems(String xml) {
  const domains = ['root', 'file', 'database', 'sharedpref', 'external'];
  final problems = <String>[];
  if (RegExp(r'<include\b').hasMatch(xml)) problems.add('has <include>');
  for (final section in ['cloud-backup', 'device-transfer']) {
    final body = RegExp('<$section\\b[^>]*>(.*?)</$section>', dotAll: true).firstMatch(xml)?.group(1);
    if (body == null) {
      problems.add('missing <$section>');
      continue;
    }
    for (final d in domains) {
      if (!RegExp('<exclude\\s+domain="$d"\\s+path="\\."\\s*/>').hasMatch(body)) problems.add('$section keeps $d');
    }
  }
  return problems;
}

void main() {
  group('self-test', () {
    test('manifest attribute reader', () {
      const m = '<manifest><application\n  android:label="x"\n  android:allowBackup="true">\n<activity/></application></manifest>';
      expect(applicationAttributes(m), {'android:label': 'x', 'android:allowBackup': 'true'});
    });

    test('rules that keep something are flagged', () {
      const partial = '<data-extraction-rules><cloud-backup><exclude domain="database" path="." /></cloud-backup>'
          '<device-transfer><include domain="file" path="." /></device-transfer></data-extraction-rules>';
      final p = extractionRuleProblems(partial);
      expect(p, containsAll(['has <include>', 'cloud-backup keeps file', 'device-transfer keeps database']));
      expect(p, isNot(contains('cloud-backup keeps database')));
    });
  });

  test('Android: no Auto Backup, no full backup, no device-transfer of app data', () {
    final attrs = applicationAttributes(File('android/app/src/main/AndroidManifest.xml').readAsStringSync());
    expect(attrs['android:allowBackup'], 'false');
    expect(attrs['android:fullBackupContent'], 'false');
    expect(attrs['android:dataExtractionRules'], '@xml/data_extraction_rules');
    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml');
    expect(rules.existsSync(), isTrue);
    expect(extractionRuleProblems(rules.readAsStringSync()), isEmpty);
  });

  test('iOS: the database folder (Application Support) is excluded from backup', () {
    final store = File('lib/data/database_store.dart').readAsStringSync();
    expect(store, contains('getApplicationSupportDirectory()'));
    expect(store, isNot(contains('getApplicationDocumentsDirectory')));
    final delegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(delegate, contains('.applicationSupportDirectory'));
    expect(delegate, contains('isExcludedFromBackup = true'));
    expect(delegate, contains('excludeAppSupportFromBackup()'));
  });
}
