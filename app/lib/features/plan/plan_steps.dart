import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bubu/bubu_view.dart';
import '../../copy/common.dart';
import '../../copy/line.dart';
import '../../copy/plan.dart';
import '../../core/clock.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import '../../safety/safety_gate.dart';
import 'plan_flow_controller.dart';
import 'plan_nav.dart';

/// 孩子自己寫事情時可以挑的圖案（不是文字，不需要放 copy/）。
const customTaskEmojis = ['⭐', '📚', '🎨', '⚽', '🎵', '🧩', '🌱', '🐾', '🧸', '🚲'];

// ============================================================== 共用版面

/// 每一步的版面：小步步＋一句話、內容、底下的按鈕。
class _StepLayout extends StatelessWidget {
  const _StepLayout({
    required this.expression,
    required this.bubuSays,
    required this.content,
    this.actions = const [],
  });

  final BubuExpression expression;
  final String bubuSays;
  final List<Widget> content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(AppSpace.m),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BubuView(expression: expression, size: 88),
              const SizedBox(width: AppSpace.m),
              Expanded(child: _Bubble(text: bubuSays)),
            ],
          ),
          const SizedBox(height: AppSpace.l),
          ...content,
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpace.l),
            ...actions,
          ],
        ],
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('plan-bubble'),
        padding: const EdgeInsets.all(AppSpace.m),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpace.m, bottom: AppSpace.s),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.inkSoft)),
      );
}

class _Note extends StatelessWidget {
  const _Note(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpace.m),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft)),
      );
}

Widget _nextButton(BuildContext context, AgeTone tone, {required VoidCallback? onPressed, Line? label}) => Center(
      child: FilledButton(
        key: const ValueKey('plan-next'),
        onPressed: onPressed,
        child: Text((label ?? CommonCopy.next).of(tone)),
      ),
    );

/// 一行輸入框＋送出按鈕。送出前一定先過 [passesSafetyCheck]；不過就清掉，文字不被使用。
class _SafeTextEntry extends ConsumerStatefulWidget {
  const _SafeTextEntry({
    required this.fieldKey,
    required this.submitKey,
    required this.hint,
    required this.submitLabel,
    required this.maxChars,
    required this.onAccepted,
    this.initial = '',
  });

  final String fieldKey;
  final String submitKey;
  final String hint;
  final String submitLabel;
  final int maxChars;
  final String initial;

  /// 通過安全檢查的文字（已 trim、非空）。
  final Future<void> Function(String text) onAccepted;

  @override
  ConsumerState<_SafeTextEntry> createState() => _SafeTextEntryState();
}

class _SafeTextEntryState extends ConsumerState<_SafeTextEntry> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    final ok = await passesSafetyCheck(context, ref, text);
    if (!mounted) return;
    if (!ok) {
      _controller.clear();
      setState(() => _busy = false);
      return;
    }
    await widget.onAccepted(text);
    if (!mounted) return;
    _controller.clear();
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              key: ValueKey(widget.fieldKey),
              controller: _controller,
              maxLength: widget.maxChars,
              decoration: InputDecoration(hintText: widget.hint),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: AppSpace.s),
          OutlinedButton(
            key: ValueKey(widget.submitKey),
            onPressed: _busy ? null : _submit,
            child: Text(widget.submitLabel),
          ),
        ],
      );
}

// ============================================================== 1. 心情暖身

/// 心情只活在這個 State 裡：只用來決定步步回的一句話，不存、不傳、不匯出（C2）。
enum _Mood { happy, okay, tired, low, unsaid }

class MoodStep extends ConsumerStatefulWidget {
  const MoodStep({super.key});

  @override
  ConsumerState<MoodStep> createState() => _MoodStepState();
}

class _MoodStepState extends ConsumerState<MoodStep> {
  _Mood? _mood;

