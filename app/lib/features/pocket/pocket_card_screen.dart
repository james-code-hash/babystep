import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bubu/bubu_view.dart';
import '../../copy/line.dart';
import '../../copy/pocket.dart';
import '../../core/layout.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../data/pocket_photos.dart';
import '../../domain/models.dart';
import '../../domain/pocket.dart';
import '../../providers.dart';
import 'pocket_widgets.dart';

/// 翻一張（M1）：正面只有題目，孩子決定先想想還是直接翻面；背面是孩子自己寫的。
/// 翻完三個一樣重的鈕，步步只好奇地問一句。不判斷對錯、不數、不留每次翻的紀錄。
class PocketCardScreen extends ConsumerStatefulWidget {
  const PocketCardScreen({super.key, required this.cardId});
  final String cardId;

  @override
  ConsumerState<PocketCardScreen> createState() => _PocketCardScreenState();
}

enum _Side { asking, thinking, back }

class _PocketCardScreenState extends ConsumerState<PocketCardScreen> {
  _Side _side = _Side.asking;

  /// 這次翻完按的（只是畫面狀態，不存）。
  PocketFeeling? _pressed;

  void _press(PocketFeeling f) => setState(() => _pressed = f);

  Future<void> _delete(PocketCard card, AgeTone tone) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(PocketCopy.deleteAsk.of(tone)),
        actions: [
          TextButton(
            key: const ValueKey('pocket-delete-no'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(PocketCopy.deleteNo.of(tone)),
          ),
          TextButton(
            key: const ValueKey('pocket-delete-yes'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(PocketCopy.deleteYes.of(tone)),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final store = ref.read(pocketPhotoStoreProvider);
    final photo = await ref.read(repositoryProvider).deletePocketCard(card.id);
    if (photo != null) await store?.delete(photo);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tone = ref.watch(toneProvider);
    final cards = ref.watch(pocketCardsProvider).value;
    final card = cards?.where((c) => c.id == widget.cardId).firstOrNull;
    final groups = ref.watch(pocketGroupsProvider).value ?? const <PocketGroup>[];
    final canEdit = ref.watch(pocketAccessProvider) == PocketAccess.full;
    final text = Theme.of(context).textTheme;

    if (card == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final groupName = groups.where((g) => g.id == card.groupId).firstOrNull?.name;

    final front = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SubjectTag(subject: card.subject, tone: tone),
                if (groupName != null) ...[
                  const SizedBox(width: AppSpace.s),
                  Expanded(
                    child: Text(groupName, style: text.bodySmall?.copyWith(color: AppColors.inkSoft)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpace.m),
            if (card.photo != null) ...[PocketPhoto(name: card.photo!), const SizedBox(height: AppSpace.s)],
            if (card.prompt != null) Text(card.prompt!, key: const ValueKey('pocket-front-prompt'), style: text.titleLarge),
          ],
        ),
      ),
    );

    final children = <Widget>[front, const SizedBox(height: AppSpace.l)];

    switch (_side) {
      case _Side.asking:
      case _Side.thinking:
        children.addAll([
          Row(
            children: [
              BubuView(expression: BubuExpression.curious, size: Layout.bubu(context, BubuSlot.step) * 0.6),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Text(
                  (_side == _Side.asking ? PocketCopy.frontAsk : PocketCopy.thinking).of(tone),
                  key: const ValueKey('pocket-bubu-line'),
                  style: text.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.m),
          // 兩個選擇一樣大。
          Row(
            children: [
              if (_side == _Side.asking) ...[
                Expanded(
                  child: FilledButton.tonal(
                    key: const ValueKey('pocket-think'),
                    onPressed: () => setState(() => _side = _Side.thinking),
                    child: Text(PocketCopy.thinkFirst.of(tone)),
                  ),
                ),
                const SizedBox(width: AppSpace.s),
              ],
              Expanded(
                child: FilledButton.tonal(
                  key: const ValueKey('pocket-flip'),
                  onPressed: () => setState(() => _side = _Side.back),
                  child: Text(PocketCopy.flip.of(tone)),
                ),
              ),
            ],
          ),
        ]);
      case _Side.back:
        children.addAll([
          _Back(card: card, tone: tone),
          const SizedBox(height: AppSpace.l),
          Text(PocketCopy.feelingAsk.of(tone), style: text.titleMedium),
          const SizedBox(height: AppSpace.s),
          FeelingButtons(selected: _pressed, onChanged: _press),
          if (_pressed != null) ...[
            const SizedBox(height: AppSpace.m),
            Row(
              children: [
                BubuView(expression: BubuExpression.curious, size: Layout.bubu(context, BubuSlot.step) * 0.6),
                const SizedBox(width: AppSpace.m),
                Expanded(
                  child: Text(
                    PocketCopy.reply(_pressed!).of(tone),
                    key: const ValueKey('pocket-bubu-reply'),
                    style: text.bodyLarge,
                  ),
                ),
              ],
            ),
          ],
        ]);
    }

    children.addAll([
      const SizedBox(height: AppSpace.xl),
      const Divider(color: AppColors.line),
      Wrap(
        spacing: AppSpace.s,
        runSpacing: AppSpace.xs,
        children: [
          if (canEdit)
            TextButton.icon(
              key: const ValueKey('pocket-edit'),
              onPressed: () => context.push(Routes.pocketEdit(card.id)),
              icon: const Icon(Icons.edit_outlined),
              label: Text(PocketCopy.edit.of(tone)),
            ),
          TextButton.icon(
            key: const ValueKey('pocket-file-away'),
            onPressed: () => ref.read(repositoryProvider).setPocketFiledAway(card.id, !card.filedAway),
            icon: Icon(card.filedAway ? Icons.unarchive_outlined : Icons.inventory_2_outlined),
            label: Text((card.filedAway ? PocketCopy.takeBack : PocketCopy.fileAway).of(tone)),
          ),
          TextButton.icon(
            key: const ValueKey('pocket-delete'),
            onPressed: () => _delete(card, tone),
            icon: const Icon(Icons.delete_outline),
            label: Text(PocketCopy.delete.of(tone)),
          ),
        ],
      ),
      SwitchListTile(
        key: const ValueKey('pocket-share'),
        contentPadding: EdgeInsets.zero,
        title: Text(PocketCopy.share.of(tone)),
        subtitle: Text(PocketCopy.shareExplain.of(tone)),
        value: card.sharedWithParent,
        onChanged: (v) => ref.read(repositoryProvider).setPocketShared(card.id, v),
      ),
    ]);

    return Scaffold(
      appBar: AppBar(title: Text(PocketCopy.title.of(tone))),
      body: SafeArea(
        child: AdaptiveFrame(
          child: ListView(padding: const EdgeInsets.all(AppSpace.m), children: children),
        ),
      ),
    );
  }
}

/// 背面：全是孩子自己寫的。空著的格子就寫「還空著」，不催。
class _Back extends StatelessWidget {
  const _Back({required this.card, required this.tone});
  final PocketCard card;
  final AgeTone tone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final blank = PocketCopy.blank.of(tone);
    Widget row(String key, Line label, String? value) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.of(tone), style: text.bodyMedium?.copyWith(color: AppColors.inkSoft)),
              const SizedBox(height: AppSpace.xs),
              Text(value ?? blank, key: ValueKey('pocket-back-$key'), style: text.bodyLarge),
            ],
          ),
        );
    return Card(
      key: const ValueKey('pocket-back'),
      margin: EdgeInsets.zero,
      color: AppColors.stageGlow,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row('thought', PocketCopy.thoughtLabel, card.thought),
            row('stuck', PocketCopy.stuckLabel, card.stuck == null ? null : PocketCopy.stuck(card.stuck!).of(tone)),
            row('know-now', PocketCopy.knowNowLabel, card.knowNow),
            row(
              'if-then',
              PocketCopy.ifThenLabel,
              card.hasIfThen
                  ? PocketCopy.ifThenSentence.fill(tone, {'cue': card.ifCue!, 'action': card.thenAction!})
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
