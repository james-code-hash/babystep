import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bubu/bubu_view.dart';
import '../../copy/line.dart';
import '../../copy/path.dart';
import '../../core/clock.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/repository.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import 'path_insights.dart';
import 'path_trail.dart';
import 'sky_trail.dart';
import 'tree_trail.dart';

/// 「我的小路」：資料只來自 [plannedDaysProvider]（沒有 outcome，C5）。
/// 孩子可以換成一棵樹或星空（J3）；每一種都只畫有計畫的日子，一天一個記號。
class PathScreen extends ConsumerWidget {
  const PathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    final days = ref.watch(plannedDaysProvider);
    final now = ref.watch(clockProvider).now();
    final style = ref.watch(trailStyleProvider);
    return Scaffold(
      appBar: AppBar(title: Text(PathCopy.title.of(tone))),
      body: SafeArea(
        child: switch (days) {
          AsyncData(:final value) when value.isNotEmpty => _PathBody(days: value, tone: tone, now: now, style: style),
          AsyncData() || AsyncError() => _EmptyPath(tone: tone, style: style),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// 換個樣子：小路／一棵樹／星空。孩子自己選，存在孩子的設定裡。
class _StylePicker extends ConsumerWidget {
  const _StylePicker({required this.tone, required this.style});
  final AgeTone tone;
  final TrailStyle style;

  static Line labelOf(TrailStyle s) => switch (s) {
        TrailStyle.path => PathCopy.stylePath,
        TrailStyle.tree => PathCopy.styleTree,
        TrailStyle.sky => PathCopy.styleSky,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
        label: PathCopy.styleAsk.of(tone),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpace.s,
          runSpacing: AppSpace.xs,
          children: [
            for (final s in TrailStyle.values)
              ChoiceChip(
                key: ValueKey('trail-style-${s.name}'),
                label: Text(labelOf(s).of(tone)),
                selected: s == style,
                onSelected: (_) => ref.read(repositoryProvider).setTrailStyle(s),
              ),
          ],
        ),
      );
}

class _PathBody extends StatelessWidget {
  const _PathBody({required this.days, required this.tone, required this.now, required this.style});
  final List<PlannedDay> days;
  final AgeTone tone;
  final DateTime now;
  final TrailStyle style;

  @override
  Widget build(BuildContext context) {
    final insights = PathInsights.from(days, now);
    final text = Theme.of(context).textTheme;
    // 窄版：洞察在小路下面（和原本一樣）；寬版（平板橫放）：洞察在小路旁邊。
    return AdaptiveTwoPane(
      scrollKey: const ValueKey('path-list'),
      sideAtEnd: true,
      side: (context, wide) => _InsightsCard(insights: insights, tone: tone),
      children: [
        _StylePicker(tone: tone, style: style),
        const SizedBox(height: AppSpace.m),
        Text(
          switch (style) {
            TrailStyle.path => PathCopy.intro,
            TrailStyle.tree => PathCopy.introTree,
            TrailStyle.sky => PathCopy.introSky,
          }
              .of(tone),
          style: text.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpace.m),
        switch (style) {
          TrailStyle.path => PathTrail(days: days, tone: tone),
          TrailStyle.tree => TreeTrail(days: days, tone: tone),
          TrailStyle.sky => SkyTrail(days: days, tone: tone),
        },
      ],
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights, required this.tone});
  final PathInsights insights;
  final AgeTone tone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lines = <(String, String)>[
      if (insights.daysThisMonth > 0)
        ('insight-month', PathCopy.daysThisMonth.fill(tone, {'n': '${insights.daysThisMonth}'})),
      if (insights.topCue != null)
        ('insight-cue', PathCopy.mostUsedCue.fill(tone, {'cue': PathCopy.cueWithoutMe(insights.topCue!)})),
      if (insights.topTask != null)
        ('insight-task', PathCopy.mostPlannedTask.fill(tone, {'task': insights.topTask!})),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BubuView(expression: BubuExpression.curious, size: 64),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(PathCopy.insightsTitle.of(tone), style: text.titleMedium),
                  const SizedBox(height: AppSpace.s),
                  for (final (key, line) in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s),
                      child: Text(line, key: ValueKey(key), style: text.bodyLarge),
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

class _EmptyPath extends StatelessWidget {
  const _EmptyPath({required this.tone, required this.style});
  final AgeTone tone;
  final TrailStyle style;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StylePicker(tone: tone, style: style),
              const SizedBox(height: AppSpace.l),
              BubuView(expression: BubuExpression.curious, size: Layout.bubu(context, BubuSlot.empty)),
              const SizedBox(height: AppSpace.l),
              Text(
                switch (style) {
                  TrailStyle.path => PathCopy.empty,
                  TrailStyle.tree => PathCopy.emptyTree,
                  TrailStyle.sky => PathCopy.emptySky,
                }
                    .of(tone),
                key: const ValueKey('path-empty'),
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
