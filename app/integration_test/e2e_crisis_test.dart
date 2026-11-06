// 情境：危機內容走預寫的安全回應。在裝置或 Linux 桌面上：
//   cd app && fvm flutter test integration_test/e2e_crisis_test.dart -d <device>
import 'package:integration_test/integration_test.dart';

import 'scenarios/crisis.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  crisisScenarios();
}
