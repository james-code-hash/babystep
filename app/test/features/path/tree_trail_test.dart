// 樹只在葉子真的變了才重畫（record 裡的 List 每次 build 都是新的，不能只用 ==）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_steps/data/repository.dart';
import 'package:little_steps/domain/models.dart';
import 'package:little_steps/features/path/tree_trail.dart';

PlannedDay _day(String k) => PlannedDay(dayKey: k, emojis: const ['🎹'], tasks: const ['練習樂器'], cues: const []);

void main() {
  testWidgets('the tree is not repainted when the same days are built again', (tester) async {
    Future<CustomPainter> pumpTree(List<PlannedDay> days) async {
      await tester.pumpWidget(MaterialApp(
        home: SingleChildScrollView(child: TreeTrail(days: days, tone: AgeTone.lively)),
      ));
      return tester
          .widget<CustomPaint>(find.descendant(of: find.byType(TreeTrail), matching: find.byType(CustomPaint)).first)
          .painter!;
    }

    final first = await pumpTree([_day('2026-10-20'), _day('2026-10-21')]);
    final again = await pumpTree([_day('2026-10-20'), _day('2026-10-21')]);
    expect(identical(first, again), isFalse, reason: 'a new painter on every build');
    expect(again.shouldRepaint(first), isFalse);

    final more = await pumpTree([_day('2026-10-20'), _day('2026-10-21'), _day('2026-10-22')]);
    expect(more.shouldRepaint(again), isTrue);
  });
}