  static const _options = <(_Mood, String, Line)>[
    (_Mood.happy, '🌞', PlanCopy.moodHappy),
    (_Mood.okay, '🙂', PlanCopy.moodOkay),
    (_Mood.tired, '😪', PlanCopy.moodTired),
    (_Mood.low, '🌧️', PlanCopy.moodLow),
  ];

  Line _reply(_Mood m) => switch (m) {
        _Mood.happy => PlanCopy.moodHappyReply,
        _Mood.okay => PlanCopy.moodOkayReply,
        _Mood.tired => PlanCopy.moodTiredReply,
        _Mood.low => PlanCopy.moodLowReply,
        _Mood.unsaid => PlanCopy.moodSkipReply,
      };

  @override
  Widget build(BuildContext context) {
    final tone = ref.watch(toneProvider);
    final mood = _mood;
    final low = mood == _Mood.tired || mood == _Mood.low;
    final controller = ref.read(planFlowProvider.notifier);
    return _StepLayout(
      expression: mood == null ? BubuExpression.curious : (low ? BubuExpression.caring : BubuExpression.happy),
      bubuSays: mood == null ? PlanCopy.moodAsk.of(tone) : _reply(mood).of(tone),
      content: [
        Wrap(
          spacing: AppSpace.s,
          runSpacing: AppSpace.s,
          children: [
            for (final (m, emoji, label) in _options)
              ChoiceChip(
                key: ValueKey('mood-${m.name}'),
                label: Text('$emoji ${label.of(tone)}'),
                selected: mood == m,
                onSelected: (_) => setState(() => _mood = m),
              ),
            ChoiceChip(
              key: const ValueKey('mood-unsaid'),
              label: Text(PlanCopy.moodSkip.of(tone)),
              selected: mood == _Mood.unsaid,
              onSelected: (_) => setState(() => _mood = _Mood.unsaid),
            ),
          ],
        ),
      ],
      actions: [
        if (mood != null && low)
          // 兩個選項份量相同：先不排、還是排一下，都可以。
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('mood-rest'),
                  onPressed: () => leavePlanFlow(context),
                  child: Text(PlanCopy.restToday.of(tone)),
                ),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('mood-plan-anyway'),
                  onPressed: controller.next,
                  child: Text(PlanCopy.planAnyway.of(tone)),
                ),
              ),
            ],
          )
        else if (mood != null)
          _nextButton(context, tone, onPressed: controller.next),
      ],
    );
  }
}

// ============================================================== 2. 選 1–3 件事

class ChooseStep extends ConsumerStatefulWidget {
  const ChooseStep({super.key});

  @override
  ConsumerState<ChooseStep> createState() => _ChooseStepState();
}

class _ChooseStepState extends ConsumerState<ChooseStep> {
  bool _writing = false;
  String _emoji = customTaskEmojis.first;

  Future<void> _addCustom(String text) async {
    final t = await ref
        .read(repositoryProvider)
        .addTaskTemplate(emoji: _emoji, text: text, origin: TemplateOrigin.child);
    final flow = ref.read(planFlowProvider.notifier);
    if (!ref.read(planFlowProvider).isSelected(t.id)) flow.toggle(t);
    if (mounted) setState(() => _writing = false);
  }

