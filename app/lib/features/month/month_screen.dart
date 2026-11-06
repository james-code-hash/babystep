import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bubu/bubu_view.dart';
import '../../copy/common.dart';
import '../../copy/month.dart';
import '../../copy/path.dart';
import '../../core/clock.dart';
import '../../core/config.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../data/repository.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import '../../safety/safety_gate.dart';
import '../path/path_insights.dart';

/// 有哪些月份可以翻：有排過事的月份、有信的月份，再加上這個月（新的在前）。
List<String> monthsToShow(List<PlannedDay> days, List<MonthLetter> letters, DateTime now) {
  final set = {monthKeyOf(now), for (final d in days) d.dayKey.substring(0, 7), for (final l in letters) l.monthKey};
  return set.toList()..sort((a, b) => b.compareTo(a));
}

/// 月回顧「這個月的我」（J4）：一個月一頁的成長故事書。
///
/// 只用故事說：這個月想清楚了幾天、最常排什麼、常在什麼時候開始——全都只跟自己比，沒有完成率、
/// 沒有「最好的一個月」、沒有斷點。資料只來自 [plannedDaysProvider]（本來就沒有 outcome）。
/// 每一頁可以夾兩封信：孩子給家人的一句（孩子寫了才有，家長區看得到）、家人給孩子的一句（原封不動）。
class MonthScreen extends ConsumerStatefulWidget {
  const MonthScreen({super.key});

