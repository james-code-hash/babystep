import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../copy/line.dart';
import '../../copy/pocket.dart';
import '../../core/config.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/pocket_photos.dart';
import '../../domain/models.dart';
import '../../domain/pocket.dart';
import '../../providers.dart';
import '../../safety/safety_gate.dart';
import 'pocket_widgets.dart';

/// 放一張進口袋，或改一張（M1）。每一格都可以不填，只有題目（文字或照片）要有。
/// 步步只問問題、給句子開頭，不代寫（底線 6）。
class PocketEditorScreen extends ConsumerStatefulWidget {
  const PocketEditorScreen({super.key, this.cardId});

  /// null ＝ 新的一張。
  final String? cardId;

  @override
  ConsumerState<PocketEditorScreen> createState() => _PocketEditorScreenState();
}

class _PocketEditorScreenState extends ConsumerState<PocketEditorScreen> {
  final _prompt = TextEditingController();
  final _thought = TextEditingController();
  final _knowNow = TextEditingController();
  final _ifCue = TextEditingController();
  final _then = TextEditingController();

  bool _loaded = false;
  String? _groupId;
  PocketSubject _subject = PocketSubject.other;
  PocketStuck? _stuck;

  /// 卡片原本的照片（改一張時）與這次畫面上的照片。
  String? _originalPhoto;
  String? _photo;

  /// 這次新拍的照片（沒存就離開要刪掉）。
  final _newPhotos = <String>{};
  bool _saving = false;

  /// 先拿好（dispose 時不能再用 ref）。
  late final PocketPhotoStore? _store;

  @override
  void initState() {
    super.initState();
    _store = ref.read(pocketPhotoStoreProvider);
    _load();
  }

  Future<void> _load() async {
    final id = widget.cardId;
    if (id != null) {
      final c = await ref.read(repositoryProvider).pocketCard(id);
      if (c != null) {
        _prompt.text = c.prompt ?? '';
        _thought.text = c.thought ?? '';
        _knowNow.text = c.knowNow ?? '';
        _ifCue.text = c.ifCue ?? '';
        _then.text = c.thenAction ?? '';
        _groupId = c.groupId;
        _subject = c.subject;
        _stuck = c.stuck;
        _originalPhoto = c.photo;
        _photo = c.photo;
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    // 拍了但沒存的照片不要留在裝置上。
    final store = _store;
    if (store != null) {
      for (final n in _newPhotos) {
        store.delete(n);
      }
    }
    for (final c in [_prompt, _thought, _knowNow, _ifCue, _then]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _takePhoto(PhotoSource source) async {
    final store = _store;
    if (store == null) return;
    final name = await store.take(source);
    if (name == null || !mounted) return;
    setState(() {
      _newPhotos.add(name);
      _photo = name;
    });
  }

  Future<void> _save(AgeTone tone) async {
    if (_saving) return;
    final draft = PocketCardDraft(
      id: widget.cardId,
      groupId: _groupId,
      subject: _subject,
      prompt: _prompt.text,
      photo: _photo,
      thought: _thought.text,
      stuck: _stuck,
      knowNow: _knowNow.text,
      ifCue: _ifCue.text,
      thenAction: _then.text,
    );
    if (!draft.hasPrompt) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(PocketCopy.needPrompt.of(tone))));
      return;
    }
    setState(() => _saving = true);
    // 孩子打的字都先過危機偵測；命中就走安全回應，不存（底線 9）。
    final ok = await passesSafetyCheck(context, ref, draft.childWords);
    if (!mounted) return;
    if (!ok) {
      setState(() => _saving = false);
      return;
    }
    final repo = ref.read(repositoryProvider);
    await repo.savePocketCard(draft);
    final store = _store;
    // 存好了：這張用的照片留著，其他這次拍過的、以及被換掉的舊照片刪掉。
    _newPhotos.remove(_photo);
    final old = _originalPhoto;
    if (store != null && old != null && old != _photo) await store.delete(old);
    if (mounted) context.pop();
  }

  Future<void> _newGroup(AgeTone tone) async {
    final name = await showDialog<String>(context: context, builder: (_) => _GroupNameDialog(tone: tone));
    if (name == null || name.trim().isEmpty || !mounted) return;
    if (!await passesSafetyCheck(context, ref, name)) return;
    final g = await ref.read(repositoryProvider).addPocketGroup(name);
    if (mounted) setState(() => _groupId = g.id);
  }

  @override
  Widget build(BuildContext context) {
    final tone = ref.watch(toneProvider);
    final groups = ref.watch(pocketGroupsProvider).value ?? const <PocketGroup>[];
    final store = ref.watch(pocketPhotoStoreProvider);
    final text = Theme.of(context).textTheme;
    final title = widget.cardId == null ? PocketCopy.editorTitle : PocketCopy.editTitle;

    Widget heading(Line line, [Line? hint]) => Padding(
          padding: const EdgeInsets.only(top: AppSpace.l, bottom: AppSpace.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.of(tone), style: text.titleMedium),
              if (hint != null) Text(hint.of(tone), style: text.bodyMedium?.copyWith(color: AppColors.inkSoft)),
            ],
          ),
        );

