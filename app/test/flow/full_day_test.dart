// 與 integration_test/full_day_test.dart 同一份流程，在 flutter_tester 上跑。
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/domain/models.dart';

import '../../integration_test/full_day_flow.dart';

void main() {
  for (final outcome in Outcome.values) {
    testWidgets('a full offline day with "${outcome.name}" reaches a clear ending', (tester) => runFullDay(tester, outcome));
  }
}
