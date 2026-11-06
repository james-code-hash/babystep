// 情境：探索角、驚喜盒、輕點步步。在裝置或 Linux 桌面上：
//   cd app && fvm flutter test integration_test/e2e_explore_test.dart -d <device>
import 'package:integration_test/integration_test.dart';

import 'scenarios/explore.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  exploreScenarios();
}
