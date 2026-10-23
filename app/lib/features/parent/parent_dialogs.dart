import 'package:flutter/material.dart';

import '../../copy/line.dart';
import '../../copy/parent.dart';
import '../../core/config.dart';
import '../../domain/models.dart';

String pt(Line l) => l.of(AgeTone.concise);

/// 預設圖示（家長沒填的時候）。
const defaultTaskEmoji = '⭐';

/// 一天中的分鐘數 → `16:00`。
String formatMinute(int m) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(m ~/ 60)}:${two(m % 60)}';
}

/// 新增／修改事情範本。回傳 (emoji, 事情)；取消回傳 null。
Future<(String, String)?> showTaskDialog(BuildContext context, {TaskTemplate? initial}) {
  final emoji = TextEditingController(text: initial?.emoji ?? '');
  final text = TextEditingController(text: initial?.text ?? '');
  return showDialog<(String, String)>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(pt(initial == null ? ParentCopy.addTask : ParentCopy.editTask)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('task-emoji-field'),
            controller: emoji,
            decoration: InputDecoration(labelText: pt(ParentCopy.taskEmojiLabel), hintText: defaultTaskEmoji),
          ),
          TextField(
            key: const ValueKey('task-text-field'),
            controller: text,
            maxLength: AppConfig.maxTaskChars,
            autofocus: true,
            decoration: InputDecoration(labelText: pt(ParentCopy.taskTextLabel)),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(pt(ParentCopy.cancel))),
        FilledButton(
          key: const ValueKey('dialog-save'),
          onPressed: () {
            final t = text.text.trim();
            if (t.isEmpty) return;
            final e = emoji.text.trim();
            Navigator.pop(context, (e.isEmpty ? defaultTaskEmoji : e, t));
          },
          child: Text(pt(ParentCopy.save)),
        ),
      ],
    ),
  );
}

/// 新增／修改時間點範本。回傳文字（存的時候 repository 會補成「我⋯」開頭）。
Future<String?> showCueDialog(BuildContext context, {CueTemplate? initial}) {
  final text = TextEditingController(text: initial?.text ?? '');
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(pt(initial == null ? ParentCopy.addCue : ParentCopy.editCue)),
      content: TextField(
        key: const ValueKey('cue-text-field'),
        controller: text,
        maxLength: AppConfig.maxCueChars,
        autofocus: true,
        decoration: InputDecoration(labelText: pt(ParentCopy.cueTextLabel)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(pt(ParentCopy.cancel))),
        FilledButton(
          key: const ValueKey('dialog-save'),
          onPressed: () {
            final t = text.text.trim();
            if (t.isEmpty) return;
            Navigator.pop(context, t);
          },
          child: Text(pt(ParentCopy.save)),
        ),
      ],
    ),
  );
}

/// 新增／修改提醒時段。回傳 (名稱, 開始分鐘, 結束分鐘)。
Future<(String, int, int)?> showSlotDialog(BuildContext context, {ReminderSlot? initial}) {
  final label = TextEditingController(text: initial?.label ?? '');
  var start = initial?.startMinute ?? ParentConfig.newSlotStartMinute;
  var end = initial?.endMinute ?? ParentConfig.newSlotEndMinute;
  return showDialog<(String, int, int)>(
    context: context,
    builder: (context) => StatefulBuilder(builder: (context, setState) {
      Future<void> pick(bool isStart) async {
        final m = isStart ? start : end;
        final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60));
        if (picked == null) return;
        setState(() {
          final v = picked.hour * 60 + picked.minute;
          if (isStart) {
            start = v;
          } else {
            end = v;
          }
        });
      }

      final valid = end > start;
      return AlertDialog(
        title: Text(pt(initial == null ? ParentCopy.addSlot : ParentCopy.editSlot)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('slot-label-field'),
              controller: label,
              maxLength: AppConfig.maxCueChars,
              decoration: InputDecoration(labelText: pt(ParentCopy.slotLabel)),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('slot-start'),
                    onPressed: () => pick(true),
                    child: Text('${pt(ParentCopy.slotStart)} ${formatMinute(start)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('slot-end'),
                    onPressed: () => pick(false),
                    child: Text('${pt(ParentCopy.slotEnd)} ${formatMinute(end)}'),
                  ),
                ),
              ],
            ),
            if (!valid)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(pt(ParentCopy.slotInvalid), key: const ValueKey('slot-invalid')),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(pt(ParentCopy.cancel))),
          FilledButton(
            key: const ValueKey('dialog-save'),
            onPressed: !valid
                ? null
                : () {
                    final l = label.text.trim();
                    if (l.isEmpty) return;
                    Navigator.pop(context, (l, start, end));
                  },
            child: Text(pt(ParentCopy.save)),
          ),
        ],
      );
    }),
  );
}

/// 一般確認框。
Future<bool> confirmDialog(
  BuildContext context, {
  required Line title,
  required Line body,
  required Line confirm,
  String confirmKey = 'dialog-confirm',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(pt(title)),
      content: Text(pt(body)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(pt(ParentCopy.cancel))),
        FilledButton(key: ValueKey(confirmKey), onPressed: () => Navigator.pop(context, true), child: Text(pt(confirm))),
      ],
    ),
  );
  return ok ?? false;
}

/// 刪除全部的第二道確認：要打出「刪除」才能按。
Future<bool> confirmDeleteAllTyped(BuildContext context) async {
  final word = pt(ParentCopy.deleteConfirmWord);
  final field = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(pt(ParentCopy.deleteTypeTitle)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ParentCopy.deleteTypeBody.fill(AgeTone.concise, {'word': word})),
            TextField(
              key: const ValueKey('delete-type-field'),
              controller: field,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(pt(ParentCopy.cancel))),
          FilledButton(
            key: const ValueKey('delete-final'),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: field.text.trim() == word ? () => Navigator.pop(context, true) : null,
            child: Text(pt(ParentCopy.deleteFinal)),
          ),
        ],
      ),
    ),
  );
  return ok ?? false;
}
