import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/features/home/home_screen.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('app boots offline to the home screen', (tester) async {
    final env = TestEnv();
    await pumpApp(tester, env);
    expect(find.byType(HomeScreen), findsOneWidget);
    await finishTest(tester, env);
  });
}
