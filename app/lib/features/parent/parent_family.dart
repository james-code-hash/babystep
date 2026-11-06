import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../copy/family.dart';
import '../../copy/parent.dart';
import '../../core/clock.dart';
import '../../core/config.dart';
import '../../core/copy_rules.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../domain/parent_view.dart';
import '../../providers.dart';
import 'parent_dialogs.dart' show pt;

/// 家長寫的字（「今天的我」、留言）要先過文案規則：L1、L2、幼稚詞全擋（和 LLM 輸出一樣嚴）。
/// 回傳第一個被擋下來的詞；沒問題回傳 null。
String? familyTextProblem(CopyRules rules, String text) {
  final v = rules.check(text, tone: AgeTone.concise);
  return v.isEmpty ? null : v.first.match;
}

/// 家長區的「全家一起」（企劃書 §9.5、文案庫 §4.11）。資料只來自 [ParentView]（家長自己寫的東西）。
///
/// 刻意沒有：孩子看過留言了沒、孩子有沒有關掉轉達、家人的事做到了沒。
class FamilySection extends ConsumerWidget {
  const FamilySection({super.key, required this.today, required this.notes});
  final List<FamilyTodayView> today;
  final List<FamilyNoteView> notes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final repo = ref.read(repositoryProvider);

    Future<void> addToday() async {
      final r = await showFamilyDialog(context, today: true);
      if (r == null) return;
      await repo.saveFamilyToday(dayKeyOf(ref.read(clockProvider).now()), who: r.$1, text: r.$2);
    }

    Future<void> addNote() async {
      final r = await showFamilyDialog(context, today: false);
      if (r == null) return;
      await repo.addFamilyNote(who: r.$1, text: r.$2);
    }

    String date(String dayKey) {
      final d = dateOfDayKey(dayKey);
      return FamilyCopy.entryDate.fill(AgeTone.concise, {'m': '${d.month}', 'd': '${d.day}'});
    }

    Widget subTitle(String label, String key, VoidCallback onAdd, String addLabel) => Row(
          children: [
            Expanded(child: Text(label, style: text.titleSmall)),
            TextButton.icon(key: ValueKey(key), onPressed: onAdd, icon: const Icon(Icons.add), label: Text(addLabel)),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        subTitle(pt(FamilyCopy.todayTitle), 'family-today-add', addToday, pt(FamilyCopy.todayAdd)),
        Text(pt(FamilyCopy.todayNote), style: text.bodyMedium?.copyWith(color: AppColors.inkSoft)),
        if (today.isEmpty) Text(pt(FamilyCopy.todayEmpty), key: const ValueKey('family-today-empty')),
        for (final f in today)
          ListTile(
            key: ValueKey('family-today-${f.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(f.text),
            subtitle: Text(f.who),
            trailing: IconButton(
              key: ValueKey('family-today-delete-${f.id}'),
              tooltip: pt(ParentCopy.delete),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => repo.deleteFamilyToday(f.id),
            ),
          ),
        const SizedBox(height: AppSpace.m),
        subTitle(pt(FamilyCopy.notesTitle), 'family-note-add', addNote, pt(FamilyCopy.noteAdd)),
        Text(pt(FamilyCopy.notesNote), style: text.bodyMedium?.copyWith(color: AppColors.inkSoft)),
        if (notes.isEmpty) Text(pt(FamilyCopy.notesEmpty), key: const ValueKey('family-notes-empty')),
        for (final n in notes)
          ListTile(
            key: ValueKey('family-note-${n.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(n.text),
            subtitle: Text('${n.who} · ${date(n.dayKey)}'),
            trailing: IconButton(
              key: ValueKey('family-note-delete-${n.id}'),
              tooltip: pt(ParentCopy.delete),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => repo.deleteFamilyNote(n.id),
            ),
          ),
      ],
    );
  }
}

/// 寫「今天的我」或留言：誰＋一句話。文字過不了文案規則就留在對話框裡、說明被擋的詞。
Future<(String, String)?> showFamilyDialog(BuildContext context, {required bool today}) =>
    showDialog<(String, String)>(context: context, builder: (_) => _FamilyDialog(today: today));

class _FamilyDialog extends ConsumerStatefulWidget {
  const _FamilyDialog({required this.today});
  final bool today;

  @override
  ConsumerState<_FamilyDialog> createState() => _FamilyDialogState();
}

class _FamilyDialogState extends ConsumerState<_FamilyDialog> {
  final _who = TextEditingController();
  final _text = TextEditingController();
  String? _blocked;

  @override
  void dispose() {
    _who.dispose();
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final who = _who.text.trim();
    final text = _text.text.trim();
    if (who.isEmpty || text.isEmpty) return;
    final rules = ref.read(copyRulesProvider);
    final problem = familyTextProblem(rules, text) ?? familyTextProblem(rules, who);
    if (problem != null) {
      setState(() => _blocked = problem);
      return;
    }
    Navigator.pop(context, (who, text));
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _blocked;
    return AlertDialog(
      title: Text(pt(widget.today ? FamilyCopy.todayTitle : FamilyCopy.notesTitle)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpace.xs,
              runSpacing: AppSpace.xs,
              children: [
                for (final (i, w) in FamilyCopy.whoPresets.indexed)
                  ActionChip(
                    key: ValueKey('family-who-$i'),
                    label: Text(pt(w)),
                    onPressed: () => setState(() => _who.text = pt(w)),
                  ),
              ],
            ),
            TextField(
              key: const ValueKey('family-who-field'),
              controller: _who,
              maxLength: AppConfig.maxFamilyWhoChars,
              decoration: InputDecoration(labelText: pt(FamilyCopy.whoLabel)),
            ),
            TextField(
              key: const ValueKey('family-text-field'),
              controller: _text,
              maxLength: widget.today ? AppConfig.maxTaskChars : AppConfig.maxFamilyNoteChars,
              autofocus: true,
              onChanged: (_) {
                if (_blocked != null) setState(() => _blocked = null);
              },
              decoration: InputDecoration(
                labelText: pt(widget.today ? FamilyCopy.todayTextLabel : FamilyCopy.noteTextLabel),
                helperText: widget.today ? null : pt(FamilyCopy.noteExample),
                helperMaxLines: 2,
              ),
            ),
            if (blocked != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s),
                child: Text(
                  FamilyCopy.blocked.fill(AgeTone.concise, {'word': blocked}),
                  key: const ValueKey('family-blocked'),
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(pt(ParentCopy.cancel))),
        FilledButton(key: const ValueKey('dialog-save'), onPressed: _save, child: Text(pt(ParentCopy.save))),
      ],
    );
  }
}
