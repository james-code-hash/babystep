import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../copy/line.dart';
import '../../copy/parent.dart';
import '../../core/clock.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../domain/parent_view.dart';
import '../../providers.dart';
import 'parent_dialogs.dart';
import 'parent_providers.dart';

/// 家長區本體。資料只讀 [parentViewProvider]（底線 7）。
///
/// 刻意沒有：任何完成狀況、使用時間、趨勢、心情、數量統計、孩子沒分享的內容。
class ParentHome extends ConsumerWidget {
  const ParentHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(parentViewProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(pt(ParentCopy.title)),
        actions: [
          IconButton(
            key: const ValueKey('parent-lock'),
            tooltip: pt(ParentCopy.lock),
            icon: const Icon(Icons.lock_outline),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (view) {
          AsyncValue(:final value?) => _ParentBody(view: value),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _ParentBody extends ConsumerWidget {
  const _ParentBody({required this.view});
  final ParentView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdaptiveFrame(
      child: ListView(
        key: const ValueKey('parent-list'),
        padding: const EdgeInsets.all(AppSpace.m),
        children: [
          Text(pt(ParentCopy.intro), style: const TextStyle(color: AppColors.inkSoft)),
          const SizedBox(height: AppSpace.m),
          _SharedLessonsSection(lessons: view.sharedLessons),
          _TaskTemplatesSection(templates: view.taskTemplates),
          _CueTemplatesSection(templates: view.cueTemplates),
          _SlotsSection(slots: view.settings.reminderSlots),
          _ToneSection(tone: view.settings.tone),
          _LlmSection(enabled: view.settings.llmEnabled),
          const _DataSection(),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ 共用版面

class _Section extends StatelessWidget {
  const _Section({required this.id, required this.title, this.note, required this.children, this.action});
  final String id;
  final Line title;
  final Line? note;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      key: ValueKey('section-$id'),
      padding: const EdgeInsets.only(bottom: AppSpace.m),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(pt(title), style: text.titleMedium)),
                  ?action,
                ],
              ),
              if (note != null) ...[
                const SizedBox(height: AppSpace.xs),
                Text(pt(note!), style: text.bodyMedium?.copyWith(color: AppColors.inkSoft)),
              ],
              const SizedBox(height: AppSpace.s),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

Widget _addButton(String key, Line label, VoidCallback onPressed) => TextButton.icon(
      key: ValueKey(key),
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(pt(label)),
    );

Widget _rowActions({required String id, required VoidCallback onEdit, required VoidCallback onDelete}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(key: ValueKey('edit-$id'), tooltip: pt(ParentCopy.edit), icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
        IconButton(key: ValueKey('delete-$id'), tooltip: pt(ParentCopy.delete), icon: const Icon(Icons.delete_outline), onPressed: onDelete),
      ],
    );

// ------------------------------------------------------------------ 孩子分享的筆記

class _SharedLessonsSection extends StatelessWidget {
  const _SharedLessonsSection({required this.lessons});
  final List<SharedLesson> lessons;

  @override
  Widget build(BuildContext context) => _Section(
        id: 'shared',
        title: ParentCopy.sharedTitle,
        note: lessons.isEmpty ? null : ParentCopy.sharedNote,
        children: [
          if (lessons.isEmpty) Text(pt(ParentCopy.sharedEmpty), key: const ValueKey('shared-empty')),
          for (final l in lessons)
            ListTile(
              key: ValueKey('shared-${l.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.text),
              subtitle: Text(_date(l.dayKey)),
            ),
        ],
      );

  String _date(String dayKey) {
    final d = dateOfDayKey(dayKey);
    return ParentCopy.sharedDate.fill(AgeTone.concise, {'m': '${d.month}', 'd': '${d.day}'});
  }
}

// ------------------------------------------------------------------ 事情範本

class _TaskTemplatesSection extends ConsumerWidget {
  const _TaskTemplatesSection({required this.templates});
  final List<TaskTemplate> templates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    void refresh() => ref.invalidate(parentViewProvider);

    Future<void> add() async {
      final r = await showTaskDialog(context);
      if (r == null) return;
      await repo.addTaskTemplate(emoji: r.$1, text: r.$2, origin: TemplateOrigin.parent);
      refresh();
    }

    Future<void> edit(TaskTemplate t) async {
      final r = await showTaskDialog(context, initial: t);
      if (r == null) return;
      await repo.updateTaskTemplate(t.copyWith(emoji: r.$1, text: r.$2));
      refresh();
    }

    Future<void> remove(TaskTemplate t) async {
      await repo.deleteTaskTemplate(t.id);
      refresh();
    }

    Future<void> restore() async {
      final ok = await confirmDialog(
        context,
        title: ParentCopy.restoreConfirmTitle,
        body: ParentCopy.restoreConfirmBody,
        confirm: ParentCopy.restoreConfirm,
        confirmKey: 'restore-confirm',
      );
      if (!ok) return;
      await repo.restoreDefaultTemplates();
      refresh();
    }

    return _Section(
      id: 'tasks',
      title: ParentCopy.tasksTitle,
      note: ParentCopy.tasksNote,
      action: _addButton('add-task', ParentCopy.add, add),
      children: [
        for (final t in templates)
          ListTile(
            key: ValueKey('task-${t.id}'),
            contentPadding: EdgeInsets.zero,
            leading: Text(t.emoji, style: const TextStyle(fontSize: 26)),
            title: Text(t.text),
            trailing: _rowActions(id: t.id, onEdit: () => edit(t), onDelete: () => remove(t)),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('restore-defaults'),
            onPressed: restore,
            icon: const Icon(Icons.restore),
            label: Text(pt(ParentCopy.restoreDefaults)),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ 時間點範本

class _CueTemplatesSection extends ConsumerWidget {
  const _CueTemplatesSection({required this.templates});
  final List<CueTemplate> templates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    void refresh() => ref.invalidate(parentViewProvider);

    Future<void> add() async {
      final r = await showCueDialog(context);
      if (r == null) return;
      await repo.addCueTemplate(text: r, origin: TemplateOrigin.parent);
      refresh();
    }

    Future<void> edit(CueTemplate c) async {
      final r = await showCueDialog(context, initial: c);
      if (r == null) return;
      await repo.updateCueTemplate(CueTemplate(id: c.id, text: r, origin: c.origin, sortOrder: c.sortOrder));
      refresh();
    }

    Future<void> remove(CueTemplate c) async {
      await repo.deleteCueTemplate(c.id);
      refresh();
    }

    return _Section(
      id: 'cues',
      title: ParentCopy.cuesTitle,
      note: ParentCopy.cuesNote,
      action: _addButton('add-cue', ParentCopy.add, add),
      children: [
        for (final c in templates)
          ListTile(
            key: ValueKey('cue-${c.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(c.text),
            trailing: _rowActions(id: c.id, onEdit: () => edit(c), onDelete: () => remove(c)),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ 提醒時段

class _SlotsSection extends ConsumerWidget {
  const _SlotsSection({required this.slots});
  final List<ReminderSlot> slots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);

    Future<void> save(List<ReminderSlot> next) async {
      await repo.setReminderSlots(next);
      ref.invalidate(parentViewProvider);
    }

    Future<void> add() async {
      final r = await showSlotDialog(context);
      if (r == null) return;
      await save([...slots, ReminderSlot(id: const Uuid().v4(), label: r.$1, startMinute: r.$2, endMinute: r.$3)]);
    }

    Future<void> edit(ReminderSlot s) async {
      final r = await showSlotDialog(context, initial: s);
      if (r == null) return;
      await save([
        for (final x in slots)
          if (x.id == s.id) ReminderSlot(id: s.id, label: r.$1, startMinute: r.$2, endMinute: r.$3) else x,
      ]);
    }

    Future<void> remove(ReminderSlot s) => save([for (final x in slots) if (x.id != s.id) x]);

    return _Section(
      id: 'slots',
      title: ParentCopy.slotsTitle,
      note: ParentCopy.slotsNote,
      action: _addButton('add-slot', ParentCopy.add, add),
      children: [
        if (slots.isEmpty) Text(pt(ParentCopy.slotsEmpty)),
        for (final s in slots)
          ListTile(
            key: ValueKey('slot-${s.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(s.label),
            subtitle: Text(ParentCopy.slotRange.fill(
              AgeTone.concise,
              {'start': formatMinute(s.startMinute), 'end': formatMinute(s.endMinute)},
            )),
            trailing: _rowActions(id: s.id, onEdit: () => edit(s), onDelete: () => remove(s)),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ 說話方式

class _ToneSection extends ConsumerWidget {
  const _ToneSection({required this.tone});
  final AgeTone tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Section(
        id: 'tone',
        title: ParentCopy.toneTitle,
        note: ParentCopy.toneNote,
        children: [
          SegmentedButton<AgeTone>(
            key: const ValueKey('parent-tone'),
            segments: [
              ButtonSegment(value: AgeTone.lively, label: Text(pt(ParentCopy.toneLively))),
              ButtonSegment(value: AgeTone.concise, label: Text(pt(ParentCopy.toneConcise))),
            ],
            selected: {tone},
            onSelectionChanged: (s) => ref.read(repositoryProvider).setTone(s.first),
          ),
        ],
      );
}

// ------------------------------------------------------------------ LLM

class _LlmSection extends ConsumerWidget {
  const _LlmSection({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Section(
        id: 'llm',
        title: ParentCopy.llmTitle,
        action: Switch(
          key: const ValueKey('llm-switch'),
          value: enabled,
          onChanged: (v) => ref.read(repositoryProvider).setLlmEnabled(v),
        ),
        children: [
          Text(pt(ParentCopy.llmOff)),
          const SizedBox(height: AppSpace.xs),
          Text(pt(ParentCopy.llmOn)),
          const SizedBox(height: AppSpace.xs),
          Text(pt(ParentCopy.llmDevOnly), style: const TextStyle(color: AppColors.inkSoft)),
        ],
      );
}

// ------------------------------------------------------------------ 資料

class _DataSection extends ConsumerWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);

    Future<void> export() async {
      final json = await repo.exportJson();
      await ref.read(parentShareProvider)(json, pt(ParentCopy.exportSubject));
    }

    Future<void> deleteAll() async {
      final first = await confirmDialog(
        context,
        title: ParentCopy.deleteConfirmTitle,
        body: ParentCopy.deleteConfirmBody,
        confirm: ParentCopy.deleteContinue,
        confirmKey: 'delete-continue',
      );
      if (!first || !context.mounted) return;
      final second = await confirmDeleteAllTyped(context);
      if (!second) return;
      await ref.read(deleteAllDataProvider)();
      ref.invalidate(parentViewProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(pt(ParentCopy.deleted))));
    }

    return _Section(
      id: 'data',
      title: ParentCopy.dataTitle,
      children: [
        Text(pt(ParentCopy.exportNote)),
        const SizedBox(height: AppSpace.s),
        OutlinedButton.icon(
          key: const ValueKey('export'),
          onPressed: export,
          icon: const Icon(Icons.ios_share),
          label: Text(pt(ParentCopy.exportButton)),
        ),
        const SizedBox(height: AppSpace.m),
        Text(pt(ParentCopy.deleteNote)),
        const SizedBox(height: AppSpace.s),
        OutlinedButton.icon(
          key: const ValueKey('delete-all'),
          onPressed: deleteAll,
          icon: const Icon(Icons.delete_forever_outlined),
          label: Text(pt(ParentCopy.deleteButton)),
        ),
      ],
    );
  }
}
