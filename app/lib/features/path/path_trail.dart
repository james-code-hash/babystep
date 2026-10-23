import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../copy/path.dart';
import '../../core/clock.dart';
import '../../core/theme.dart';
import '../../data/repository.dart';
import '../../domain/models.dart';
import '../../core/config.dart';

/// 一條彎彎的小路：只畫有計畫的日子，一天一塊石頭（C5）。
///
/// - 沒計畫的日子**根本不在清單裡**，所以不會有空格、虛線或「漏掉」的記號。
/// - 每塊石頭的樣子都一樣：只有那天第一件事的圖示和日期，不因完成度改變（[PlannedDay] 本來就沒有 outcome）。
/// - 新的在上面，往下走是比較早的日子。
class PathTrail extends StatelessWidget {
  const PathTrail({super.key, required this.days, required this.tone});

  /// 舊的在前（repository 的順序）。
  final List<PlannedDay> days;
  final AgeTone tone;

  @override
  Widget build(BuildContext context) {
    final ordered = days.reversed.toList();
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final centers = stoneCenters(ordered.length, width);
      const labelHeight = 24.0;
      final height = ordered.isEmpty ? 0.0 : centers.last.dy + PathConfig.stoneSize / 2 + labelHeight + AppSpace.m;
      return SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: PathPainter(centers))),
            for (final (i, day) in ordered.indexed)
              Positioned(
                left: centers[i].dx - PathConfig.stoneSize,
                top: centers[i].dy - PathConfig.stoneSize / 2,
                width: PathConfig.stoneSize * 2,
                child: PathStone(day: day, tone: tone),
              ),
          ],
        ),
      );
    });
  }

  /// 第 i 塊石頭的中心點：沿著緩和的正弦曲線左右擺。
  static List<Offset> stoneCenters(int count, double width) {
    final sway = width * PathConfig.swayFraction;
    final cx = width / 2;
    const top = PathConfig.stoneSize / 2 + AppSpace.m;
    return [
      for (var i = 0; i < count; i++)
        Offset(cx + sway * math.sin(i * PathConfig.swayStep), top + i * PathConfig.stoneSpacing),
    ];
  }
}

/// 一塊石頭。所有石頭共用同一個樣式。
class PathStone extends StatelessWidget {
  const PathStone({super.key, required this.day, required this.tone});
  final PlannedDay day;
  final AgeTone tone;

  @override
  Widget build(BuildContext context) {
    final date = dateOfDayKey(day.dayKey);
    final md = {'m': '${date.month}', 'd': '${date.day}'};
    final emoji = day.emojis.isEmpty ? '' : day.emojis.first;
    final task = day.tasks.isEmpty ? '' : day.tasks.first;
    return Semantics(
      label: PathCopy.stoneSemantics.fill(tone, {...md, 'task': task}),
      excludeSemantics: true,
      child: Column(
        key: ValueKey('stone-${day.dayKey}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: PathConfig.stoneSize,
            height: PathConfig.stoneSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.line, width: 2),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 3))],
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 32)),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            PathCopy.stoneDate.fill(tone, md),
            style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// 畫穿過每塊石頭的小路（實線，沒有任何缺口）。
class PathPainter extends CustomPainter {
  PathPainter(this.centers);
  final List<Offset> centers;

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.isEmpty) return;
    final path = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (var i = 1; i < centers.length; i++) {
      final a = centers[i - 1];
      final b = centers[i];
      final midY = (a.dy + b.dy) / 2;
      path.cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
    }
    // 起點（最早的那天）再往下延伸一小段，像小路從這裡開始。
    final last = centers.last;
    path.quadraticBezierTo(last.dx, last.dy + PathConfig.stoneSpacing * 0.4, size.width / 2, size.height);

    final paint = Paint()
      ..color = AppColors.accentSoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = PathConfig.stoneSize * 0.42
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(PathPainter old) =>
      old.centers.length != centers.length ||
      [for (var i = 0; i < centers.length; i++) old.centers[i] != centers[i]].any((x) => x);
}
