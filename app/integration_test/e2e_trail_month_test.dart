// 情境：成長軌跡三種樣子、月回顧。在裝置或 Linux 桌面上：
//   cd app && fvm flutter test integration_test/e2e_trail_month_test.dart -d <device>
import 'package:integration_test/integration_test.dart';

import 'scenarios/trail_month.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  trailMonthScenarios();
}
