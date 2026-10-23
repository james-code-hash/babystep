import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bubu_inputs.dart';

/// 步步的表情只有這六種（C10）。沒有難過、生病、虛弱。
enum BubuExpression { happy, curious, caring, calm, surprised, relaxed }

/// 畫出步步。外觀只吃（裝扮、時間）——不讀任何計畫或回顧資料（底線 2）。
///
/// TODO(build-b): CustomPainter、`look(DressUp, DateTime)`、季節變化。
class BubuView extends ConsumerWidget {
  const BubuView({super.key, this.expression = BubuExpression.calm, this.size = 160, this.thinking = false});

  final BubuExpression expression;
  final double size;

  /// 等 LLM 時的「在想」動畫。
  final bool thinking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(bubuDressUpProvider);
    ref.watch(clockProvider);
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFF6E7C8), shape: BoxShape.circle),
        child: Center(child: Text(thinking ? '…' : '•ᴗ•', style: TextStyle(fontSize: size / 5))),
      ),
    );
  }
}
