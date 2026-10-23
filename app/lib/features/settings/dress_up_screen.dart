import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bubu/bubu_view.dart';
import '../../bubu/catalog.dart';
import '../../copy/line.dart';
import '../../copy/settings.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../providers.dart';

/// 幫步步換裝扮。目錄裡的每一樣一開始就全部能選：沒有條件、沒有價格（底線 1、2）。
/// 這裡只依目錄內容通用地列出，不假設有哪些配件。
class DressUpScreen extends ConsumerWidget {
  const DressUpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    final current = ref.watch(dressUpProvider).value ?? DressUp.initial;
    final text = Theme.of(context).textTheme;

    void choose(DressUp next) => ref.read(repositoryProvider).setDressUp(next);

    return Scaffold(
      appBar: AppBar(title: Text(SettingsCopy.dressUpTitle.of(tone))),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AppSpace.s),
            const Center(child: BubuView(expression: BubuExpression.happy, size: 160)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.m, vertical: AppSpace.s),
              child: Text(SettingsCopy.dressUpIntro.of(tone), style: text.bodyMedium, textAlign: TextAlign.center),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('dress-up-list'),
                padding: const EdgeInsets.all(AppSpace.m),
                children: [
                  _AccessoryGroup(
                    slot: 'hat',
                    title: SettingsCopy.hats,
                    items: BubuCatalog.hats,
                    selectedId: current.hat,
                    tone: tone,
                    onPick: (id) => choose(current.copyWith(hat: id)),
                  ),
                  _AccessoryGroup(
                    slot: 'neck',
                    title: SettingsCopy.necks,
                    items: BubuCatalog.necks,
                    selectedId: current.neck,
                    tone: tone,
                    onPick: (id) => choose(current.copyWith(neck: id)),
                  ),
                  _AccessoryGroup(
                    slot: 'color',
                    title: SettingsCopy.colors,
                    items: BubuCatalog.colors,
                    selectedId: current.color,
                    tone: tone,
                    onPick: (id) => choose(current.copyWith(color: id)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessoryGroup extends StatelessWidget {
  const _AccessoryGroup({
    required this.slot,
    required this.title,
    required this.items,
    required this.selectedId,
    required this.tone,
    required this.onPick,
  });

  final String slot;
  final Line title;
  final List<Accessory> items;
  final String selectedId;
  final AgeTone tone;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.of(tone), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpace.s),
          Wrap(
            spacing: AppSpace.s,
            runSpacing: AppSpace.s,
            children: [
              for (final (i, a) in items.indexed)
                ChoiceChip(
                  key: ValueKey('$slot-${a.id}'),
                  label: Text(_label(a, i)),
                  selected: a.id == selectedId,
                  showCheckmark: false,
                  onSelected: (_) => onPick(a.id),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _label(Accessory a, int index) {
    final name = a.name.of(tone).trim();
    return name.isNotEmpty ? name : SettingsCopy.unnamedOption.fill(tone, {'n': '${index + 1}'});
  }
}
