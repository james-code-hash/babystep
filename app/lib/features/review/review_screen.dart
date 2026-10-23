import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bubu/bubu_view.dart';
import '../../copy/common.dart';
import '../../copy/review.dart';
import '../../core/config.dart';
import '../../core/layout.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import '../../safety/safety_gate.dart';
import '../notebook/note_paper.dart';
import 'outcome_buttons.dart';
import 'review_controller.dart';

/// 晚上回顧：開場 → 每件事的狀態 → 歷程問題 → 步步學到 → 要不要記 → 結束。
///
/// 「今天沒做」走的步驟、看到的畫面份量和「做到了」完全一樣（底線 4）。
class ReviewFlowScreen extends ConsumerStatefulWidget {
  const ReviewFlowScreen({super.key});

  @override
  ConsumerState<ReviewFlowScreen> createState() => _ReviewFlowScreenState();
}

class _ReviewFlowScreenState extends ConsumerState<ReviewFlowScreen> {
  final _text = TextEditingController();
  bool _writing = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) ref.read(reviewControllerProvider.notifier).start();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  ReviewController get _ctrl => ref.read(reviewControllerProvider.notifier);

  void _goHome() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go(Routes.home);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  /// 每一段孩子的話（chip 或自己寫的）都先過安全檢查（底線 9）。
  Future<void> _submit(String words) async {
    if (_checking || words.trim().isEmpty) return;
    setState(() => _checking = true);
    final ok = await passesSafetyCheck(context, ref, words);
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) {
      await _ctrl.answer(words);
    } else {
      await _ctrl.stopForSafety();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = ref.watch(toneProvider);
    final s = ref.watch(reviewControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(ReviewCopy.title.of(tone))),
      body: SafeArea(
        child: KeyedSubtree(key: ValueKey('review-stage-${s.stage.name}-${s.index}'), child: _body(context, tone, s)),
      ),
    );
  }

  Widget _body(BuildContext context, AgeTone tone, ReviewState s) {
    final hero = Layout.bubu(context, BubuSlot.hero);
    switch (s.stage) {
      case ReviewStage.loading:
        return const SizedBox.shrink();
      case ReviewStage.noPlans:
        return _Centered(
          bubu: BubuView(expression: BubuExpression.calm, size: hero),
          line: ReviewCopy.noPlans.of(tone),
          actions: [_Primary(key: const ValueKey('review-back'), label: ReviewCopy.backHome.of(tone), onTap: _goHome)],
        );
      case ReviewStage.alreadyEnded:
        return _Centered(
          bubu: BubuView(expression: BubuExpression.relaxed, size: hero),
          line: ReviewCopy.alreadyEnded.of(tone),
          actions: [_Primary(key: const ValueKey('review-back'), label: ReviewCopy.backHome.of(tone), onTap: _goHome)],
        );
      case ReviewStage.opening:
        return _Centered(
          bubu: BubuView(expression: BubuExpression.happy, size: hero),
          line: s.opening!.of(tone),
          actions: [
            _Primary(key: const ValueKey('review-start'), label: ReviewCopy.start.of(tone), onTap: _ctrl.begin),
          ],
        );
      case ReviewStage.outcomes:
        return _outcomeStep(context, tone, s);
      case ReviewStage.question:
        return _questionStep(context, tone, s);
      case ReviewStage.learning:
        return _Centered(
          bubu: BubuView(expression: BubuExpression.curious, size: hero, thinking: s.thinking),
          line: s.thinking ? ReviewCopy.thinking.of(tone) : null,
          lineKey: const ValueKey('review-thinking'),
          actions: const [],
        );
      case ReviewStage.lesson:
        return _lessonStep(context, tone, s);
      case ReviewStage.ending:
        return _Centered(
          bubu: BubuView(expression: BubuExpression.relaxed, size: hero),
          line: (s.endedBySafety ? ReviewCopy.goodnight : ReviewCopy.ending).of(tone),
          lineKey: const ValueKey('review-ending'),
          actions: [_Primary(key: const ValueKey('review-end-ok'), label: ReviewCopy.endOk.of(tone), onTap: _goHome)],
        );
    }
  }

  Widget _outcomeStep(BuildContext context, AgeTone tone, ReviewState s) {
    final plan = s.currentPlan!;
    final text = Theme.of(context).textTheme;
    return _Scroll(
      // 三種狀態的回應都用同一個表情、同一個大小（底線 4）。
      side: (context, wide) => _SideBubu(expression: BubuExpression.curious, wide: wide),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.m),
            child: Row(
              children: [
                Text(plan.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: AppSpace.m),
                Expanded(
                  child: Text(plan.ifThen, key: const ValueKey('review-plan'), style: text.titleMedium),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.m),
        Text(ReviewCopy.howDidItGo.of(tone), style: text.bodyLarge, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.m),
        OutcomeButtons(selected: s.currentOutcome, onChanged: _ctrl.choose),
        const SizedBox(height: AppSpace.l),
        if (s.response != null) ...[
          _BubuSays(text: s.response!.of(tone), key: const ValueKey('review-response')),
          const SizedBox(height: AppSpace.l),
          Center(
            child: _Primary(key: const ValueKey('review-next'), label: CommonCopy.next.of(tone), onTap: _ctrl.next),
          ),
        ],
      ],
    );
  }

  Widget _questionStep(BuildContext context, AgeTone tone, ReviewState s) {
    final text = Theme.of(context).textTheme;
    final question = _BubuSays(text: s.question!.of(tone), key: const ValueKey('review-question'));
    return _Scroll(
      gap: AppSpace.l,
      side: (context, wide) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SideBubu(expression: BubuExpression.curious, wide: wide),
          const SizedBox(height: AppSpace.m),
          question,
        ],
      ),
      children: [
        Wrap(
          spacing: AppSpace.s,
          runSpacing: AppSpace.s,
          alignment: WrapAlignment.center,
          children: [
            for (final (i, c) in s.chips.indexed)
              ActionChip(
                key: ValueKey('review-chip-$i'),
                label: Text(c.of(tone)),
                onPressed: _checking ? null : () => _submit(c.of(tone)),
              ),
            ActionChip(
              key: const ValueKey('review-write'),
              avatar: const Icon(Icons.edit_outlined, size: 18),
              label: Text(ReviewCopy.writeOwn.of(tone)),
              onPressed: () => setState(() => _writing = true),
            ),
          ],
        ),
        if (_writing) ...[
          const SizedBox(height: AppSpace.m),
          TextField(
            key: const ValueKey('review-text'),
            controller: _text,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            inputFormatters: [LengthLimitingTextInputFormatter(AppConfig.maxReflectionChars)],
            style: text.bodyLarge,
            decoration: InputDecoration(
              hintText: ReviewCopy.answerHint.of(tone),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
            ),
          ),
          const SizedBox(height: AppSpace.s),
          Center(
            child: _Primary(
              key: const ValueKey('review-send'),
              label: ReviewCopy.send.of(tone),
              onTap: _checking ? null : () => _submit(_text.text),
            ),
          ),
        ],
        const SizedBox(height: AppSpace.l),
        Center(
          child: TextButton(
            key: const ValueKey('review-skip'),
            onPressed: _checking ? null : () => _ctrl.answer(null),
            child: Text(ReviewCopy.skipQuestion.of(tone)),
          ),
        ),
      ],
    );
  }

  Widget _lessonStep(BuildContext context, AgeTone tone, ReviewState s) {
    final lesson = s.lesson!;
    final text = Theme.of(context).textTheme;
    return _Scroll(
      side: (context, wide) => _SideBubu(expression: BubuExpression.happy, wide: wide),
      gap: AppSpace.m,
      children: [
        NotePaper(
          header: Text(ReviewCopy.learnedTitle.of(tone), style: text.titleMedium),
          child: Text(lesson.text, key: const ValueKey('review-lesson')),
        ),
        const SizedBox(height: AppSpace.l),
        if (s.canSave) ...[
          Text(ReviewCopy.askSave.of(tone), style: text.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.m),
          // 兩個選項同尺寸、同樣式：不暗示哪一個比較「對」。
          Row(
            children: [
              Expanded(
                child: _Choice(
                  key: const ValueKey('review-save-yes'),
                  label: ReviewCopy.saveYes.of(tone),
                  onTap: () => _ctrl.decideSave(true),
                ),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: _Choice(
                  key: const ValueKey('review-save-no'),
                  label: ReviewCopy.saveNo.of(tone),
                  onTap: () => _ctrl.decideSave(false),
                ),
              ),
            ],
          ),
        ] else
          Center(
            child: _Primary(
              key: const ValueKey('review-continue'),
              label: ReviewCopy.continueOn.of(tone),
              onTap: () => _ctrl.decideSave(false),
            ),
          ),
      ],
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.bubu, required this.line, required this.actions, this.lineKey});

  final Widget bubu;
  final String? line;
  final Key? lineKey;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => AdaptiveFrame(
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            bubu,
            const SizedBox(height: AppSpace.l),
            if (line != null) _BubuSays(text: line!, key: lineKey),
            const SizedBox(height: AppSpace.l),
            ...actions,
          ],
        ),
      ),
    ),
  );
}

