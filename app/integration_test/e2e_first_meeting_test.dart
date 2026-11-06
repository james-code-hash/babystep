// 情境：初次見面與取名字。在裝置或 Linux 桌面上：
//   cd app && fvm flutter test integration_test/e2e_first_meeting_test.dart -d <device>
// 全部情境一次跑：tool/e2e.sh
import 'package:integration_test/integration_test.dart';

import 'scenarios/first_meeting.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  firstMeetingScenarios();
}
