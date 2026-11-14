// 在真機／模擬器上離線跑完整一天：
//   cd app && fvm flutter test integration_test/full_day_test.dart -d <device>
// 同一份流程也在 test/flow/full_day_test.dart 以 widget test 跑（雲端沒有裝置時）。
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:little_steps/domain/models.dart';

import 'full_day_flow.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final outcome in Outcome.values) {
    testWidgets('a full offline day with "${outcome.name}" reaches a clear ending', (tester) => runFullDay(tester, outcome));
  }
}
