import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'bubu_expression.dart';
import 'look.dart';

/// 畫步步：圓滾滾、帶點貓／熊特徵的小生物（移植自原型的 SVG，viewBox 200×190）。
///
/// 畫布的邏輯座標是 [canvasUnits]×[canvasUnits]；步步本體用原型的 SVG 座標，
/// 往右下平移 [_bodyOffset]，上方留空間給帽子、四周留空間給季節小裝飾。
class BubuPainter extends CustomPainter {
  const BubuPainter({required this.look, required this.expression});

  final BubuLook look;
  final BubuExpression expression;

  static const double canvasUnits = 220;
  static const Offset _bodyOffset = Offset(10, 24);

  static const _ink = Color(0xFF3D3428);
  static const _white = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / canvasUnits;
    canvas.save();
    canvas.translate((size.width - canvasUnits * s) / 2, (size.height - canvasUnits * s) / 2);
    canvas.scale(s);

    _paintAmbientBack(canvas);
    canvas.save();
    canvas.translate(_bodyOffset.dx, _bodyOffset.dy);
    _paintBody(canvas);
    _paintNeck(canvas);
    _paintArms(canvas);
    _paintFace(canvas);
    _paintHat(canvas);
    canvas.restore();
    _paintAmbientFront(canvas);

