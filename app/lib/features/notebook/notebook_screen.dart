import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../bubu/bubu_view.dart';
import '../../copy/notebook.dart';
import '../../core/clock.dart';
import '../../core/config.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import 'note_paper.dart';

/// 筆記本的日期，例如「10月23日」（intl zh_TW）。
String formatNoteDate(String dayKey) {
  // 這個呼叫是同步載入 intl 內建的日期資料（回傳的 Future 已經完成）。
  initializeDateFormatting('zh_TW');
  return DateFormat.MMMd('zh_TW').format(dateOfDayKey(dayKey));
}

/// 只看愛心（畫面狀態，不存）。
class _FavoritesOnly extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final _favoritesOnlyProvider = NotifierProvider.autoDispose<_FavoritesOnly, bool>(_FavoritesOnly.new);

/// 步步的筆記本（C4）：新的在前、可翻閱；不顯示數量、沒有目標、沒有進度。
class NotebookScreen extends ConsumerWidget {
  const NotebookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    final lessons = ref.watch(lessonsProvider).value ?? const <Lesson>[];
    final favoritesOnly = ref.watch(_favoritesOnlyProvider);
    final shown = favoritesOnly ? lessons.where((l) => l.favorite).toList() : lessons;

    return Scaffold(
      appBar: AppBar(title: Text(NotebookCopy.title.of(tone))),
      body: SafeArea(
        child: lessons.isEmpty
            ? _Empty(text: NotebookCopy.empty.of(tone))
            : AdaptiveFrame(
                // 平板：多欄排頁（新的仍在最前面，由左到右、由上到下）。只排版，不加任何數量。
                maxWidth: Layout.isTablet(context) ? LayoutConfig.wideMaxWidth : null,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = Layout.notebookColumns(context, constraints.maxWidth - 2 * AppSpace.m);
                    return ListView(
                      padding: const EdgeInsets.all(AppSpace.m),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilterChip(
                            key: const ValueKey('notebook-favorites-only'),
                            avatar: const Icon(Icons.favorite, size: 18, color: AppColors.accent),
                            label: Text(NotebookCopy.favoritesOnly.of(tone)),
                            selected: favoritesOnly,
                            onSelected: (_) => ref.read(_favoritesOnlyProvider.notifier).toggle(),
                          ),
                        ),
                        const SizedBox(height: AppSpace.m),
                        if (shown.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
                            child: Text(
                              NotebookCopy.emptyFavorites.of(tone),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        if (columns == 1)
                          for (final l in shown) ...[
                            _LessonPage(lesson: l, tone: tone),
                            const SizedBox(height: AppSpace.m),
                          ]
                        else
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
                                          ? _LessonPage(lesson: shown[start + i], tone: tone)
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

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

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
            text,
            key: const ValueKey('notebook-empty'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    ),
  );
}

class _LessonPage extends ConsumerWidget {
  const _LessonPage({required this.lesson, required this.tone});
  final Lesson lesson;
  final AgeTone tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(repositoryProvider);
    final small = Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft);
    final heartLabel = (lesson.favorite ? NotebookCopy.favoriteOff : NotebookCopy.favoriteOn).of(tone);
    return NotePaper(
      key: ValueKey('lesson-${lesson.id}'),
      header: Row(
        children: [
          Expanded(child: Text(formatNoteDate(lesson.dayKey), style: small)),
          IconButton(
            key: ValueKey('fav-${lesson.id}'),
            tooltip: heartLabel,
            icon: Icon(lesson.favorite ? Icons.favorite : Icons.favorite_border, color: AppColors.accent),
            onPressed: () => repo.setFavorite(lesson.id, !lesson.favorite),
          ),
        ],
      ),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lesson.sourceQuote != null && lesson.sourceQuote!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s),
              child: Text(NotebookCopy.quote.fill(tone, {'quote': lesson.sourceQuote!}), style: small),
            ),
          const Divider(height: 1, color: AppColors.line),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(NotebookCopy.shareWithParent.of(tone), style: Theme.of(context).textTheme.bodyMedium),
                    Text(NotebookCopy.shareExplain.of(tone), style: small?.copyWith(fontSize: 14)),
                  ],
                ),
              ),
              Switch(
                key: ValueKey('share-${lesson.id}'),
                value: lesson.sharedWithParent,
                onChanged: (v) => repo.setSharedWithParent(lesson.id, v),
              ),
            ],
          ),
        ],
      ),
      child: Text(lesson.text),
    );
  }
}
