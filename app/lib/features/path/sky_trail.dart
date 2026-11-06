import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/repository.dart';
import '../../domain/models.dart';
import 'tree_trail.dart' show TrailMark;

/// 星空：有計畫的日子一顆星，照日期用細線連成一個大星座（J3）。新的在上面。
///
/// - 沒計畫的日子不在清單裡，連線一路接下去，沒有斷掉的地方。
/// - 每顆星都一樣亮，不因任何事變暗或熄滅。
class SkyTrail extends StatelessWidget {
  const SkyTrail({super.key, required this.days, required this.tone});

  /// 舊的在前（repository 的順序）。
  final List<PlannedDay> days;
  final AgeTone tone;

  static const night = Color(0xFF2F3B5C);

  @override
  Widget build(BuildContext context) {
    final ordered = days.reversed.toList();
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final centers = starCenters(ordered, width);
      final rows = (ordered.length / TrailConfig.starsPerRow).ceil();
      final height = rows * TrailConfig.starRowHeight + AppSpace.m;
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          width: width,
          height: height,
          color: night,
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _SkyPainter(centers))),
              for (final (i, day) in ordered.indexed)
                Positioned(
                  left: centers[i].dx - TrailConfig.starSize / 2,
                  top: centers[i].dy - TrailConfig.starSize / 2,
                  child: TrailMark(day: day, tone: tone, kind: 'star'),
                ),
            ],
          ),
        ),
      );
    });
  }

  /// 一列幾顆、每列來回蛇行（像一筆畫下去），位置再依日期輕輕錯開一點，看起來像星座。
  static List<Offset> starCenters(List<PlannedDay> ordered, double width) {
    const per = TrailConfig.starsPerRow;
    final cell = width / per;
    return [
      for (final (i, day) in ordered.indexed)
        () {
          final row = i ~/ per;
          final col = row.isEven ? i % per : per - 1 - i % per;
          final r = math.Random(day.dayKey.hashCode);
          final jx = (r.nextDouble() - 0.5) * cell * 0.4;
          final jy = (r.nextDouble() - 0.5) * TrailConfig.starRowHeight * 0.3;
          return Offset((col + 0.5) * cell + jx, (row + 0.5) * TrailConfig.starRowHeight + AppSpace.s + jy);
        }(),
    ];
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.centers);
  final List<Offset> centers;

  @override
  void paint(Canvas canvas, Size size) {
    // 背景小點點（固定的，不代表任何事）。
    final dust = Paint()..color = Colors.white.withValues(alpha: 0.25);
    final r = math.Random(7);
    for (var i = 0; i < (size.width * size.height / 3000).round(); i++) {
      canvas.drawCircle(Offset(r.nextDouble() * size.width, r.nextDouble() * size.height), 1, dust);
    }
    if (centers.length < 2) return;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (final c in centers.skip(1)) {
      path.lineTo(c.dx, c.dy);
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_SkyPainter old) => !listEquals(old.centers, centers);
}
