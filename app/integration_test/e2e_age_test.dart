// 情境：分齡（小樹苗／小探險家）。在裝置或 Linux 桌面上：
//   cd app && fvm flutter test integration_test/e2e_age_test.dart -d <device>
import 'package:integration_test/integration_test.dart';

import 'scenarios/age.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  ageScenarios();
}