  @override
  ConsumerState<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends ConsumerState<MonthScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tone = ref.watch(toneProvider);
    final now = ref.watch(clockProvider).now();
    final days = ref.watch(plannedDaysProvider).value ?? const <PlannedDay>[];
    final letters = ref.watch(monthLettersProvider).value ?? const <MonthLetter>[];
    final months = monthsToShow(days, letters, now);
    final i = _index.clamp(0, months.length - 1);
    final month = months[i];
    return Scaffold(
      appBar: AppBar(title: Text(MonthCopy.title.of(tone))),
      body: SafeArea(
        child: AdaptiveFrame(
          child: ListView(
            key: const ValueKey('month-list'),
            padding: const EdgeInsets.all(AppSpace.m),
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('month-older'),
                    tooltip: MonthCopy.prev.of(tone),
                    onPressed: i < months.length - 1 ? () => setState(() => _index = i + 1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      MonthCopy.pageTitle.fill(tone, {
                        'y': month.substring(0, 4),
                        'm': '${int.parse(month.substring(5))}',
                      }),
                      key: ValueKey('month-page-$month'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('month-newer'),
                    tooltip: MonthCopy.next.of(tone),
                    onPressed: i > 0 ? () => setState(() => _index = i - 1) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.m),
              _Story(tone: tone, days: [for (final d in days) if (d.dayKey.startsWith('$month-')) d], month: month),
              const SizedBox(height: AppSpace.m),
              _FamilyThisMonth(tone: tone, month: month),
              _Letters(
                tone: tone,
                month: month,
                editable: month == monthKeyOf(now),
                letters: [for (final l in letters) if (l.monthKey == month) l],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Story extends StatelessWidget {
  const _Story({required this.tone, required this.days, required this.month});
  final AgeTone tone;
  final List<PlannedDay> days;
  final String month;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final insights = PathInsights.from(days, dateOfDayKey('$month-01'));
    final lines = days.isEmpty
        ? [MonthCopy.none.of(tone)]
        : [
            MonthCopy.days.fill(tone, {'n': '${insights.daysThisMonth}'}),
            if (insights.topTask != null) MonthCopy.topTask.fill(tone, {'task': insights.topTask!}),
            if (insights.topCue != null) MonthCopy.topCue.fill(tone, {'cue': PathCopy.cueWithoutMe(insights.topCue!)}),
            MonthCopy.yours.of(tone),
          ];
    return Card(
      key: const ValueKey('month-story'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BubuView(expression: BubuExpression.happy, size: 64),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in lines)
                    Padding(padding: const EdgeInsets.only(bottom: AppSpace.s), child: Text(l, style: text.bodyLarge)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 這個月家人寫過的「今天的我」（同一件事只列一次）。沒有就不顯示。
class _FamilyThisMonth extends ConsumerWidget {
  const _FamilyThisMonth({required this.tone, required this.month});
  final AgeTone tone;
  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(familyMonthProvider(month)).value ?? const <FamilyToday>[];
    final seen = <String>{};
    final items = [
      for (final f in entries)
        if (seen.add('${f.who}|${f.text}')) MonthCopy.familyItem.fill(tone, {'who': f.who, 'text': f.text}),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.m),
      child: Card(
        key: const ValueKey('month-family'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(MonthCopy.familyTitle.of(tone), style: text.titleMedium),
              const SizedBox(height: AppSpace.s),
              for (final s in items) Text(s, style: text.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _Letters extends ConsumerStatefulWidget {
  const _Letters({required this.tone, required this.month, required this.editable, required this.letters});
  final AgeTone tone;
  final String month;

  /// 只有這個月可以寫或改；以前的月份只翻閱。
  final bool editable;
  final List<MonthLetter> letters;

  @override
  ConsumerState<_Letters> createState() => _LettersState();
}

class _LettersState extends ConsumerState<_Letters> {
  final _controller = TextEditingController();
  bool _editing = false;
  bool _busy = false;

  /// 上一次存或拿掉沒成功（例如磁碟滿了）：說一聲，字留在框裡。
  bool _failed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    await _guarded(() async {
      // 孩子的自由輸入：先過危機偵測，不過就不存（底線 9）。
      final ok = await passesSafetyCheck(context, ref, text);
      if (!mounted) return;
      if (ok) await ref.read(repositoryProvider).saveMonthLetter(widget.month, LetterAuthor.child, text);
      if (!mounted) return;
      _controller.clear();
      if (ok) _editing = false;
    });
  }

  Future<void> _remove() =>
      _guarded(() => ref.read(repositoryProvider).deleteMonthLetter(widget.month, LetterAuthor.child));

  /// 存或拿掉時出錯（例如磁碟滿了）：錯誤照樣回報，按鈕回來、說一聲，字留在框裡可以再按一次。
  Future<void> _guarded(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await action();
    } catch (e, st) {
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: st, library: 'month letters'));
      if (mounted) _failed = true;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 「改一下」之後反悔：回到原本那一句，什麼都不動。
  void _cancelEdit() => setState(() {
        _editing = false;
        _controller.clear();
      });

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    final text = Theme.of(context).textTheme;
    String? of(LetterAuthor a) => widget.letters.where((l) => l.author == a).firstOrNull?.text;
    final mine = of(LetterAuthor.child);
    final theirs = of(LetterAuthor.parent);
    final writing = widget.editable && (mine == null || _editing);
    if (!widget.editable && mine == null && theirs == null) return const SizedBox.shrink();

    Widget letter(String key, String label, String body, {List<Widget> actions = const []}) => Container(
          key: ValueKey(key),
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: AppSpace.s),
          padding: const EdgeInsets.all(AppSpace.m),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.labelLarge?.copyWith(color: AppColors.inkSoft)),
              const SizedBox(height: AppSpace.xs),
              Text(body, style: text.bodyLarge),
              if (actions.isNotEmpty) Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
            ],
          ),
        );

    return Card(
      key: const ValueKey('month-letters'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(MonthCopy.lettersTitle.of(tone), style: text.titleMedium),
            const SizedBox(height: AppSpace.s),
            // 家人的信原封不動，步步不加評論（和 §4.11 一樣）。
            if (theirs != null) letter('month-letter-parent', MonthCopy.parentLabel.of(tone), theirs),
            if (mine != null && !writing)
              letter('month-letter-child', MonthCopy.childLabel.of(tone), mine, actions: [
                if (widget.editable) ...[
                  TextButton(
                    key: const ValueKey('month-letter-edit'),
                    onPressed: () => setState(() {
                      _editing = true;
                      _controller.text = mine;
                    }),
                    child: Text(MonthCopy.childEdit.of(tone)),
                  ),
                  TextButton(
                    key: const ValueKey('month-letter-remove'),
                    onPressed: _busy ? null : _remove,
                    child: Text(MonthCopy.childRemove.of(tone)),
                  ),
                ],
              ]),
            if (_failed)
              Text(
                MonthCopy.childFailed.of(tone),
                key: const ValueKey('month-letter-failed'),
                style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
              ),
            if (writing) ...[
              Text(MonthCopy.childHint.of(tone), style: text.bodyMedium?.copyWith(color: AppColors.inkSoft)),
              TextField(
                key: const ValueKey('month-letter-field'),
                controller: _controller,
                maxLength: AppConfig.maxLetterChars,
                decoration: InputDecoration(labelText: MonthCopy.childField.of(tone)),
                onSubmitted: (_) => _save(),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (mine != null)
                    TextButton(
                      key: const ValueKey('month-letter-cancel'),
                      onPressed: _busy ? null : _cancelEdit,
                      child: Text(CommonCopy.cancel.of(tone)),
                    ),
                  FilledButton(
                    key: const ValueKey('month-letter-save'),
                    onPressed: _busy ? null : _save,
                    child: Text(MonthCopy.childSave.of(tone)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