    Widget field(String key, TextEditingController c, int max, {String? hint, int lines = 2}) => TextField(
          key: ValueKey(key),
          controller: c,
          minLines: 1,
          maxLines: lines,
          inputFormatters: [LengthLimitingTextInputFormatter(max)],
          style: text.bodyLarge,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(title.of(tone))),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : AdaptiveFrame(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpace.m),
                  children: [
                    // 組
                    Text(PocketCopy.groupTitle.of(tone), style: text.titleMedium),
                    const SizedBox(height: AppSpace.s),
                    Wrap(
                      spacing: AppSpace.s,
                      runSpacing: AppSpace.xs,
                      children: [
                        ChoiceChip(
                          key: const ValueKey('pocket-group-none'),
                          label: Text(PocketCopy.groupNone.of(tone)),
                          selected: _groupId == null,
                          onSelected: (_) => setState(() => _groupId = null),
                        ),
                        for (final g in groups)
                          ChoiceChip(
                            key: ValueKey('pocket-group-${g.id}'),
                            label: Text(g.name),
                            selected: _groupId == g.id,
                            onSelected: (_) => setState(() => _groupId = g.id),
                          ),
                        ActionChip(
                          key: const ValueKey('pocket-group-new'),
                          avatar: const Icon(Icons.add, size: 18),
                          label: Text(PocketCopy.groupNew.of(tone)),
                          onPressed: () => _newGroup(tone),
                        ),
                      ],
                    ),

                    // 題目
                    heading(PocketCopy.promptTitle),
                    field('pocket-prompt', _prompt, PocketConfig.maxPromptChars,
                        hint: PocketCopy.promptHint.of(tone), lines: 4),
                    if (store != null) ...[
                      const SizedBox(height: AppSpace.s),
                      if (_photo != null) ...[
                        PocketPhoto(name: _photo!, height: 200),
                        TextButton.icon(
                          key: const ValueKey('pocket-photo-remove'),
                          onPressed: () => setState(() => _photo = null),
                          icon: const Icon(Icons.close),
                          label: Text(PocketCopy.removePhoto.of(tone)),
                        ),
                      ],
                      Wrap(
                        spacing: AppSpace.s,
                        children: [
                          OutlinedButton.icon(
                            key: const ValueKey('pocket-photo-camera'),
                            onPressed: () => _takePhoto(PhotoSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: Text(PocketCopy.takePhoto.of(tone)),
                          ),
                          OutlinedButton.icon(
                            key: const ValueKey('pocket-photo-gallery'),
                            onPressed: () => _takePhoto(PhotoSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(PocketCopy.pickPhoto.of(tone)),
                          ),
                        ],
                      ),
                    ],

                    // 科目
                    heading(PocketCopy.subjectTitle),
                    Wrap(
                      spacing: AppSpace.s,
                      runSpacing: AppSpace.xs,
                      children: [
                        for (final s in PocketSubject.values)
                          ChoiceChip(
                            key: ValueKey('pocket-subject-${s.name}'),
                            label: Text(PocketCopy.subject(s).of(tone)),
                            selected: _subject == s,
                            onSelected: (_) => setState(() => _subject = s),
                          ),
                      ],
                    ),

                    // 那時候怎麼想
                    heading(PocketCopy.thoughtTitle, PocketCopy.thoughtHint),
                    field('pocket-thought', _thought, PocketConfig.maxNoteChars),

                    // 卡在哪（點一下選、再點一下取消）
                    heading(PocketCopy.stuckTitle),
                    Wrap(
                      spacing: AppSpace.s,
                      runSpacing: AppSpace.xs,
                      children: [
                        for (final s in PocketStuck.values)
                          ChoiceChip(
                            key: ValueKey('pocket-stuck-${s.name}'),
                            label: Text(PocketCopy.stuck(s).of(tone)),
                            selected: _stuck == s,
                            onSelected: (on) => setState(() => _stuck = on ? s : null),
                          ),
                      ],
                    ),

                    // 現在知道的
                    heading(PocketCopy.knowNowTitle, PocketCopy.knowNowHint),
                    field('pocket-know-now', _knowNow, PocketConfig.maxNoteChars),

                    // 如果⋯我就⋯（孩子自己寫，步步只給開頭）
                    heading(PocketCopy.ifThenTitle, PocketCopy.ifThenExample),
                    Row(
                      children: [
                        SizedBox(width: 48, child: Text(PocketCopy.ifLabel.of(tone), style: text.titleMedium)),
                        Expanded(child: field('pocket-if', _ifCue, PocketConfig.maxIfThenChars, lines: 1)),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s),
                    Row(
                      children: [
                        SizedBox(width: 48, child: Text(PocketCopy.thenLabel.of(tone), style: text.titleMedium)),
                        Expanded(child: field('pocket-then', _then, PocketConfig.maxIfThenChars, lines: 1)),
                      ],
                    ),

                    const SizedBox(height: AppSpace.xl),
                    FilledButton(
                      key: const ValueKey('pocket-save'),
                      onPressed: _saving ? null : () => _save(tone),
                      child: Text((widget.cardId == null ? PocketCopy.save : PocketCopy.saveEdit).of(tone)),
                    ),
                    const SizedBox(height: AppSpace.l),
                  ],
                ),
              ),
      ),
    );
  }
}

class _GroupNameDialog extends StatefulWidget {
  const _GroupNameDialog({required this.tone});
  final AgeTone tone;

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(PocketCopy.groupNew.of(widget.tone)),
        content: TextField(
          key: const ValueKey('pocket-group-name'),
          controller: _name,
          autofocus: true,
          inputFormatters: [LengthLimitingTextInputFormatter(PocketConfig.maxGroupNameChars)],
          decoration: InputDecoration(hintText: PocketCopy.groupNameHint.of(widget.tone)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(PocketCopy.cancel.of(widget.tone))),
          FilledButton(
            key: const ValueKey('pocket-group-create'),
            onPressed: () => Navigator.pop(context, _name.text),
            child: Text(PocketCopy.groupCreate.of(widget.tone)),
          ),
        ],
      );
}
