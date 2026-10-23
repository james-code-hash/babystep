import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bubu/bubu_view.dart';
import '../../copy/common.dart';
import '../../copy/plan.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import 'plan_flow_controller.dart';
import 'plan_nav.dart';
import 'plan_steps.dart';

/// 早上排計畫：心情暖身 → 選 1–3 件事 →（每件）如果⋯我就⋯ →（每件，可跳過）為什麼 → 確認。
///
/// 今天已經聊完 → 只顯示一句平靜的話與回首頁。
class PlanFlowScreen extends ConsumerWidget {
  const PlanFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    final record = ref.watch(todayRecordProvider);
    final ended = record.value?.ended ?? false;
    final step = ref.watch(planFlowProvider.select((s) => s.step));
    final index = ref.watch(planFlowProvider.select((s) => s.index));

    Widget body;
    if (!record.hasValue) {
      body = const SizedBox.shrink();
    } else if (ended) {
      body = _EndedView(tone: tone);
    } else {
      body = switch (step) {
        PlanStep.mood => const MoodStep(),
        PlanStep.choose => const ChooseStep(),
        PlanStep.ifThen => IfThenStep(key: ValueKey('plan-ifthen-$index')),
        PlanStep.why => WhyStep(key: ValueKey('plan-why-$index')),
        PlanStep.confirm => const ConfirmStep(),
      };
    }

    void goBack() {
      if (ended || !ref.read(planFlowProvider.notifier).back()) leavePlanFlow(context);
    }

    return PopScope(
      canPop: ended || step == PlanStep.mood,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(planFlowProvider.notifier).back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(PlanCopy.title.of(tone)),
          leading: IconButton(
            key: const ValueKey('plan-back'),
            tooltip: CommonCopy.back.of(tone),
            icon: const Icon(Icons.arrow_back),
            onPressed: goBack,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: body),
          ),
        ),
      ),
    );
  }
}

class _EndedView extends StatelessWidget {
  const _EndedView({required this.tone});
  final AgeTone tone;

  @override
  Widget build(BuildContext context) => Padding(
        key: const ValueKey('plan-ended'),
        padding: const EdgeInsets.all(AppSpace.l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BubuView(expression: BubuExpression.relaxed, size: 140),
            const SizedBox(height: AppSpace.l),
            Text(PlanCopy.dayEnded.of(tone), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppSpace.l),
            OutlinedButton(
              key: const ValueKey('plan-ended-home'),
              onPressed: () => leavePlanFlow(context),
              child: Text(PlanCopy.backHome.of(tone)),
            ),
          ],
        ),
      );
}
