import 'package:flutter/material.dart';

import '../../copy/parent.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';

/// 數字鍵盤＋圓點。輸入滿 [AppConfig.parentPinLength] 位就呼叫 [onComplete]。
class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.entered, required this.onDigit, required this.onBackspace});

  /// 目前輸入了幾位（畫面只顯示圓點）。
  final int entered;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget key(String d) => _PadButton(
          key: ValueKey('pin-key-$d'),
          onTap: () => onDigit(d),
          child: Text(d, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.ink)),
        );
    Widget row(List<String> ds) => Row(mainAxisSize: MainAxisSize.min, children: [for (final d in ds) key(d)]);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          key: const ValueKey('pin-dots'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < AppConfig.parentPinLength; i++)
              Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: AppSpace.s),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < entered ? AppColors.ink : Colors.transparent,
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.l),
        row(['1', '2', '3']),
        row(['4', '5', '6']),
        row(['7', '8', '9']),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: _PadButton.size + 2 * _PadButton.gap),
            key('0'),
            _PadButton(
              key: const ValueKey('pin-backspace'),
              onTap: entered > 0 ? onBackspace : null,
              child: Icon(
                Icons.backspace_outlined,
                color: AppColors.inkSoft,
                semanticLabel: ParentCopy.pinBackspace.of(AgeTone.concise),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({super.key, required this.onTap, required this.child});
  static const double size = 72;
  static const double gap = 8;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(gap),
        child: SizedBox.square(
          dimension: size,
          child: Material(
            color: AppColors.card,
            shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
            child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Center(child: child)),
          ),
        ),
      );
}
