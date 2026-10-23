import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../domain/models.dart';

/// 早上排計畫的步驟。心情不在這裡：心情只活在畫面的 State 裡，用完就丟（C2）。
enum PlanStep { mood, choose, ifThen, why, confirm }

/// 選擇步驟下方的那句話。
enum ChooseNotice { none, one, full }

/// 孩子挑的一件事（還沒存）。
class PlanItem {
  const PlanItem({required this.templateId, required this.emoji, required this.task, this.cue, this.why});

  final String templateId;
  final String emoji;

  /// 「我就⋯」那一槽；孩子可以換個說法。
  final String task;

  /// 「如果⋯」那一槽，以「我」開頭；孩子自己挑，預設是空的（底線 6）。
  final String? cue;
  final String? why;

  PlanItem copyWith({String? task, String? cue, String? why, bool clearWhy = false}) => PlanItem(
        templateId: templateId,
        emoji: emoji,
        task: task ?? this.task,
        cue: cue ?? this.cue,
        why: clearWhy ? null : (why ?? this.why),
      );

  PlanDraft toDraft() => PlanDraft(emoji: emoji, task: task, cue: cue ?? '', why: why);
}

class PlanFlowState {
  const PlanFlowState({
    this.step = PlanStep.mood,
    this.items = const [],
    this.index = 0,
    this.fullAttempt = false,
  });

  final PlanStep step;
  final List<PlanItem> items;

  /// 在 ifThen／why 步驟時，正在處理第幾件。
  final int index;

  /// 剛剛想多選但已經滿了。
  final bool fullAttempt;

  PlanItem? get current => index < items.length ? items[index] : null;

  bool isSelected(String templateId) => items.any((i) => i.templateId == templateId);

  bool get canLeaveChoose => items.length >= AppConfig.minPlansPerDay && items.length <= AppConfig.maxPlansPerDay;

  bool get allCuesChosen => items.isNotEmpty && items.every((i) => (i.cue ?? '').isNotEmpty);

  ChooseNotice get chooseNotice {
    if (fullAttempt) return ChooseNotice.full;
    if (items.length == 1) return ChooseNotice.one;
    return ChooseNotice.none;
  }

  List<PlanDraft> get drafts => [for (final i in items) i.toDraft()];

  PlanFlowState copyWith({PlanStep? step, List<PlanItem>? items, int? index, bool? fullAttempt}) => PlanFlowState(
        step: step ?? this.step,
        items: items ?? this.items,
        index: index ?? this.index,
        fullAttempt: fullAttempt ?? this.fullAttempt,
      );
}

/// 排計畫流程的狀態。離開畫面就丟掉（autoDispose）；重新進來是一份新的草稿
/// （存的時候才覆蓋今天原本的計畫，見 docs/decisions.md）。
class PlanFlowController extends Notifier<PlanFlowState> {
  @override
  PlanFlowState build() => const PlanFlowState();

  void startChoosing() => state = state.copyWith(step: PlanStep.choose, fullAttempt: false);

  /// 選或取消一件事。已經滿了再選 → 不加，只顯示一句溫和的話。回傳有沒有選上。
  bool toggle(TaskTemplate t) {
    if (state.isSelected(t.id)) {
      state = state.copyWith(
        items: [for (final i in state.items) if (i.templateId != t.id) i],
        fullAttempt: false,
      );
      return false;
    }
    if (state.items.length >= AppConfig.maxPlansPerDay) {
      state = state.copyWith(fullAttempt: true);
      return false;
    }
    state = state.copyWith(
      items: [...state.items, PlanItem(templateId: t.id, emoji: t.emoji, task: t.text)],
      fullAttempt: false,
    );
    return true;
  }

  void _updateCurrent(PlanItem Function(PlanItem) f) {
    final items = [...state.items];
    items[state.index] = f(items[state.index]);
    state = state.copyWith(items: items);
  }

  void setCue(String cue) => _updateCurrent((i) => i.copyWith(cue: CueTemplate.normalize(cue)));

  void setTask(String task) {
    final clean = task.trim();
    if (clean.isEmpty) return;
    _updateCurrent((i) => i.copyWith(task: clean));
  }

  /// null 或空字串 = 不說（跳過）。
  void setWhy(String? why) {
    final clean = why?.trim() ?? '';
    _updateCurrent((i) => clean.isEmpty ? i.copyWith(clearWhy: true) : i.copyWith(why: clean));
  }

  /// 往下一步。條件不夠（還沒選、還沒挑時間點）時什麼都不做。
  void next() {
    final s = state;
    switch (s.step) {
      case PlanStep.mood:
        startChoosing();
      case PlanStep.choose:
        if (s.canLeaveChoose) state = s.copyWith(step: PlanStep.ifThen, index: 0, fullAttempt: false);
      case PlanStep.ifThen:
        if ((s.current?.cue ?? '').isNotEmpty) state = s.copyWith(step: PlanStep.why);
      case PlanStep.why:
        state = s.index + 1 < s.items.length
            ? s.copyWith(step: PlanStep.ifThen, index: s.index + 1)
            : s.copyWith(step: PlanStep.confirm);
      case PlanStep.confirm:
        break;
    }
  }

  /// 往上一步。已經在第一步就回傳 false（畫面自己離開）。
  bool back() {
    final s = state;
    switch (s.step) {
      case PlanStep.mood:
        return false;
      case PlanStep.choose:
        state = s.copyWith(step: PlanStep.mood, fullAttempt: false);
      case PlanStep.ifThen:
        state = s.index == 0
            ? s.copyWith(step: PlanStep.choose)
            : s.copyWith(step: PlanStep.why, index: s.index - 1);
      case PlanStep.why:
        state = s.copyWith(step: PlanStep.ifThen);
      case PlanStep.confirm:
        state = s.copyWith(step: PlanStep.why, index: s.items.length - 1);
    }
    return true;
  }

  /// 確認頁的「回去改一下」。
  void editAgain() => state = state.copyWith(step: PlanStep.choose, index: 0, fullAttempt: false);
}

final planFlowProvider = NotifierProvider.autoDispose<PlanFlowController, PlanFlowState>(PlanFlowController.new);
