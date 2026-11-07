import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bubu/bubu_view.dart';
import '../../copy/family.dart';
import '../../copy/pocket.dart';
import '../../copy/settings.dart';
import '../../core/routes.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../domain/pocket.dart';
import '../../providers.dart';
import '../read_aloud/read_aloud.dart';

/// 孩子自己的「我的設定」：步步說話的方式（B5，不標年齡）＋裝扮入口。
class ChildSettingsScreen extends ConsumerWidget {
  const ChildSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(SettingsCopy.title.of(tone))),
      body: SafeArea(
        child: AdaptiveFrame(
          child: ListView(
            padding: const EdgeInsets.all(AppSpace.m),
            children: [
              Text(SettingsCopy.toneTitle.of(tone), style: text.titleMedium),
              const SizedBox(height: AppSpace.xs),
              Text(SettingsCopy.toneHint.of(tone), style: text.bodyMedium?.copyWith(color: AppColors.inkSoft)),
              const SizedBox(height: AppSpace.m),
              for (final option in AgeTone.values) ...[
                _ToneOption(option: option, selected: option == tone),
                const SizedBox(height: AppSpace.s),
              ],
              const SizedBox(height: AppSpace.l),
              Card(
                child: SwitchListTile(
                  key: const ValueKey('family-notes-switch'),
                  title: Text(FamilyCopy.settingTitle.of(tone), style: text.titleMedium),
                  subtitle: Text(FamilyCopy.settingHint.of(tone)),
                  value: ref.watch(settingsProvider).value?.familyNotesOn ?? true,
                  onChanged: (v) => ref.read(repositoryProvider).setFamilyNotesOn(v),
                ),
              ),
              // 口袋（家長有買才出現這個開關，M1）：藏起來不會刪掉任何卡。
              if (ref.watch(pocketAccessProvider) != PocketAccess.none) ...[
                const SizedBox(height: AppSpace.m),
                Card(
                  child: SwitchListTile(
                    key: const ValueKey('pocket-visible-switch'),
                    secondary: const Icon(Icons.style_outlined),
                    title: Text(PocketCopy.settingTitle.of(tone), style: text.titleMedium),
                    subtitle: Text(PocketCopy.settingHint.of(tone)),
                    value: !(ref.watch(settingsProvider).value?.pocketHidden ?? false),
                    onChanged: (v) => ref.read(repositoryProvider).setPocketHidden(!v),
                  ),
                ),
              ],
              if (ref.watch(speakerProvider).available) ...[
                const SizedBox(height: AppSpace.m),
                Card(
                  child: SwitchListTile(
                    key: const ValueKey('read-aloud-switch'),
                    secondary: const Icon(Icons.volume_up_outlined),
                    title: Text(SettingsCopy.readAloudTitle.of(tone), style: text.titleMedium),
                    subtitle: Text(SettingsCopy.readAloudHint.of(tone)),
                    value: ref.watch(settingsProvider).value?.readAloud ?? false,
                    onChanged: (v) => ref.read(repositoryProvider).setReadAloud(v),
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.m),
              Card(
                child: ListTile(
                  key: const ValueKey('open-pet-name'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.m, vertical: AppSpace.s),
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(SettingsCopy.nameEntry.of(tone), style: text.titleMedium),
                  subtitle: Text(SettingsCopy.nameEntryHint.of(tone)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.petName),
                ),
              ),
              const SizedBox(height: AppSpace.m),
              Card(
                child: ListTile(
                  key: const ValueKey('open-dress-up'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.m, vertical: AppSpace.s),
                  leading: const BubuView(size: 56),
                  title: Text(SettingsCopy.dressUpEntry.of(tone), style: text.titleMedium),
                  subtitle: Text(SettingsCopy.dressUpEntryHint.of(tone)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.dressUp),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToneOption extends ConsumerWidget {
  const _ToneOption({required this.option, required this.selected});
  final AgeTone option;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = option == AgeTone.lively ? SettingsCopy.toneLively : SettingsCopy.toneConcise;
    final preview = option == AgeTone.lively ? SettingsCopy.previewLively : SettingsCopy.previewConcise;
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.accentSoft : AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: selected ? AppColors.accent : AppColors.line, width: selected ? 2 : 1),
        ),
        child: InkWell(
          key: ValueKey('tone-${option.name}'),
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => ref.read(repositoryProvider).setTone(option),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.m),
            child: Row(
              children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: AppColors.accent),
                const SizedBox(width: AppSpace.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label.of(option), style: text.titleMedium),
                      const SizedBox(height: AppSpace.xs),
                      Text(preview.of(option), key: ValueKey('tone-preview-${option.name}'), style: text.bodyMedium),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        (option == AgeTone.lively ? SettingsCopy.livelyDetail : SettingsCopy.conciseDetail).of(option),
                        style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