  @override
  Widget build(BuildContext context) {
    final tone = ref.watch(toneProvider);
    final flow = ref.watch(planFlowProvider);
    final controller = ref.read(planFlowProvider.notifier);
    final choices = ref.watch(taskChoicesProvider).value ?? const <TaskTemplate>[];
    final max = {'max': '${AppConfig.maxPlansPerDay}'};

    Widget chips(Iterable<TaskTemplate> ts) => Wrap(
          spacing: AppSpace.s,
          runSpacing: AppSpace.s,
          children: [
            for (final t in ts)
              FilterChip(
                key: ValueKey('task-${t.id}'),
                label: Text('${t.emoji} ${t.text}'),
                selected: flow.isSelected(t.id),
                onSelected: (_) => controller.toggle(t),
              ),
          ],
        );

    final mine = choices.where((t) => t.origin == TemplateOrigin.child);
    final preset = choices.where((t) => t.origin == TemplateOrigin.preset);
    final parent = choices.where((t) => t.origin == TemplateOrigin.parent);

    final notice = switch (flow.chooseNotice) {
      ChooseNotice.one => PlanCopy.chooseOne.of(tone),
      ChooseNotice.full => PlanCopy.chooseFull.fill(tone, max),
      ChooseNotice.none => null,
    };

    return _StepLayout(
      expression: BubuExpression.curious,
      bubuSays: PlanCopy.chooseAsk.fill(tone, max),
      content: [
        if (mine.isNotEmpty) ...[_SectionTitle(PlanCopy.sectionMine.of(tone)), chips(mine)],
        if (preset.isNotEmpty) ...[_SectionTitle(PlanCopy.sectionPreset.of(tone)), chips(preset)],
        if (parent.isNotEmpty) ...[_SectionTitle(PlanCopy.sectionParent.of(tone)), chips(parent)],
        const SizedBox(height: AppSpace.m),
        if (!_writing)
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              key: const ValueKey('task-write-own'),
              avatar: const Icon(Icons.edit_outlined, size: 18),
              label: Text(CommonCopy.writeMyOwn.of(tone)),
              onPressed: () => setState(() => _writing = true),
            ),
          )
        else ...[
          _SectionTitle(PlanCopy.customEmojiAsk.of(tone)),
          Wrap(
            spacing: AppSpace.s,
            runSpacing: AppSpace.s,
            children: [
              for (final e in customTaskEmojis)
                ChoiceChip(
                  key: ValueKey('emoji-$e'),
                  label: Text(e, style: const TextStyle(fontSize: 22)),
                  selected: _emoji == e,
                  onSelected: (_) => setState(() => _emoji = e),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s),
          _SafeTextEntry(
            fieldKey: 'task-custom-field',
            submitKey: 'task-custom-add',
            hint: PlanCopy.customTaskHint.of(tone),
            submitLabel: PlanCopy.addIt.of(tone),
            maxChars: AppConfig.maxTaskChars,
            onAccepted: _addCustom,
          ),
        ],
        if (notice != null) _Note(notice, key: const ValueKey('choose-notice')),
      ],
      actions: [
        _nextButton(context, tone, onPressed: flow.canLeaveChoose ? controller.next : null),
      ],
    );
  }
}

// ============================================================== 3. 如果⋯我就⋯

class IfThenStep extends ConsumerStatefulWidget {
  const IfThenStep({super.key});

  @override
  ConsumerState<IfThenStep> createState() => _IfThenStepState();
}

class _IfThenStepState extends ConsumerState<IfThenStep> {
  bool _writingCue = false;
  bool _editingTask = false;

  Future<void> _addCue(String text) async {
    final c = await ref.read(repositoryProvider).addCueTemplate(text: text, origin: TemplateOrigin.child);
    ref.read(planFlowProvider.notifier).setCue(c.text);
    if (mounted) setState(() => _writingCue = false);
  }

  Future<void> _editTask(String text) async {
    ref.read(planFlowProvider.notifier).setTask(text);
    if (mounted) setState(() => _editingTask = false);
  }

