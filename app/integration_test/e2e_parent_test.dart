// 情境：家長區（PIN、建議、說話方式、LLM 開關、匯出、提醒時段、刪除全部）。在裝置或 Linux 桌面上：
//   cd app && fvm flutter test integration_test/e2e_parent_test.dart -d <device>
import 'package:integration_test/integration_test.dart';

import 'scenarios/parent.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  parentScenarios();
}
