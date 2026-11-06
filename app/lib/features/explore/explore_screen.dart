import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bubu/bubu_view.dart';
import '../../bubu/surprise.dart';
import '../../copy/line.dart';
import '../../copy/explore.dart';
import '../../copy/surprise.dart';
import '../../core/clock.dart';
import '../../core/config.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../providers.dart';

/// 今天的小疑問：只看日期（第幾天），跟孩子做了什麼無關。
int curioIndexFor(DateTime now) {
  final day = DateTime.utc(now.year, now.month, now.day);
  return day.difference(DateTime.utc(1970)).inDays % ExploreCopy.curios.length;
}

/// 探索角（企劃書模組五）：每日一個小疑問、有些日子的驚喜盒、塗鴉送給步步。
///
/// 刻意沒有：對錯、分數、看過幾題、「完成探索」。這一頁不讀計畫、回顧、筆記，也不寫任何東西。
/// 驚喜盒哪天出現只看日期（[surpriseBoxOn]），不是做完什麼的獎勵。
class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    final text = Theme.of(context).textTheme;
    final box = surpriseBoxOn(ref.watch(clockProvider).now());
    return Scaffold(
      appBar: AppBar(title: Text(ExploreCopy.title.of(tone))),
      body: SafeArea(
        child: AdaptiveFrame(
          child: ListView(
            key: const ValueKey('explore-list'),
            padding: const EdgeInsets.all(AppSpace.m),
            children: [
              Text(ExploreCopy.intro.of(tone), style: text.bodyMedium?.copyWith(color: AppColors.inkSoft)),
              const SizedBox(height: AppSpace.m),
              _CurioCard(tone: tone),
              const SizedBox(height: AppSpace.m),
              if (box) ...[
                _SurpriseCard(tone: tone),
                const SizedBox(height: AppSpace.m),
              ],
              _DrawCard(tone: tone),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 小疑問

class _CurioCard extends ConsumerStatefulWidget {
  const _CurioCard({required this.tone});
  final AgeTone tone;

  @override
  ConsumerState<_CurioCard> createState() => _CurioCardState();
}

class _CurioCardState extends ConsumerState<_CurioCard> {
  /// 「換一題」往後跳幾題（只在記憶體）。
  int _offset = 0;
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    final text = Theme.of(context).textTheme;
    final all = ExploreCopy.curios;
    final c = all[(curioIndexFor(ref.watch(clockProvider).now()) + _offset) % all.length];
    return Card(
      key: ValueKey('curio-${c.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ExploreCopy.curioTitle.of(tone), style: text.titleMedium),
            const SizedBox(height: AppSpace.s),
            Text(c.question.of(tone), key: const ValueKey('curio-question'), style: text.bodyLarge),
            const SizedBox(height: AppSpace.s),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _open
                  ? Column(
                      key: const ValueKey('curio-answer-box'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpace.s),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                          child: Text(c.answer.of(tone), key: const ValueKey('curio-answer'), style: text.bodyLarge),
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          ExploreCopy.curioTopic.fill(tone, {'topic': c.topic.of(tone)}),
                          style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
                        ),
                      ],
                    )
                  : Column(
                      key: const ValueKey('curio-closed'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ExploreCopy.curioThink.of(tone),
                            style: text.bodyMedium?.copyWith(color: AppColors.inkSoft)),
                        const SizedBox(height: AppSpace.s),
                        FilledButton.tonal(
                          key: const ValueKey('curio-reveal'),
                          onPressed: () => setState(() => _open = true),
                          child: Text(ExploreCopy.curioReveal.of(tone)),
                        ),
                      ],
                    ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey('curio-another'),
                onPressed: () => setState(() {
                  _offset++;
                  _open = false;
                }),
                child: Text(ExploreCopy.curioAnother.of(tone)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 驚喜盒

class _SurpriseCard extends ConsumerStatefulWidget {
  const _SurpriseCard({required this.tone});
  final AgeTone tone;

  @override
  ConsumerState<_SurpriseCard> createState() => _SurpriseCardState();
}

class _SurpriseCardState extends ConsumerState<_SurpriseCard> {
  /// 打開後看到的（只在記憶體）。
  (Line, BubuExpression)? _inside;

  void _shake() => setState(() => _inside = pickSurprise(ref.read(randomProvider)));

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    final text = Theme.of(context).textTheme;
    final inside = _inside;
    return Card(
      key: const ValueKey('surprise-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(SurpriseCopy.boxTitle.of(tone), style: text.titleMedium),
            const SizedBox(height: AppSpace.s),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: inside == null
                  ? Column(
                      key: const ValueKey('surprise-closed'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(SurpriseCopy.boxHint.of(tone), style: text.bodyMedium?.copyWith(color: AppColors.inkSoft)),
                        const SizedBox(height: AppSpace.s),
                        FilledButton.tonalIcon(
                          key: const ValueKey('surprise-box'),
                          onPressed: _shake,
                          icon: const Icon(Icons.card_giftcard),
                          label: Text(SurpriseCopy.boxOpen.of(tone)),
                        ),
                      ],
                    )
                  : Row(
                      key: ValueKey('surprise-open-${inside.$1.lively}'),
                      children: [
                        BubuView(expression: inside.$2, size: 88),
                        const SizedBox(width: AppSpace.s),
                        Expanded(
                          child: Text(inside.$1.of(tone), key: const ValueKey('surprise-story'), style: text.bodyLarge),
                        ),
                      ],
                    ),
            ),
            if (inside != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey('surprise-again'),
                  onPressed: _shake,
                  child: Text(SurpriseCopy.boxAgain.of(tone)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 塗鴉牆

/// 一筆：顏色＋經過的點。
class _Stroke {
  _Stroke(this.color);
  final Color color;
  final points = <Offset>[];
}

/// 塗鴉的顏色（跟整體暖色紙感一致）。
const drawPalette = <Color>[
  AppColors.ink,
  AppColors.accent,
  AppColors.leaf,
  AppColors.sky,
  Color(0xFFD98BA8),
  Color(0xFFE8C35A),
];

class _DrawCard extends ConsumerStatefulWidget {
  const _DrawCard({required this.tone});
  final AgeTone tone;

  @override
  ConsumerState<_DrawCard> createState() => _DrawCardState();
}

class _DrawCardState extends ConsumerState<_DrawCard> {
  final _strokes = <_Stroke>[];
  Color _color = drawPalette.first;

  /// 步步收到畫時說的話（只在記憶體）。
  String? _thanks;

  void _start(Offset p) => setState(() {
        _strokes.add(_Stroke(_color)..points.add(p));
        _thanks = null;
      });

  void _extend(Offset p) => setState(() => _strokes.last.points.add(p));

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    final text = Theme.of(context).textTheme;
    final thanks = _thanks;
    return Card(
      key: const ValueKey('draw-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ExploreCopy.drawTitle.of(tone), style: text.titleMedium),
            Text(ExploreCopy.drawHint.of(tone), style: text.bodyMedium?.copyWith(color: AppColors.inkSoft)),
            const SizedBox(height: AppSpace.s),
            Semantics(
              label: ExploreCopy.drawCanvas.of(tone),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Container(
                  height: ExploreConfig.canvasHeight,
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.line)),
                  child: GestureDetector(
                    key: const ValueKey('draw-canvas'),
                    onPanStart: (d) => _start(d.localPosition),
                    onPanUpdate: (d) => _extend(d.localPosition),
                    child: CustomPaint(painter: _StrokesPainter(_strokes), size: Size.infinite),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s),
            Wrap(
              spacing: AppSpace.s,
              runSpacing: AppSpace.s,
              children: [
                for (final (i, c) in drawPalette.indexed)
                  Semantics(
                    button: true,
                    selected: c == _color,
                    label: ExploreCopy.drawColor.of(tone),
                    child: InkWell(
                      key: ValueKey('draw-color-$i'),
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _color = c),
                      child: Container(
                        width: AppConfig.minTapTarget,
                        height: AppConfig.minTapTarget,
                        alignment: Alignment.center,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: c == _color ? AppColors.ink : AppColors.line, width: 3),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.s),
            Row(
              children: [
                TextButton.icon(
                  key: const ValueKey('draw-clear'),
                  onPressed: _strokes.isEmpty ? null : () => setState(() {
                        _strokes.clear();
                        _thanks = null;
                      }),
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: Text(ExploreCopy.drawClear.of(tone)),
                ),
                const Spacer(),
                FilledButton.icon(
                  key: const ValueKey('draw-give'),
                  onPressed: _strokes.isEmpty
                      ? null
                      : () => setState(() => _thanks = ExploreCopy.drawThanks.pick(tone, ref.read(randomProvider))),
                  icon: const Icon(Icons.card_giftcard),
                  label: Text(ExploreCopy.drawGive.of(tone)),
                ),
              ],
            ),
            if (thanks != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s),
                child: Row(
                  children: [
                    const BubuView(expression: BubuExpression.happy, size: 72),
                    const SizedBox(width: AppSpace.s),
                    Expanded(child: Text(thanks, key: const ValueKey('draw-thanks'), style: text.bodyLarge)),
                  ],
                ),
              ),
            const SizedBox(height: AppSpace.xs),
            Text(ExploreCopy.drawKept.of(tone), style: text.bodySmall?.copyWith(color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}

class _StrokesPainter extends CustomPainter {
  _StrokesPainter(this.strokes);
  final List<_Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = ExploreConfig.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (s.points.length == 1) {
        canvas.drawCircle(s.points.first, ExploreConfig.strokeWidth / 2, paint..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (final p in s.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StrokesPainter old) => true;
}
