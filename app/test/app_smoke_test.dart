import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('app boots offline to the home screen', (tester) async {
    final env = TestEnv();
    await pumpApp(tester, env);
    expect(find.byKey(const ValueKey('placeholder-home')), findsOneWidget);
    await env.dispose();
  });
}