    canvas.restore();
  }

  @override
  bool shouldRepaint(BubuPainter oldDelegate) =>
      oldDelegate.look != look || oldDelegate.expression != expression;

  // ── helpers ────────────────────────────────────────────────

  static Paint _fill(Color c, [double opacity = 1]) =>
      Paint()..color = c.withValues(alpha: c.a * opacity);

  static Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static Rect _oval(double cx, double cy, double rx, double ry) =>
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);

  static void _rotatedOval(Canvas canvas, double cx, double cy, double rx, double ry, double deg, List<Paint> paints) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(deg * math.pi / 180);
    for (final p in paints) {
      canvas.drawOval(_oval(0, 0, rx, ry), p);
    }
    canvas.restore();
  }

  Paint _bodyGradient(Rect r) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [look.palette.bodyLight, look.palette.body],
    ).createShader(r);

  // ── 本體 ───────────────────────────────────────────────────

  void _paintBody(Canvas canvas) {
    final p = look.palette;
    final outline = _stroke(p.outline, 4);

    // 影子
    canvas.drawOval(_oval(100, 184, 54, 7), _fill(_ink, 0.10));

    // 耳朵
    for (final cx in [58.0, 142.0]) {
      final r = Rect.fromCircle(center: Offset(cx, 42), radius: 20);
      canvas.drawOval(r, _bodyGradient(r));
      canvas.drawOval(r, outline);
      canvas.drawCircle(Offset(cx, 42), 9, _fill(p.belly));
    }

    // 身體
    final body = _oval(100, 108, 66, 62);
    canvas.drawOval(body, _bodyGradient(body));
    canvas.drawOval(body, outline);

    // 肚子
    canvas.drawOval(_oval(100, 128, 40, 34), _fill(p.belly));

    // 腳
    canvas.drawOval(_oval(76, 172, 17, 11), _fill(p.outline));
    canvas.drawOval(_oval(124, 172, 17, 11), _fill(p.outline));
  }

  void _paintArms(Canvas canvas) {
    final p = look.palette;
    final outline = _stroke(p.outline, 4);
    _rotatedOval(canvas, 40, 112, 14, 18, 20, [_fill(p.body), outline]);
    _rotatedOval(canvas, 160, 112, 14, 18, -20, [_fill(p.body), outline]);
  }

  // ── 臉 ─────────────────────────────────────────────────────

  void _paintFace(Canvas canvas) {
    final p = look.palette;
    final line = _stroke(_ink, 4);
    final ink = _fill(_ink);
    final shine = _fill(_white);

    void roundEyes({double r = 8.5, Offset shineShift = const Offset(2.5, -3)}) {
      for (final cx in [78.0, 122.0]) {
        canvas.drawCircle(Offset(cx, 96), r, ink);
        canvas.drawCircle(Offset(cx, 96) + shineShift, r * 0.35, shine);
      }
    }

    void cheeks({double scale = 1, double opacity = 0.8}) {
      canvas.drawOval(_oval(62, 108, 8 * scale, 5.5 * scale), _fill(p.cheek, opacity));
      canvas.drawOval(_oval(138, 108, 8 * scale, 5.5 * scale), _fill(p.cheek, opacity));
    }

    Path curve(double x0, double y0, double cx, double cy, double x1, double y1) => Path()
      ..moveTo(x0, y0)
      ..quadraticBezierTo(cx, cy, x1, y1);

    switch (expression) {
      case BubuExpression.happy:
        // 笑瞇瞇的 ^ ^ 眼，張嘴笑。
        canvas.drawPath(curve(70, 99, 78, 88, 86, 99), line);
        canvas.drawPath(curve(114, 99, 122, 88, 130, 99), line);
        cheeks(scale: 1.1, opacity: 0.9);
        final mouth = Path()
          ..moveTo(90, 107)
          ..quadraticBezierTo(100, 107, 110, 107)
          ..quadraticBezierTo(108, 120, 100, 120)
          ..quadraticBezierTo(92, 120, 90, 107)
          ..close();
        canvas.drawPath(mouth, ink);
        canvas.drawOval(_oval(100, 116, 5, 3), _fill(p.cheek));
      case BubuExpression.curious:
        // 眼睛往右上看，小小的「喔？」嘴。
        roundEyes(shineShift: const Offset(3.5, -3.5));
        cheeks();
        canvas.drawOval(_oval(102, 111, 4.5, 4), ink);
      case BubuExpression.caring:
        // 溫柔的眼神、微笑、臉頰紅一點。
        roundEyes(r: 8);
        cheeks(scale: 1.25, opacity: 0.9);
        canvas.drawPath(curve(93, 108, 100, 114, 107, 108), line);
      case BubuExpression.calm:
        // 原型的預設臉。
        roundEyes();
        cheeks();
        canvas.drawPath(curve(92, 108, 100, 116, 108, 108), line);
      case BubuExpression.surprised:
        // 眼睛睜得更圓，小圓嘴。
        roundEyes(r: 10);
        cheeks();
        canvas.drawOval(_oval(100, 113, 5.5, 6.5), ink);
      case BubuExpression.relaxed:
        // 原型「晚安」的瞇眼臉。
        canvas.drawPath(curve(70, 96, 78, 102, 86, 96), line);
        canvas.drawPath(curve(114, 96, 122, 102, 130, 96), line);
        cheeks();
        canvas.drawPath(curve(94, 110, 100, 114, 106, 110), line);
    }
  }

  // ── 帽子 ───────────────────────────────────────────────────

  void _paintHat(Canvas canvas) {
    switch (look.hat) {
      case 'leaf':
        final stem = _stroke(const Color(0xFF6E9A5E), 3);
        canvas.drawPath(Path()
          ..moveTo(100, 47)
          ..quadraticBezierTo(98, 38, 102, 30), stem);
        final leaf = Path()
          ..moveTo(102, 31)
          ..quadraticBezierTo(108, 12, 128, 14)
          ..quadraticBezierTo(124, 32, 102, 31)
          ..close();
        canvas.drawPath(leaf, _fill(const Color(0xFF8DB596)));
        canvas.drawPath(leaf, _stroke(const Color(0xFF6E9A5E), 2.5));
        canvas.drawPath(Path()
          ..moveTo(104, 29)
          ..quadraticBezierTo(114, 22, 122, 17), _stroke(const Color(0xFF6E9A5E), 1.5));
      case 'flower':
        const c = Offset(128, 50);
        final petal = _fill(const Color(0xFFF6A5B7));
        for (var i = 0; i < 5; i++) {
          final a = i * 2 * math.pi / 5 - math.pi / 2;
          canvas.drawCircle(c + Offset(math.cos(a) * 8, math.sin(a) * 8), 6.5, petal);
        }
        canvas.drawCircle(c, 5.5, _fill(const Color(0xFFF7D774)));
      case 'beanie':
        const knit = Color(0xFFE48A6E);
        final dome = Path()
          ..moveTo(46, 72)
          ..cubicTo(46, 22, 154, 22, 154, 72)
          ..close();
        canvas.drawPath(dome, _fill(knit));
        final band = RRect.fromRectAndRadius(const Rect.fromLTWH(42, 62, 116, 16), const Radius.circular(8));
        canvas.drawRRect(band, _fill(const Color(0xFFF2B49E)));
        final rib = _stroke(knit, 2);
        for (var x = 52.0; x <= 148; x += 12) {
          canvas.drawLine(Offset(x, 65), Offset(x, 75), rib);
        }
        canvas.drawCircle(const Offset(100, 26), 10, _fill(const Color(0xFFFFF4E6)));
      case 'straw':
        const straw = Color(0xFFEAC97E);
        const strawDark = Color(0xFFC9A55A);
        canvas.drawOval(_oval(100, 58, 80, 15), _fill(straw));
        canvas.drawOval(_oval(100, 58, 80, 15), _stroke(strawDark, 2.5));
        final crown = Path()
          ..moveTo(66, 58)
          ..cubicTo(64, 22, 136, 22, 134, 58)
          ..close();
        canvas.drawPath(crown, _fill(straw));
        canvas.drawPath(crown, _stroke(strawDark, 2.5));
        canvas.drawRect(const Rect.fromLTWH(66, 46, 68, 7), _fill(const Color(0xFF9CC3D5)));
      case 'bucket':
        const cloth = Color(0xFF9CC3D5);
        const clothDark = Color(0xFF6F9DB3);
        final brim = Path()
          ..moveTo(50, 66)
          ..lineTo(150, 66)
          ..lineTo(160, 78)
          ..quadraticBezierTo(100, 86, 40, 78)
          ..close();
        canvas.drawPath(brim, _fill(cloth));
        canvas.drawPath(brim, _stroke(clothDark, 2.5));
        final top = Path()
          ..moveTo(58, 67)
          ..cubicTo(58, 26, 142, 26, 142, 67)
          ..close();
        canvas.drawPath(top, _fill(cloth));
        canvas.drawPath(top, _stroke(clothDark, 2.5));
      default:
        break; // 'none'
    }
  }

  // ── 脖子 ───────────────────────────────────────────────────

  void _paintNeck(Canvas canvas) {
    switch (look.neck) {
      case 'scarf':
        const red = Color(0xFFE8836B);
        final band = Path()
          ..moveTo(40, 118)
          ..quadraticBezierTo(100, 134, 160, 118)
          ..lineTo(158, 132)
          ..quadraticBezierTo(100, 148, 42, 132)
          ..close();
        canvas.drawPath(band, _fill(red));
        final tail = RRect.fromRectAndRadius(const Rect.fromLTWH(118, 132, 15, 30), const Radius.circular(5));
        canvas.drawRRect(tail, _fill(const Color(0xFFD9705A)));
        final stripe = _stroke(const Color(0xFFFBE3D6), 2);
        canvas.drawLine(const Offset(120, 150), const Offset(131, 150), stripe);
      case 'bow':
        const pink = Color(0xFFF2A0B3);
        final left = Path()
          ..moveTo(100, 130)
          ..lineTo(82, 120)
          ..quadraticBezierTo(78, 130, 82, 140)
          ..close();
        final right = Path()
          ..moveTo(100, 130)
          ..lineTo(118, 120)
          ..quadraticBezierTo(122, 130, 118, 140)
          ..close();
        canvas.drawPath(left, _fill(pink));
        canvas.drawPath(right, _fill(pink));
        canvas.drawCircle(const Offset(100, 130), 5, _fill(const Color(0xFFE07F96)));
      case 'bell':
        final collar = Path()
          ..moveTo(52, 122)
          ..quadraticBezierTo(100, 136, 148, 122);
        canvas.drawPath(collar, _stroke(const Color(0xFFE48A6E), 5));
        canvas.drawCircle(const Offset(100, 138), 8, _fill(const Color(0xFFF2C94C)));
        canvas.drawCircle(const Offset(100, 138), 8, _stroke(const Color(0xFFC79A2E), 2));
        canvas.drawLine(const Offset(100, 139), const Offset(100, 145), _stroke(const Color(0xFFC79A2E), 2));
      case 'bandana':
        const teal = Color(0xFF8DB596);
        final tri = Path()
          ..moveTo(48, 120)
          ..quadraticBezierTo(100, 134, 152, 120)
          ..lineTo(100, 158)
          ..close();
        canvas.drawPath(tri, _fill(teal));
        final dot = _fill(const Color(0xFFF4FBF5));
        for (final o in const [Offset(86, 134), Offset(114, 134), Offset(100, 146)]) {
          canvas.drawCircle(o, 2.5, dot);
        }
      default:
        break; // 'none'
    }
  }

  // ── 季節與時段的小裝飾（不在步步身上，只在旁邊）────────────

  void _paintAmbientBack(Canvas canvas) {
    if (look.ambient.contains(Ambient.sunsetGlow)) {
      final r = Rect.fromCircle(center: const Offset(110, 140), radius: 100);
      canvas.drawCircle(
        r.center,
        100,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0x33F2A65A), Color(0x00F2A65A)]).createShader(r),
      );
    }
    if (look.ambient.contains(Ambient.moon)) {
      final moon = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: const Offset(196, 26), radius: 13)),
        Path()..addOval(Rect.fromCircle(center: const Offset(203, 21), radius: 11)),
      );
      canvas.drawPath(moon, _fill(const Color(0xFFF7E3A1)));
    }
    if (look.ambient.contains(Ambient.stars)) {
      final star = _fill(const Color(0xFFF7E3A1));
      for (final o in const [Offset(22, 22), Offset(168, 12), Offset(210, 96), Offset(12, 120)]) {
        canvas.drawCircle(o, 2.2, star);
      }
    }
  }

  void _paintAmbientFront(Canvas canvas) {
    for (final a in look.ambient) {
      switch (a) {
        case Ambient.petals:
          final petal = _fill(const Color(0xFFF6BFCB));
          _rotatedOval(canvas, 24, 52, 5, 3, 30, [petal]);
          _rotatedOval(canvas, 200, 78, 5, 3, -20, [petal]);
          _rotatedOval(canvas, 18, 168, 4.5, 2.8, 60, [petal]);
        case Ambient.sparkle:
          for (final (o, r) in const [(Offset(24, 44), 7.0), (Offset(198, 66), 6.0), (Offset(204, 168), 5.0)]) {
            _sparkle(canvas, o, r);
          }
        case Ambient.leaf:
          _leaf(canvas, const Offset(22, 58), 25);
          _leaf(canvas, const Offset(200, 160), -35);
        case Ambient.snowflake:
          for (final (o, r) in const [(Offset(22, 46), 6.0), (Offset(200, 70), 5.0), (Offset(16, 162), 4.5)]) {
            _snowflake(canvas, o, r);
          }
        case Ambient.sunsetGlow:
        case Ambient.moon:
        case Ambient.stars:
          break; // 畫在背後
      }
    }
  }

  static void _sparkle(Canvas canvas, Offset c, double r) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(p, _fill(const Color(0xFFF7D774)));
  }

  static void _leaf(Canvas canvas, Offset c, double deg) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(deg * math.pi / 180);
    final p = Path()
      ..moveTo(-8, 0)
      ..quadraticBezierTo(0, -7, 8, 0)
      ..quadraticBezierTo(0, 7, -8, 0)
      ..close();
    canvas.drawPath(p, _fill(const Color(0xFFE8A35C)));
    canvas.drawLine(const Offset(-8, 0), const Offset(7, 0), _stroke(const Color(0xFFC07A3A), 1.2));
    canvas.restore();
  }

  static void _snowflake(Canvas canvas, Offset c, double r) {
    final p = _stroke(const Color(0xFFB7D5E6), 1.6);
    for (var i = 0; i < 3; i++) {
      final a = i * math.pi / 3;
      final d = Offset(math.cos(a) * r, math.sin(a) * r);
      canvas.drawLine(c - d, c + d, p);
    }
  }
}

/// 「在想」泡泡的三個點。[phase] 是 0–1 的動畫進度；動畫關閉時固定在 null（三點都亮）。
class ThinkingDotsPainter extends CustomPainter {
  const ThinkingDotsPainter({this.phase});

  final double? phase;

  @override
  void paint(Canvas canvas, Size size) {
    final bubble = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2));
    canvas.drawRRect(bubble, Paint()..color = const Color(0xFFFFFDF8));
    canvas.drawRRect(
      bubble,
      Paint()
        ..color = const Color(0xFFE8DCC8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final r = size.height * 0.12;
    for (var i = 0; i < 3; i++) {
      final x = size.width * (0.28 + i * 0.22);
      var alpha = 0.85;
      final ph = phase;
      if (ph != null) {
        // 每個點輪流亮一下。
        final t = (ph - i / 3) % 1.0;
        alpha = 0.3 + 0.6 * math.max(0, math.sin(t * math.pi));
      }
      canvas.drawCircle(
        Offset(x, size.height / 2),
        r,
        Paint()..color = const Color(0xFF7A6E5F).withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(ThinkingDotsPainter oldDelegate) => oldDelegate.phase != phase;
}
