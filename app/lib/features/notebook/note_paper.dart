import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 筆記本一頁的紙感外框：橫線、左邊一條紅褐色邊線、微微手寫感的字。
/// 回顧畫面的「步步學到」與筆記本共用。
class NotePaper extends StatelessWidget {
  const NotePaper({super.key, required this.child, this.header, this.footer});

  final Widget child;
  final Widget? header;
  final Widget? footer;

  static const double lineGap = 30;
  static const _margin = Color(0xFFE6B8A2);

  /// 筆記內文的字型樣式（行高對齊橫線）。
  static const TextStyle textStyle = TextStyle(
    fontSize: 19,
    height: lineGap / 19,
    color: AppColors.ink,
    letterSpacing: 0.5,
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: CustomPaint(
          painter: const _RuledPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl + AppSpace.s, AppSpace.m, AppSpace.m, AppSpace.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (header != null) ...[header!, const SizedBox(height: AppSpace.xs)],
                DefaultTextStyle.merge(style: textStyle, child: child),
                if (footer != null) ...[const SizedBox(height: AppSpace.s), footer!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RuledPainter extends CustomPainter {
  const _RuledPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rule = Paint()
      ..color = AppColors.line.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var y = AppSpace.m + NotePaper.lineGap; y < size.height; y += NotePaper.lineGap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
    final margin = Paint()
      ..color = NotePaper._margin
      ..strokeWidth = 1.5;
    const x = AppSpace.xl - AppSpace.xs;
    canvas.drawLine(const Offset(x, 0), Offset(x, size.height), margin);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
