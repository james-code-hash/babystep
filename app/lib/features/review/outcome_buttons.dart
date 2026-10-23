import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../copy/line.dart';
import '../../copy/review.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../providers.dart';

/// 回顧的三個狀態按鈕（底線 4、C10）。
///
/// 三顆按鈕：同尺寸（[Expanded] 平分＋同一個高度）、同底色 [AppColors.outcomeButton]、
/// 同字重、同字級，只用圖示區分；順序固定；沒有預設選取；不用紅綠。
/// 選了之後的外框也一樣，不因為選了哪一個而不同。
class OutcomeButtons extends ConsumerWidget {
  const OutcomeButtons({super.key, required this.onChanged, this.selected});

  final ValueChanged<Outcome> onChanged;

  /// 目前選的（null = 還沒選，沒有預設值）。
  final Outcome? selected;

  /// 固定順序。
  static const order = [Outcome.done, Outcome.partly, Outcome.notToday];

  static const emoji = {Outcome.done: '🌟', Outcome.partly: '🌗', Outcome.notToday: '🌙'};

  static const labels = <Outcome, Line>{
    Outcome.done: ReviewCopy.outcomeDone,
    Outcome.partly: ReviewCopy.outcomePartly,
    Outcome.notToday: ReviewCopy.outcomeNotToday,
  };

  static ValueKey<String> keyFor(Outcome o) => ValueKey('outcome-${o.name}');

  /// 三顆共用的文字樣式。
  static const labelStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.3);

  static const double height = 104;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, o) in order.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpace.s),
            Expanded(
              child: _OutcomeButton(
                key: keyFor(o),
                emoji: emoji[o]!,
                label: labels[o]!.of(tone),
                selected: selected == o,
                onTap: () => onChanged(o),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OutcomeButton extends StatelessWidget {
  const _OutcomeButton({
    super.key,
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.button);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: SizedBox.expand(
        child: Material(
          color: AppColors.outcomeButton,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            // 選了的那顆有同一種外框；沒選的外框透明（尺寸不變）。
            side: BorderSide(color: selected ? AppColors.ink : Colors.transparent, width: 2),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppConfig.minTapTarget),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 30)),
                    const SizedBox(height: AppSpace.xs),
                    Text(label, textAlign: TextAlign.center, style: OutcomeButtons.labelStyle),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
