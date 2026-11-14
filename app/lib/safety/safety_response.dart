import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bubu/bubu_view.dart';
import '../copy/safety.dart';
import '../core/theme.dart';
import '../core/layout.dart';
import '../providers.dart';
import 'crisis_detector.dart';

/// 危機訊號的安全回應（docs/decisions.md C6、底線 9）。
///
/// - 全部是 `copy/safety.dart` 的預寫句子，不呼叫 LLM。
/// - 不存任何東西、不通知家長；孩子剛剛寫的字不會出現在這裡。
/// - 溫和、不驚嚇：步步是「關心」表情，沒有警示色、沒有倒數、只有一個「我知道了」。
/// - 專線來自 `assets/crisis_patterns.json`；沒有撥號套件，號碼放大顯示、可以長按複製。
class SafetyResponseScreen extends ConsumerWidget {
  const SafetyResponseScreen({super.key, this.category});

  /// null = 伺服器端攔下，不知道是哪一類，用通用版。
  final CrisisCategory? category;

  static Route<void> route(CrisisCategory? category) =>
      MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => SafetyResponseScreen(category: category));

  /// 顯示安全回應，等孩子按「我知道了」（或返回）才完成。
  static Future<void> show(BuildContext context, CrisisCategory? category) =>
      Navigator.of(context).push(route(category));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    final helplines = ref.watch(crisisDetectorProvider).helplines;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: AdaptiveFrame(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: BubuView(expression: BubuExpression.caring, size: Layout.bubu(context, BubuSlot.review)),
                ),
                const SizedBox(height: AppSpace.l),
                Text(SafetyCopy.opening(category).of(tone), style: text.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: AppSpace.m),
                Text(SafetyCopy.bridge(category).of(tone), style: text.bodyLarge, textAlign: TextAlign.center),
                const SizedBox(height: AppSpace.m),
                Text(SafetyCopy.trustedAdult.of(tone), style: text.bodyLarge, textAlign: TextAlign.center),
                const SizedBox(height: AppSpace.l),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.m),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(SafetyCopy.helplinesTitle.of(tone), style: text.titleMedium),
                        const SizedBox(height: AppSpace.xs),
                        Text(SafetyCopy.howToCall.of(tone), style: text.bodyMedium?.copyWith(color: AppColors.inkSoft)),
                        for (final h in helplines) _HelplineRow(helpline: h),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.m),
                Text(
                  SafetyCopy.notSaved.of(tone),
                  style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpace.l),
                Center(
                  child: FilledButton(
                    key: const Key('safety-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(SafetyCopy.close.of(tone)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HelplineRow extends StatelessWidget {
  const _HelplineRow({required this.helpline});
  final Helpline helpline;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 96, minHeight: 48),
            child: SelectableText(
              helpline.number,
              key: Key('helpline-${helpline.id}'),
              style: text.headlineSmall?.copyWith(color: AppColors.ink, letterSpacing: 1),
            ),
          ),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(helpline.name, style: text.titleMedium),
                Text(helpline.note, style: text.bodyMedium?.copyWith(color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
