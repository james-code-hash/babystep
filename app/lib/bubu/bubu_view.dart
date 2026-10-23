import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../copy/bubu.dart';
import '../copy/line.dart';
import 'bubu_config.dart';
import 'bubu_expression.dart';
import 'bubu_inputs.dart';
import 'bubu_painter.dart';
import 'look.dart';

export 'bubu_expression.dart';

/// 畫出步步。外觀只吃（裝扮、時間）——不讀任何計畫或回顧資料（底線 2）。
///
/// 動畫的選擇（見 docs/decisions.md）：
/// - 預設**靜態**，沒有無限動畫，所以掛了步步的畫面在測試裡仍可以 `pumpAndSettle`。
/// - [thinking] 為 true 時才有重複動畫（三個點輪流亮）；測試請用 `pump(duration)`。
/// - [breathe] 為 true 時才有呼吸動畫（畫面自己選擇要不要）；同樣要用 `pump(duration)`。
/// - 系統「減少動態效果」（`MediaQuery.disableAnimations`）開著時，一律不動。
class BubuView extends ConsumerWidget {
  const BubuView({
    super.key,
    this.expression = BubuExpression.calm,
    this.size = 160,
    this.thinking = false,
    this.breathe = false,
  });

  final BubuExpression expression;
  final double size;

  /// 等 LLM 時的「在想」動畫。
  final bool thinking;

  /// 輕輕的呼吸動畫（無限循環，預設關）。
  final bool breathe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dressUp = ref.watch(bubuDressUpProvider);
    final now = ref.watch(clockProvider).now();
    final tone = ref.watch(toneProvider);
    final bubuLook = look(dressUp, now);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    Widget body = CustomPaint(
      size: Size.square(size),
      painter: BubuPainter(look: bubuLook, expression: expression),
    );
    if (breathe && !reduceMotion) body = _Breathing(child: body);

    final label = (thinking ? BubuCopy.semanticsThinking : semanticsFor(expression)).of(tone);

    return Semantics(
      label: label,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: body),
            if (thinking)
              Positioned(
                right: 0,
                top: size * 0.02,
                width: size * 0.3,
                height: size * 0.15,
                child: _ThinkingDots(animate: !reduceMotion),
              ),
          ],
        ),
      ),
    );
  }
}

/// 每個表情的讀螢幕描述。
Line semanticsFor(BubuExpression e) => switch (e) {
      BubuExpression.happy => BubuCopy.semanticsHappy,
      BubuExpression.curious => BubuCopy.semanticsCurious,
      BubuExpression.caring => BubuCopy.semanticsCaring,
      BubuExpression.calm => BubuCopy.semanticsCalm,
      BubuExpression.surprised => BubuCopy.semanticsSurprised,
      BubuExpression.relaxed => BubuCopy.semanticsRelaxed,
    };

class _Breathing extends StatefulWidget {
  const _Breathing({required this.child});
  final Widget child;

  @override
  State<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<_Breathing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: BubuConfig.breatheCycleMs),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_c.value);
          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(1 + 0.012 * t, 1 + 0.025 * t, 1),
            child: child,
          );
        },
        child: widget.child,
      );
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots({required this.animate});
  final bool animate;

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: BubuConfig.thinkingCycleMs),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(_ThinkingDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.animate && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: ThinkingDotsPainter(phase: widget.animate ? _c.value : null),
        ),
      );
}
