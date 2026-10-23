import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bubu/bubu_view.dart';
import '../../copy/path.dart';
import '../../core/clock.dart';
import '../../core/theme.dart';
import '../../data/repository.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import 'path_insights.dart';
import 'path_trail.dart';

/// 「我的小路」：資料只來自 [plannedDaysProvider]（沒有 outcome，C5）。
class PathScreen extends ConsumerWidget {
  const PathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    final days = ref.watch(plannedDaysProvider);
    final now = ref.watch(clockProvider).now();
    return Scaffold(
      appBar: AppBar(title: Text(PathCopy.title.of(tone))),
      body: SafeArea(
        child: switch (days) {
          AsyncData(:final value) when value.isNotEmpty => _PathBody(days: value, tone: tone, now: now),
          AsyncData() || AsyncError() => _EmptyPath(tone: tone),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _PathBody extends StatelessWidget {
  const _PathBody({required this.days, required this.tone, required this.now});
  final List<PlannedDay> days;
  final AgeTone tone;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final insights = PathInsights.from(days, now);
    final text = Theme.of(context).textTheme;
    return ListView(
      key: const ValueKey('path-list'),
      padding: const EdgeInsets.all(AppSpace.m),
      children: [
        Text(PathCopy.intro.of(tone), style: text.bodyLarge, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.m),
        PathTrail(days: days, tone: tone),
        const SizedBox(height: AppSpace.l),
        _InsightsCard(insights: insights, tone: tone),
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
  const _EmptyPath({required this.tone});
  final AgeTone tone;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BubuView(expression: BubuExpression.curious, size: 140),
              const SizedBox(height: AppSpace.l),
              Text(
                PathCopy.empty.of(tone),
                key: const ValueKey('path-empty'),
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
