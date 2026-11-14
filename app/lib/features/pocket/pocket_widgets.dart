import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../copy/pocket.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/pocket_photos.dart';
import '../../domain/models.dart';
import '../../domain/pocket.dart';
import '../../providers.dart';

/// 題目照片。這台裝置沒有照片資料夾（測試、桌面）或檔案不見了，就什麼都不畫。
class PocketPhoto extends ConsumerWidget {
  const PocketPhoto({super.key, required this.name, this.height});
  final String name;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(pocketPhotoStoreProvider);
    if (store == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.chip),
      child: Image.file(
        store.fileOf(name),
        key: ValueKey('pocket-photo-$name'),
        height: height,
        width: double.infinity,
        fit: height == null ? BoxFit.contain : BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// 科目的小標籤。
class SubjectTag extends StatelessWidget {
  const SubjectTag({super.key, required this.subject, required this.tone});
  final PocketSubject subject;
  final AgeTone tone;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(AppRadius.chip)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s, vertical: 2),
          child: Text(PocketCopy.subject(subject).of(tone), style: Theme.of(context).textTheme.bodySmall),
        ),
      );
}

/// 翻完時的三個鈕（底線 4）：同尺寸（[Expanded] 平分＋同高）、同底色、同字重、同字級；
/// 順序固定；沒有預設選取；不用紅綠。選了的那顆外框和其他兩顆一樣粗，只是顏色不透明。
class FeelingButtons extends ConsumerWidget {
  const FeelingButtons({super.key, required this.onChanged, this.selected});

  final ValueChanged<PocketFeeling> onChanged;
  final PocketFeeling? selected;

  static const order = [PocketFeeling.clearer, PocketFeeling.stillStuck, PocketFeeling.later];

  static ValueKey<String> keyFor(PocketFeeling f) => ValueKey('feeling-${f.name}');

  static const labelStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.3);

  static const double height = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, f) in order.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpace.s),
            Expanded(
              child: _FeelingButton(
                key: keyFor(f),
                label: PocketCopy.feeling(f).of(tone),
                selected: selected == f,
                onTap: () => onChanged(f),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeelingButton extends StatelessWidget {
  const _FeelingButton({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.button);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: SizedBox.expand(
        child: Material(
          color: AppColors.outcomeButton,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: selected ? AppColors.ink : Colors.transparent, width: 2),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppConfig.minTapTarget),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s),
                child: Center(child: Text(label, textAlign: TextAlign.center, style: FeelingButtons.labelStyle)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 一張卡在牆上的樣子：科目、組名、題目（字或照片）。沒有數字、沒有對錯。
class PocketTile extends StatelessWidget {
  const PocketTile({super.key, required this.card, required this.tone, this.groupName, required this.onTap});
  final PocketCard card;
  final AgeTone tone;
  final String? groupName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('pocket-tile-${card.id}'),
        onTap: onTap,
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
                    Expanded(child: Text(groupName!, style: small, overflow: TextOverflow.ellipsis)),
                  ],
                ],
              ),
              const SizedBox(height: AppSpace.s),
              if (card.photo != null) ...[
                PocketPhoto(name: card.photo!, height: PocketConfig.thumbHeight),
                const SizedBox(height: AppSpace.xs),
              ],
              if (card.prompt != null)
                Text(card.prompt!, maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
