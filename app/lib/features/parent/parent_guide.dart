import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../copy/line.dart';
import '../../copy/parent_guide.dart';
import '../../core/age_text_scale.dart';
import '../../core/clock.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import 'parent_dialogs.dart' show pt;

/// 每週一則：依日期（從某個週一算起的第幾週）輪替。不記錄家長讀了沒有。
int lessonIndexFor(DateTime now) {
  final day = DateTime.utc(now.year, now.month, now.day);
  // 1970-01-05 是週一。
  final weeks = day.difference(DateTime.utc(1970, 1, 5)).inDays ~/ 7;
  return weeks % ParentGuideCopy.lessons.length;
}

ParentLesson lessonFor(DateTime now) => ParentGuideCopy.lessons[lessonIndexFor(now)];

/// 家長區裡推一個子頁面：推在家長區自己的 Navigator 上，所以仍在 PIN 後面、沒有網址可以繞過。
void pushParentPage(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

/// 家長區的「陪伴小工具」入口。
class ParentGuideEntries extends ConsumerWidget {
  const ParentGuideEntries({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = lessonFor(ref.watch(clockProvider).now());
    return Column(
      children: [
        ListTile(
          key: const ValueKey('open-talk'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.chat_bubble_outline),
          title: Text(pt(ParentGuideCopy.talkEntry)),
          subtitle: Text(pt(ParentGuideCopy.talkEntryHint)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => pushParentPage(context, const ParentTalkScreen()),
        ),
        ListTile(
          key: const ValueKey('open-lessons'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.menu_book_outlined),
          title: Text(pt(ParentGuideCopy.lessonsEntry)),
          subtitle: Text(ParentGuideCopy.lessonsEntryHint.fill(AgeTone.concise, {'title': pt(lesson.title)})),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => pushParentPage(context, const ParentLessonsScreen()),
        ),
      ],
    );
  }
}

/// 一個家長子頁面的外框。
class ParentPage extends StatelessWidget {
  const ParentPage({super.key, required this.title, required this.children, this.listKey});
  final Line title;
  final List<Widget> children;
  final Key? listKey;

  @override
  Widget build(BuildContext context) => AgeTextScale.unscaled(context, Scaffold(
        appBar: AppBar(title: Text(pt(title))),
        body: SafeArea(
          child: AdaptiveFrame(
            child: ListView(key: listKey, padding: const EdgeInsets.all(AppSpace.m), children: children),
          ),
        ),
      ));
}

// ------------------------------------------------------------------ 話術轉譯器

/// 話術轉譯器（企劃書 §9.4）：家長選情境 → 承認感受＋提供選擇＋給理由。
/// 只吃家長點的情境，不讀孩子任何資料（底線 7）。
class ParentTalkScreen extends StatefulWidget {
  const ParentTalkScreen({super.key});

  @override
  State<ParentTalkScreen> createState() => _ParentTalkScreenState();
}

class _ParentTalkScreenState extends State<ParentTalkScreen> {
  String? _open;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ParentPage(
      title: ParentGuideCopy.talkTitle,
      listKey: const ValueKey('talk-list'),
      children: [
        Text(pt(ParentGuideCopy.talkIntro), style: text.bodyMedium?.copyWith(color: AppColors.inkSoft)),
        const SizedBox(height: AppSpace.m),
        Wrap(
          spacing: AppSpace.s,
          runSpacing: AppSpace.s,
          children: [
            for (final s in ParentGuideCopy.scripts)
              ChoiceChip(
                key: ValueKey('talk-${s.id}'),
                label: Text(pt(s.situation)),
                selected: _open == s.id,
                onSelected: (sel) => setState(() => _open = sel ? s.id : null),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.m),
        for (final s in ParentGuideCopy.scripts)
          if (s.id == _open) _ScriptCard(script: s),
      ],
    );
  }
}

class _ScriptCard extends StatelessWidget {
  const _ScriptCard({required this.script});
  final TalkScript script;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget part(String id, Line label, Line body, {bool muted = false}) => Padding(
          key: ValueKey('talk-part-$id'),
          padding: const EdgeInsets.only(bottom: AppSpace.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pt(label), style: text.titleSmall?.copyWith(color: AppColors.inkSoft)),
              const SizedBox(height: AppSpace.xs),
              Text(
                pt(body),
                style: muted
                    ? text.bodyLarge?.copyWith(color: AppColors.inkSoft, decoration: TextDecoration.lineThrough)
                    : text.bodyLarge,
              ),
            ],
          ),
        );
    return Card(
      key: ValueKey('talk-card-${script.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            part('avoid', ParentGuideCopy.avoidLabel, script.avoid, muted: true),
            part('feeling', ParentGuideCopy.feelingLabel, script.feeling),
            part('choice', ParentGuideCopy.choiceLabel, script.choice),
            part('reason', ParentGuideCopy.reasonLabel, script.reason),
            part('why', ParentGuideCopy.whyLabel, script.why),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ 每週一則

/// 家長微課程（企劃書 §9.3）：這週的那一則在最上面，其他週的照順序往下排。
class ParentLessonsScreen extends ConsumerWidget {
  const ParentLessonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final current = lessonIndexFor(ref.watch(clockProvider).now());
    final all = ParentGuideCopy.lessons;
    final ordered = [for (var i = 0; i < all.length; i++) all[(current + i) % all.length]];
    return ParentPage(
      title: ParentGuideCopy.lessonsTitle,
      listKey: const ValueKey('lessons-list'),
      children: [
        Text(pt(ParentGuideCopy.lessonsIntro), style: text.bodyMedium?.copyWith(color: AppColors.inkSoft)),
        const SizedBox(height: AppSpace.m),
        for (final (i, l) in ordered.indexed)
          Card(
            key: ValueKey('lesson-${l.id}'),
            margin: const EdgeInsets.only(bottom: AppSpace.m),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (i == 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.xs),
                      child: Text(pt(ParentGuideCopy.thisWeek),
                          key: const ValueKey('lesson-this-week'), style: text.labelLarge?.copyWith(color: AppColors.accent)),
                    ),
                  Text(pt(l.title), style: text.titleMedium),
                  const SizedBox(height: AppSpace.s),
                  for (final p in l.paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s),
                      child: Text(pt(p), style: text.bodyLarge),
                    ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpace.s),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: Text('${pt(ParentGuideCopy.tryThisLabel)}：${pt(l.tryThis)}', style: text.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
