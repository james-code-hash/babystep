import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../copy/path.dart';
import '../../core/clock.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/repository.dart';
import '../../domain/models.dart';

/// 一棵樹：有計畫的日子一片葉子（J3）。最早的葉子在樹冠中間，新的往外長。
///
/// - 沒計畫的日子不在清單裡，所以沒有空位、沒有落葉、沒有枯枝；樹不會因為任何事變小或變色。
/// - 每片葉子都一樣：只有那天第一件事的圖示。
class TreeTrail extends StatelessWidget {
  const TreeTrail({super.key, required this.days, required this.tone});

  /// 舊的在前（repository 的順序）。
  final List<PlannedDay> days;
  final AgeTone tone;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final layout = leafLayout(days.length, width);
      return SizedBox(
        width: width,
        height: layout.height,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _TreePainter(layout, (count: days.length, width: width)))),
            for (final (i, day) in days.indexed)
              Positioned(
                left: layout.leaves[i].dx - TrailConfig.leafSize / 2,
                top: layout.leaves[i].dy - TrailConfig.leafSize / 2,
                child: TrailMark(day: day, tone: tone, kind: 'leaf'),
              ),
          ],
        ),
      );
    });
  }

  /// 樹冠中心、每片葉子的位置與整棵樹的高度。
  ///
  /// 葉子排在蜂巢格上，照離中心的距離由近到遠一片片放（最早的在中間），所以永遠是一整團、沒有空位；
  /// 樹冠碰到兩邊之後就往上下長，變成高高的一棵樹，不會擠出畫面。
  static ({Offset crown, List<Offset> leaves, double height, double radiusY}) leafLayout(int count, double width) {
    const half = TrailConfig.leafSize / 2;
    const d = TrailConfig.leafSpacing;
    final maxX = math.max(0.0, width / 2 - half - AppSpace.s);
    final perRow = (2 * maxX / d).floor() + 1;
    final reach = (math.max(math.sqrt(count.toDouble()), count / perRow) + 2) * d;
    final rows = (reach / (d * 0.866)).ceil();
    final candidates = <Offset>[
      for (var r = -rows; r <= rows; r++)
        for (var c = -perRow; c <= perRow; c++)
          Offset(c * d + (r.isOdd ? d / 2 : 0), r * d * 0.866),
    ].where((p) => p.dx.abs() <= maxX).toList()
      ..sort((a, b) {
        final byDistance = a.distance.compareTo(b.distance);
        return byDistance != 0 ? byDistance : a.direction.compareTo(b.direction);
      });
    final rel = candidates.take(count).toList();
    final top = rel.isEmpty ? 0.0 : rel.map((p) => p.dy).reduce(math.min);
    final bottom = rel.isEmpty ? 0.0 : rel.map((p) => p.dy).reduce(math.max);
    final radiusY = math.max((bottom - top) / 2 + half, d);
    final crown = Offset(width / 2, AppSpace.s + half - top);
    final leaves = [for (final p in rel) crown + p];
    return (crown: crown, leaves: leaves, height: crown.dy + bottom + half + TrailConfig.trunkHeight, radiusY: radiusY);
  }
}

class _TreePainter extends CustomPainter {
  _TreePainter(this.layout, this.input);
  final ({Offset crown, List<Offset> leaves, double height, double radiusY}) layout;

  /// [layout] 只由這兩個數算出來（[TreeTrail.leafLayout]），比它們就知道要不要重畫。
  final ({int count, double width}) input;

  @override
  void paint(Canvas canvas, Size size) {
    final c = layout.crown;
    final leaves = layout.leaves;
    final ys = leaves.map((p) => p.dy);
    final mid = leaves.isEmpty ? c.dy : (ys.reduce(math.min) + ys.reduce(math.max)) / 2;
    final halfW = (leaves.isEmpty ? 0.0 : leaves.map((p) => (p.dx - c.dx).abs()).reduce(math.max)) +
        TrailConfig.leafSize * 0.8;
    const bark = Color(0xFFB08B68);

    // 樹幹與三根樹枝。
    canvas.drawLine(
      Offset(c.dx, size.height - AppSpace.s),
      Offset(c.dx, mid),
      Paint()
        ..color = bark
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round,
    );
    final branch = Paint()
      ..color = bark
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final reach = math.min(layout.radiusY, halfW) * 0.6;
    final fork = Offset(c.dx, mid + reach * 0.3);
    for (final a in [-2.4, -1.57, -0.7]) {
      canvas.drawLine(fork, fork + Offset(math.cos(a) * reach, math.sin(a) * reach), branch);
    }
    // 樹冠的底色：一團柔和的綠，讓葉子看起來長在同一棵樹上。
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx, mid),
        width: halfW * 2,
        height: layout.radiusY * 2 + TrailConfig.leafSize * 0.6,
      ),
      Paint()..color = AppColors.leaf.withValues(alpha: 0.18),
    );
    // 地面。
    canvas.drawLine(
      Offset(size.width * 0.2, size.height - AppSpace.s),
      Offset(size.width * 0.8, size.height - AppSpace.s),
      Paint()
        ..color = AppColors.line
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  // 不比 layout：record 的 == 對裡面的 List 只比是不是同一個物件，每次 build 都是新的。
  bool shouldRepaint(_TreePainter old) => old.input != input;
}

/// 樹上的葉子或天上的星星。同一種樣子裡每一個都長得一樣：只有那天第一件事的圖示。
class TrailMark extends StatelessWidget {
  const TrailMark({super.key, required this.day, required this.tone, required this.kind});
  final PlannedDay day;
  final AgeTone tone;

  /// 'leaf' 或 'star'（也是 key 的前綴）。
  final String kind;

  @override
  Widget build(BuildContext context) {
    final date = dateOfDayKey(day.dayKey);
    final md = {'m': '${date.month}', 'd': '${date.day}'};
    final emoji = day.emojis.isEmpty ? '' : day.emojis.first;
    final task = day.tasks.isEmpty ? '' : day.tasks.first;
    final star = kind == 'star';
    final size = star ? TrailConfig.starSize : TrailConfig.leafSize;
    return Tooltip(
      message: PathCopy.markTip.fill(tone, {...md, 'task': task}),
      child: Semantics(
        label: PathCopy.stoneSemantics.fill(tone, {...md, 'task': task}),
        excludeSemantics: true,
        child: Container(
          key: ValueKey('$kind-${day.dayKey}'),
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: star
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFE9A8),
                  boxShadow: [BoxShadow(color: const Color(0xFFFFE9A8).withValues(alpha: 0.7), blurRadius: 14)],
                )
              : BoxDecoration(
                  color: AppColors.leaf,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(TrailConfig.leafSize),
                    bottomRight: Radius.circular(TrailConfig.leafSize),
                    topRight: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                  ),
                  border: Border.all(color: AppColors.card, width: 2),
                ),
          child: Text(emoji, style: TextStyle(fontSize: size * 0.45)),
        ),
      ),
    );
  }
}