/// 步步說的一句話（對話泡泡）。
class _BubuSays extends StatelessWidget {
  const _BubuSays({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(AppSpace.m),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: AppColors.line),
    ),
    child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
  );
}

class _Primary extends StatelessWidget {
  const _Primary({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => FilledButton(onPressed: onTap, child: Text(label));
}

class _Choice extends StatelessWidget {
  const _Choice({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      backgroundColor: AppColors.card,
      side: const BorderSide(color: AppColors.line, width: 1.5),
      textStyle: Theme.of(context).textTheme.labelLarge,
    ),
    child: Text(label),
  );
}

/// 回顧每一步的內容都不長：全部一次建好（不用 lazy ListView），按鈕永遠在樹上。
/// 寬螢幕（平板橫放）時步步在旁邊一欄（[AdaptiveTwoPane]）。
class _Scroll extends StatelessWidget {
  const _Scroll({required this.side, required this.children, this.gap = AppSpace.m});
  final Widget Function(BuildContext context, bool wide) side;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) =>
      AdaptiveTwoPane(padding: const EdgeInsets.all(AppSpace.l), gap: gap, side: side, children: children);
}

/// 回顧各步驟上方（或旁邊）的步步：同一步驟裡大小固定，不因孩子的回答改變。
class _SideBubu extends StatelessWidget {
  const _SideBubu({required this.expression, required this.wide});
  final BubuExpression expression;
  final bool wide;

  @override
  Widget build(BuildContext context) => Center(
    child: BubuView(
      expression: expression,
      size: wide ? LayoutConfig.bubuSidePane : Layout.bubu(context, BubuSlot.review),
    ),
  );
}