  @override
  Widget build(BuildContext context) {
    final tone = ref.watch(toneProvider);
    final flow = ref.watch(planFlowProvider);
    final controller = ref.read(planFlowProvider.notifier);
    final item = flow.current;
    if (item == null) return const SizedBox.shrink();
    final cues = ref.watch(cueChoicesProvider).value ?? const <CueTemplate>[];
    final cue = item.cue;
    final ask = PlanCopy.cueAsk.lines[flow.index % PlanCopy.cueAsk.length];
    final textTheme = Theme.of(context).textTheme;

    Widget slot(String label, Widget content) => Card(
          margin: const EdgeInsets.only(bottom: AppSpace.s),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.m),
            child: Row(
              children: [
                SizedBox(width: 64, child: Text(label, style: textTheme.titleMedium)),
                Expanded(child: content),
              ],
            ),
          ),
        );

    return _StepLayout(
      expression: cue == null ? BubuExpression.curious : BubuExpression.happy,
      bubuSays: cue == null ? ask.of(tone) : PlanCopy.cueChosen.of(tone),
      content: [
        slot(
          PlanCopy.ifSlot.of(tone),
          Text(cue ?? '', key: const ValueKey('ifthen-cue'), style: textTheme.bodyLarge),
        ),
        slot(
          PlanCopy.thenSlot.of(tone),
          Row(
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: AppSpace.s),
              Expanded(child: Text(item.task, key: const ValueKey('ifthen-task'), style: textTheme.bodyLarge)),
              if (!_editingTask)
                IconButton(
                  key: const ValueKey('ifthen-edit-task'),
                  tooltip: PlanCopy.editTask.of(tone),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => setState(() => _editingTask = true),
                ),
            ],
          ),
        ),
        if (_editingTask)
          _SafeTextEntry(
            fieldKey: 'ifthen-task-field',
            submitKey: 'ifthen-task-done',
            hint: PlanCopy.editTaskHint.of(tone),
            submitLabel: CommonCopy.done.of(tone),
            maxChars: AppConfig.maxTaskChars,
            initial: item.task,
            onAccepted: _editTask,
          ),
        if (cue != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
            child: Text(
              PlanCopy.ifThen.fill(tone, {'cue': cue, 'task': item.task}),
              key: const ValueKey('ifthen-sentence'),
              style: textTheme.headlineSmall?.copyWith(fontSize: 20),
            ),
          ),
        _SectionTitle(PlanCopy.ifSlot.of(tone)),
        Wrap(
          spacing: AppSpace.s,
          runSpacing: AppSpace.s,
          children: [
            for (final c in cues)
              ChoiceChip(
                key: ValueKey('cue-${c.id}'),
                label: Text(c.text),
                selected: cue == c.text,
                onSelected: (_) => controller.setCue(c.text),
              ),
            if (!_writingCue)
              ActionChip(
                key: const ValueKey('cue-write-own'),
                avatar: const Icon(Icons.edit_outlined, size: 18),
                label: Text(CommonCopy.writeMyOwn.of(tone)),
                onPressed: () => setState(() => _writingCue = true),
              ),
          ],
        ),
        if (_writingCue) ...[
          const SizedBox(height: AppSpace.s),
          _SafeTextEntry(
            fieldKey: 'cue-custom-field',
            submitKey: 'cue-custom-use',
            hint: PlanCopy.customCueHint.of(tone),
            submitLabel: PlanCopy.useThis.of(tone),
            maxChars: AppConfig.maxCueChars,
            onAccepted: _addCue,
          ),
        ],
      ],
      actions: [
        _nextButton(context, tone, onPressed: cue == null ? null : controller.next),
      ],
    );
  }
}

// ============================================================== 4. 為什麼（可跳過）

class WhyStep extends ConsumerStatefulWidget {
  const WhyStep({super.key});

  @override
  ConsumerState<WhyStep> createState() => _WhyStepState();
}

class _WhyStepState extends ConsumerState<WhyStep> {
  bool _writing = false;

  static const _answers = [
    PlanCopy.whyTry,
    PlanCopy.whyMine,
    PlanCopy.whyEasier,
    PlanCopy.whyFamily,
    PlanCopy.whyDontKnow,
  ];

