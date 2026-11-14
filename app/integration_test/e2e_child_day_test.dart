// 情境：孩子的核心循環。在裝置或 Linux 桌面上：
//   cd app && fvm flutter test integration_test/e2e_child_day_test.dart -d <device>
// 全部情境一次跑：tool/e2e.sh
import 'package:integration_test/integration_test.dart';

import 'scenarios/child_day.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  childDayScenarios();
}
