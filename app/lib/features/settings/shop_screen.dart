import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bubu/bubu_view.dart';
import '../../bubu/look.dart' show Season, seasonOf;
import '../../bubu/shop.dart';
import '../../copy/line.dart';
import '../../copy/shop.dart';
import '../../core/clock.dart';
import '../../core/config.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../providers.dart';

/// 步步的小店（決策 L1）：逛、試穿、穿上。
///
/// 每一樣都不用錢、沒有條件（底線 1）；這一季的架子只看日期，東西過季也不收（底線 2、3）。
/// 試穿只改畫面上的預覽，按「穿上」才存起來。
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  /// 正在試穿的那一件；null 表示沒在試穿。
  ShopItem? _trying;

  @override
  Widget build(BuildContext context) {
    final tone = ref.watch(toneProvider);
    final current = ref.watch(dressUpProvider).value ?? DressUp.initial;
    final now = ref.watch(clockProvider).now();
    final text = Theme.of(context).textTheme;
    final trying = _trying;
    final previewLook = trying?.wornOn(current) ?? current;

    void tryOn(ShopItem item) => setState(() => _trying = item.isWornIn(current) ? null : item);
    Future<void> wear() async {
      final item = _trying;
      if (item == null) return;
      await ref.read(repositoryProvider).setDressUp(item.wornOn(current));
      if (mounted) setState(() => _trying = null);
    }

    final preview = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BubuView(
          key: const ValueKey('shop-preview'),
          expression: BubuExpression.happy,
          dressUp: previewLook,
          size: Layout.isTwoPane(context) ? LayoutConfig.bubuSidePane : Layout.bubu(context, BubuSlot.hero),
        ),
        const SizedBox(height: AppSpace.s),
        if (trying == null)
          Text(ShopCopy.intro.of(tone), style: text.bodyMedium, textAlign: TextAlign.center)
        else ...[
          Text(
            ShopCopy.trying.fill(tone, {'item': trying.accessory.name.of(tone)}),
            key: const ValueKey('shop-trying'),
            style: text.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.s),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpace.s,
            children: [
              FilledButton(key: const ValueKey('shop-wear'), onPressed: wear, child: Text(ShopCopy.wear.of(tone))),
              OutlinedButton(
                key: const ValueKey('shop-put-back'),
                onPressed: () => setState(() => _trying = null),
                child: Text(ShopCopy.putBack.of(tone)),
              ),
            ],
          ),
        ],
      ],
    );

    Widget shelf(Line title, List<ShopItem> items, {Line? hint, Key? key}) => _Shelf(
          key: key,
          title: title.fill(tone, {'season': _seasonName(seasonOf(now)).of(tone)}),
          hint: hint?.of(tone),
          items: items,
          current: current,
          trying: trying,
          tone: tone,
          onTap: tryOn,
        );

    final list = ListView(
      key: const ValueKey('shop-list'),
      padding: const EdgeInsets.all(AppSpace.m),
      children: [
        shelf(ShopCopy.seasonShelf, BubuShop.featured(now), hint: ShopCopy.seasonShelfHint, key: const ValueKey('shelf-season')),
        shelf(ShopCopy.hats, BubuShop.shelf(AccessorySlot.hat, now), key: const ValueKey('shelf-hat')),
        shelf(ShopCopy.necks, BubuShop.shelf(AccessorySlot.neck, now), key: const ValueKey('shelf-neck')),
        shelf(ShopCopy.colors, BubuShop.shelf(AccessorySlot.color, now), key: const ValueKey('shelf-color')),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(ShopCopy.title.of(tone))),
      body: SafeArea(
        child: Layout.isTwoPane(context)
            ? TwoPaneRow(
                side: Center(
                  child: SingleChildScrollView(padding: const EdgeInsets.all(AppSpace.m), child: preview),
                ),
                main: list,
              )
            : AdaptiveFrame(
                child: Column(
                  children: [
                    const SizedBox(height: AppSpace.s),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.m),
                      child: Layout.isTablet(context) ? StagePanel(child: preview) : preview,
                    ),
                    Expanded(child: list),
                  ],
                ),
              ),
      ),
    );
  }

  static Line _seasonName(Season s) => switch (s) {
        Season.spring => ShopCopy.spring,
        Season.summer => ShopCopy.summer,
        Season.autumn => ShopCopy.autumn,
        Season.winter => ShopCopy.winter,
      };
}

/// 一層架子：標題＋一排格子。每一格畫一隻穿著那一件的小步步。
class _Shelf extends StatelessWidget {
  const _Shelf({
    super.key,
    required this.title,
    required this.hint,
    required this.items,
    required this.current,
    required this.trying,
    required this.tone,
    required this.onTap,
  });

  final String title;
  final String? hint;
  final List<ShopItem> items;
  final DressUp current;
  final ShopItem? trying;
  final AgeTone tone;
  final ValueChanged<ShopItem> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium),
          if (hint != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(hint!, style: text.bodySmall),
          ],
          const SizedBox(height: AppSpace.s),
          Wrap(
            spacing: AppSpace.s,
            runSpacing: AppSpace.s,
            children: [
              for (final item in items)
                _ShopTile(
                  item: item,
                  current: current,
                  selected: item == trying,
                  worn: item.isWornIn(current),
                  tone: tone,
                  onTap: () => onTap(item),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({
    required this.item,
    required this.current,
    required this.selected,
    required this.worn,
    required this.tone,
    required this.onTap,
  });

  final ShopItem item;
  final DressUp current;
  final bool selected;
  final bool worn;
  final AgeTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final name = item.accessory.name.of(tone);
    return SizedBox(
      width: ShopConfig.tileWidth,
      child: Card(
        key: ValueKey('shop-${item.slot.name}-${item.id}'),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpace.m),
          side: BorderSide(color: selected ? scheme.primary : Colors.transparent, width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.s),
            child: Column(
              children: [
                // 小步步只穿這一件（其他位置照現在穿的），所以看得出這一件長什麼樣。
                ExcludeSemantics(child: BubuView(size: ShopConfig.tileBubu, dressUp: item.wornOn(current))),
                const SizedBox(height: AppSpace.xs),
                Text(name, style: text.bodyMedium, textAlign: TextAlign.center, maxLines: 2),
                if (worn) Text(ShopCopy.worn.of(tone), style: text.bodySmall?.copyWith(color: scheme.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
