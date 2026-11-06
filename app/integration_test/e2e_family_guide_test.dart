// 情境：話術轉譯器、家長微課程、全家一起、月回顧的信。在裝置或 Linux 桌面上：
//   cd app && fvm flutter test integration_test/e2e_family_guide_test.dart -d <device>
import 'package:integration_test/integration_test.dart';

import 'scenarios/family_guide.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  familyGuideScenarios();
}
