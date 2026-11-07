import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bubu/bubu_view.dart';
import '../../copy/pocket.dart';
import '../../core/config.dart';
import '../../core/layout.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../domain/pocket.dart';
import '../../providers.dart';
import 'pocket_widgets.dart';

/// 牆上要看哪些卡（畫面狀態，不存）。
sealed class PocketFilter {
  const PocketFilter();
  bool shows(PocketCard c);
}

class AllCards extends PocketFilter {
  const AllCards();
  @override
  bool shows(PocketCard c) => !c.filedAway;
  @override
  bool operator ==(Object other) => other is AllCards;
  @override
  int get hashCode => 0;
}

class FiledAwayCards extends PocketFilter {
  const FiledAwayCards();
  @override
  bool shows(PocketCard c) => c.filedAway;
  @override
  bool operator ==(Object other) => other is FiledAwayCards;
  @override
  int get hashCode => 1;
}

class GroupCards extends PocketFilter {
  const GroupCards(this.groupId);
  final String groupId;
  @override
  bool shows(PocketCard c) => !c.filedAway && c.groupId == groupId;
  @override
  bool operator ==(Object other) => other is GroupCards && other.groupId == groupId;
  @override
  int get hashCode => groupId.hashCode;
}

class SubjectCards extends PocketFilter {
  const SubjectCards(this.subject);
  final PocketSubject subject;
  @override
  bool shows(PocketCard c) => !c.filedAway && c.subject == subject;
  @override
  bool operator ==(Object other) => other is SubjectCards && other.subject == subject;
  @override
  int get hashCode => subject.hashCode;
}

class _Filter extends Notifier<PocketFilter> {
  @override
  PocketFilter build() => const AllCards();
  void set(PocketFilter f) => state = f;
}

final pocketFilterProvider = NotifierProvider.autoDispose<_Filter, PocketFilter>(_Filter.new);

/// 再看一次口袋（M1）：孩子放的卡，新的在前。不顯示張數、沒有進度、不排程。
class PocketScreen extends ConsumerWidget {
  const PocketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    final access = ref.watch(pocketAccessProvider);
    final cards = ref.watch(pocketCardsProvider).value ?? const <PocketCard>[];
    final groups = ref.watch(pocketGroupsProvider).value ?? const <PocketGroup>[];
    final filter = ref.watch(pocketFilterProvider);
    final shown = cards.where(filter.shows).toList();
    final groupNames = {for (final g in groups) g.id: g.name};
    final canAdd = access == PocketAccess.full;

    void drawOne() {
      final pool = cards.where(const AllCards().shows).where(filter.shows).toList();
      if (pool.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(PocketCopy.nothingToDraw.of(tone))));
        return;
      }
      final pick = pool[ref.read(randomProvider).nextInt(pool.length)];
      context.push(Routes.pocketCard(pick.id));
    }

    final actions = Wrap(
      spacing: AppSpace.s,
      runSpacing: AppSpace.s,
      children: [
        if (canAdd)
          FilledButton.icon(
            key: const ValueKey('pocket-add'),
            onPressed: () => context.push(Routes.pocketNew),
            icon: const Icon(Icons.add),
            label: Text(PocketCopy.add.of(tone)),
          ),
        if (cards.any((c) => !c.filedAway))
          OutlinedButton.icon(
            key: const ValueKey('pocket-draw'),
            onPressed: drawOne,
            icon: const Icon(Icons.shuffle),
            label: Text(PocketCopy.draw.of(tone)),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(PocketCopy.title.of(tone))),
      body: SafeArea(
        child: AdaptiveFrame(
          maxWidth: Layout.isTablet(context) ? LayoutConfig.wideMaxWidth : null,
          child: cards.isEmpty
              ? _Empty(tone: tone, action: canAdd ? actions : null)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = Layout.notebookColumns(context, constraints.maxWidth - 2 * AppSpace.m);
                    return ListView(
                      padding: const EdgeInsets.all(AppSpace.m),
                      children: [
                        actions,
                        const SizedBox(height: AppSpace.m),
                        _FilterChips(tone: tone, cards: cards, groups: groups, selected: filter),
                        const SizedBox(height: AppSpace.m),
                        for (var start = 0; start < shown.length; start += columns)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpace.m),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (var i = 0; i < columns; i++) ...[
                                  if (i > 0) const SizedBox(width: AppSpace.m),
                                  Expanded(
                                    child: start + i < shown.length
                                        ? PocketTile(
                                            card: shown[start + i],
                                            tone: tone,
                                            groupName: groupNames[shown[start + i].groupId],
                                            onTap: () => context.push(Routes.pocketCard(shown[start + i].id)),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// 篩選：全部、每一組、出現過的科目、收好的。都是孩子自己點的，系統不會主動篩。
class _FilterChips extends ConsumerWidget {
  const _FilterChips({required this.tone, required this.cards, required this.groups, required this.selected});
  final AgeTone tone;
  final List<PocketCard> cards;
  final List<PocketGroup> groups;
  final PocketFilter selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = {for (final c in cards) c.subject}.toList()..sort((a, b) => a.index.compareTo(b.index));
    final usedGroups = {for (final c in cards) c.groupId};
    Widget chip(String key, String label, PocketFilter f) => ChoiceChip(
          key: ValueKey('pocket-filter-$key'),
          label: Text(label),
          selected: selected == f,
          onSelected: (_) => ref.read(pocketFilterProvider.notifier).set(f),
        );
    return Wrap(
      spacing: AppSpace.s,
      runSpacing: AppSpace.xs,
      children: [
        chip('all', PocketCopy.filterAll.of(tone), const AllCards()),
        for (final g in groups)
          if (usedGroups.contains(g.id)) chip('group-${g.id}', g.name, GroupCards(g.id)),
        if (subjects.length > 1)
          for (final s in subjects) chip('subject-${s.name}', PocketCopy.subject(s).of(tone), SubjectCards(s)),
        if (cards.any((c) => c.filedAway)) chip('filed', PocketCopy.filterFiledAway.of(tone), const FiledAwayCards()),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.tone, this.action});
  final AgeTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BubuView(expression: BubuExpression.relaxed, size: Layout.bubu(context, BubuSlot.empty)),
              const SizedBox(height: AppSpace.l),
              Text(
                PocketCopy.empty.of(tone),
                key: const ValueKey('pocket-empty'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (action != null) ...[const SizedBox(height: AppSpace.l), action!],
            ],
          ),
        ),
      );
}