  @override
  Widget build(BuildContext context) {
    final tone = ref.watch(toneProvider);
    final flow = ref.watch(planFlowProvider);
    final controller = ref.read(planFlowProvider.notifier);
    final item = flow.current;
    if (item == null) return const SizedBox.shrink();
    final why = item.why;

    final String says;
    if (why == null) {
      says = PlanCopy.whyAsk.fill(tone, {'task': item.task});
    } else if (why == PlanCopy.whyDontKnow.of(tone)) {
      says = PlanCopy.whyDontKnowReply.of(tone);
    } else {
      says = PlanCopy.whyHeard.of(tone);
    }

    return _StepLayout(
      expression: why == null ? BubuExpression.curious : BubuExpression.calm,
      bubuSays: says,
      content: [
        Wrap(
          spacing: AppSpace.s,
          runSpacing: AppSpace.s,
          children: [
            for (final (i, a) in _answers.indexed)
              ChoiceChip(
                key: ValueKey('why-$i'),
                label: Text(a.of(tone)),
                selected: why == a.of(tone),
                onSelected: (sel) => controller.setWhy(sel ? a.of(tone) : null),
              ),
            if (!_writing)
              ActionChip(
                key: const ValueKey('why-write-own'),
                avatar: const Icon(Icons.edit_outlined, size: 18),
                label: Text(CommonCopy.writeMyOwn.of(tone)),
                onPressed: () => setState(() => _writing = true),
              ),
          ],
        ),
        if (_writing) ...[
          const SizedBox(height: AppSpace.s),
          _SafeTextEntry(
            fieldKey: 'why-custom-field',
            submitKey: 'why-custom-use',
            hint: PlanCopy.whyCustomHint.of(tone),
            submitLabel: PlanCopy.useThis.of(tone),
            maxChars: AppConfig.maxWhyChars,
            onAccepted: (text) async {
              controller.setWhy(text);
              if (mounted) setState(() => _writing = false);
            },
          ),
        ],
      ],
      actions: [
        if (why != null)
          _nextButton(context, tone, onPressed: controller.next)
        else
          Center(
            child: TextButton(
              key: const ValueKey('why-skip'),
              onPressed: () {
                controller.setWhy(null);
                controller.next();
              },
              child: Text(CommonCopy.skip.of(tone)),
            ),
          ),
      ],
    );
  }
}

// ============================================================== 5. 確認

class ConfirmStep extends ConsumerStatefulWidget {
  const ConfirmStep({super.key});

  @override
  ConsumerState<ConfirmStep> createState() => _ConfirmStepState();
}

class _ConfirmStepState extends ConsumerState<ConfirmStep> {
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final drafts = ref.read(planFlowProvider).drafts;
    final day = ref.read(todayKeyProvider);
    await ref.read(repositoryProvider).savePlans(day, drafts);
    if (!mounted) return;
    leavePlanFlow(context);
  }

  @override
  Widget build(BuildContext context) {
    final tone = ref.watch(toneProvider);
    final flow = ref.watch(planFlowProvider);
    final controller = ref.read(planFlowProvider.notifier);
    return _StepLayout(
      expression: BubuExpression.happy,
      bubuSays: PlanCopy.confirmTitle.of(tone),
      content: [
        for (final (i, item) in flow.items.indexed)
          Card(
            key: ValueKey('confirm-$i'),
            margin: const EdgeInsets.only(bottom: AppSpace.s),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.m),
              child: Row(
                children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: AppSpace.m),
                  Expanded(
                    child: Text(
                      PlanCopy.ifThen.fill(tone, {'cue': item.cue ?? '', 'task': item.task}),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      actions: [
        _nextButton(
          context,
          tone,
          label: PlanCopy.confirmSave,
          onPressed: _saving || !flow.allCuesChosen ? null : _save,
        ),
        Center(
          child: TextButton(
            key: const ValueKey('confirm-edit'),
            onPressed: _saving ? null : controller.editAgain,
            child: Text(PlanCopy.confirmEdit.of(tone)),
          ),
        ),
      ],
    );
  }
}
