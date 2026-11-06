import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../copy/path.dart';
import '../../core/clock.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/repository.dart';
import '../../domain/models.dart';
import 'tree_trail.dart' show TrailMark;

/// 地圖：有計畫的日子是地圖上的一個地方，一個月是一段旅程（一章）。新的一章在上面。
///
/// - 沒計畫的日子不在清單裡；沒排事的月份也不會變成一張空白地圖（下一章直接接上）。
/// - 每個地方都長得一樣（只有那天第一件事的圖示），不因做到了沒而不同。
/// - 章名只說月份，第一章叫「出發」；沒有章數、沒有「還差幾個地方」。
class MapTrail extends StatelessWidget {
  const MapTrail({super.key, required this.days, required this.tone});

  /// 舊的在前（repository 的順序）。
  final List<PlannedDay> days;
  final AgeTone tone;

  /// 依月份分章，新的一章在前；章裡面照日期排。
  static List<({String month, List<PlannedDay> days})> chapters(List<PlannedDay> days) {
    final byMonth = <String, List<PlannedDay>>{};
    for (final d in days) {
      byMonth.putIfAbsent(d.dayKey.substring(0, 7), () => []).add(d);
    }
    final months = byMonth.keys.toList()..sort();
    return [
      for (final m in months.reversed) (month: m, days: byMonth[m]!..sort((a, b) => a.dayKey.compareTo(b.dayKey))),
    ];
  }

  /// 章名：第一章（最早的月份）是「出發」；跨年時才寫年份。
  static String chapterTitle(String month, {required bool first, required bool withYear, required AgeTone tone}) {
    final date = dateOfDayKey('$month-01');
    final values = {'y': '${date.year}', 'm': '${date.month}'};
    final line = switch ((first, withYear)) {
      (true, false) => PathCopy.chapterFirst,
      (true, true) => PathCopy.chapterFirstWithYear,
      (false, false) => PathCopy.chapter,
      (false, true) => PathCopy.chapterWithYear,
    };
    return line.fill(tone, values);
  }

  /// 一章裡每個地方的中心：一列 [TrailConfig.mapPerRow] 個，來回蛇行，像一條彎彎的路。
  static List<Offset> placeCenters(int n, double width) {
    const per = TrailConfig.mapPerRow;
    final cell = width / per;
    return [
      for (var i = 0; i < n; i++)
        () {
          final row = i ~/ per;
          final col = row.isEven ? i % per : per - 1 - i % per;
          // 同一列裡輕輕上下起伏（固定的，不看任何資料）。
          final wave = math.sin((col + row) * TrailConfig.mapWaveStep) * TrailConfig.mapRowHeight * TrailConfig.mapWaveFraction;
          return Offset((col + 0.5) * cell, (row + 0.5) * TrailConfig.mapRowHeight + wave);
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final list = chapters(days);
    final years = {for (final c in list) c.month.substring(0, 4)};
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, c) in list.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpace.l),
          Text(
            chapterTitle(c.month, first: i == list.length - 1, withYear: years.length > 1, tone: tone),
            key: ValueKey('map-chapter-${c.month}'),
            style: text.titleMedium,
          ),
          const SizedBox(height: AppSpace.s),
          _ChapterMap(month: c.month, days: c.days, tone: tone),
        ],
      ],
    );
  }
}

class _ChapterMap extends StatelessWidget {
  const _ChapterMap({required this.month, required this.days, required this.tone});
  final String month;
  final List<PlannedDay> days;
  final AgeTone tone;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final centers = MapTrail.placeCenters(days.length, width);
        final rows = (days.length / TrailConfig.mapPerRow).ceil();
        final height = rows * TrailConfig.mapRowHeight + AppSpace.s;
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            width: width,
            height: height,
            color: AppColors.mapParchment,
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _MapPainter(centers, month.hashCode))),
                for (final (i, day) in days.indexed)
                  Positioned(
                    left: centers[i].dx - TrailConfig.mapPlaceSize / 2,
                    top: centers[i].dy - TrailConfig.mapPlaceSize / 2,
                    child: TrailMark(day: day, tone: tone, kind: 'place'),
                  ),
              ],
            ),
          ),
        );
      });
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.centers, this.seed);
  final List<Offset> centers;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    // 地圖上的小山、小樹（只是風景：依月份固定，不代表任何事）。
    final r = math.Random(seed);
    final hill = Paint()..color = AppColors.mapHill;
    final tree = Paint()..color = AppColors.leaf.withValues(alpha: 0.35);
    const w = TrailConfig.mapHillHalfWidth, h = TrailConfig.mapHillHeight;
    for (var i = 0; i < (size.width * size.height / TrailConfig.mapSceneryArea).round(); i++) {
      final p = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
      if (r.nextBool()) {
        canvas.drawPath(
          Path()
            ..moveTo(p.dx - w, p.dy + h / 2)
            ..quadraticBezierTo(p.dx, p.dy - h, p.dx + w, p.dy + h / 2)
            ..close(),
          hill,
        );
      } else {
        canvas.drawCircle(p, TrailConfig.mapTreeRadius, tree);
      }
    }
    if (centers.length < 2) return;
    // 虛線的路：照日期一路接下去，沒有斷掉的地方。
    final path = Path()..moveTo(centers.first.dx, centers.first.dy);
    for (final c in centers.skip(1)) {
      path.lineTo(c.dx, c.dy);
    }
    final dash = Paint()
      ..color = AppColors.mapRoute
      ..strokeWidth = TrailConfig.mapRouteWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += TrailConfig.mapDashPeriod) {
        canvas.drawPath(metric.extractPath(d, math.min(d + TrailConfig.mapDash, metric.length)), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.seed != seed || !listEquals(old.centers, centers);
}
