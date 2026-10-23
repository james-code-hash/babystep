import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../copy/line.dart';
import '../../copy/review.dart';
import '../../core/clock.dart';
import '../../core/config.dart';
import '../../domain/lesson_service.dart';
import '../../domain/models.dart';
import '../../providers.dart';

/// 回顧流程的每一步。「今天沒做」走的是完全一樣的步驟（底線 4）。
enum ReviewStage {
  loading,

  /// 今天沒有計畫。
  noPlans,

  /// 今天已經聊完了。
  alreadyEnded,

  opening,

  /// 一件一件回顧（[ReviewState.index] 是第幾件）。
  outcomes,

  /// 歷程問題。
  question,

  /// 等步步想。
  learning,

  /// 步步說牠學到的事，問要不要記進筆記本。
  lesson,

  ending,
}

class ReviewState {
  const ReviewState({
    this.stage = ReviewStage.loading,
    this.plans = const [],
    this.index = 0,
    this.outcomes = const {},
    this.response,
    this.opening,
    this.question,
    this.chips = const [],
    this.lesson,
    this.thinking = false,
    this.saved = false,
    this.endedBySafety = false,
  });

  final ReviewStage stage;
  final List<Plan> plans;
  final int index;

  /// 這次回顧選的狀態（planId → Outcome）。
  final Map<String, Outcome> outcomes;

  /// 步步對目前這件事的回應（還沒選就是 null）。
  final Line? response;
  final Line? opening;
  final Line? question;
  final List<Line> chips;
  final LessonResult? lesson;

  /// 等太久了，步步在想。
  final bool thinking;

  /// 孩子選了「記下來」。
  final bool saved;

  /// 反思命中危機訊號 → 不學、不存，只道晚安。
  final bool endedBySafety;

  Plan? get currentPlan => index < plans.length ? plans[index] : null;
  Outcome? get currentOutcome => currentPlan == null ? null : outcomes[currentPlan!.id];

  /// safety 來源的結果不提供儲存（C6）。
  bool get canSave => lesson != null && lesson!.source != LessonSource.safety;

  ReviewState copyWith({
    ReviewStage? stage,
    List<Plan>? plans,
    int? index,
    Map<String, Outcome>? outcomes,
    Line? response,
    bool clearResponse = false,
    Line? opening,
    Line? question,
    List<Line>? chips,
    LessonResult? lesson,
    bool? thinking,
    bool? saved,
    bool? endedBySafety,
  }) => ReviewState(
    stage: stage ?? this.stage,
    plans: plans ?? this.plans,
    index: index ?? this.index,
    outcomes: outcomes ?? this.outcomes,
    response: clearResponse ? null : (response ?? this.response),
    opening: opening ?? this.opening,
    question: question ?? this.question,
    chips: chips ?? this.chips,
    lesson: lesson ?? this.lesson,
    thinking: thinking ?? this.thinking,
    saved: saved ?? this.saved,
    endedBySafety: endedBySafety ?? this.endedBySafety,
  );
}

/// 回顧流程的狀態。每次進入回顧畫面都是新的（autoDispose）。
///
/// 安全檢查需要 BuildContext，所以由畫面先跑 `passesSafetyCheck`，再呼叫
/// [answer]（沒事）或 [stopForSafety]（命中）。
class ReviewController extends Notifier<ReviewState> {
  Timer? _thinkingTimer;

  @override
  ReviewState build() {
    ref.onDispose(_cancelTimer);
    return const ReviewState();
  }

  String get _todayKey => ref.read(todayKeyProvider);

  /// 讀今天的計畫與紀錄，決定從哪一步開始。
  Future<void> start() async {
    final repo = ref.read(repositoryProvider);
    final key = _todayKey;
    final record = await repo.dayRecord(key);
    final plans = await repo.plans(key);
    if (!ref.mounted) return;
    final random = ref.read(randomProvider);
    if (record?.ended ?? false) {
      state = state.copyWith(stage: ReviewStage.alreadyEnded);
    } else if (plans.isEmpty) {
      state = state.copyWith(stage: ReviewStage.noPlans);
    } else {
      state = state.copyWith(stage: ReviewStage.opening, plans: plans, opening: ReviewCopy.openings.pickLine(random));
    }
  }

  void begin() {
    if (state.stage != ReviewStage.opening) return;
    state = state.copyWith(stage: ReviewStage.outcomes, index: 0, clearResponse: true);
  }

  /// 選了（或改選）目前這件事的狀態。三種狀態做的事完全一樣：存起來、抽一句步步的回應。
  Future<void> choose(Outcome outcome) async {
    final plan = state.currentPlan;
    if (state.stage != ReviewStage.outcomes || plan == null) return;
    final pool = switch (outcome) {
      Outcome.done => ReviewCopy.doneResponses,
      Outcome.partly => ReviewCopy.partlyResponses,
      Outcome.notToday => ReviewCopy.notTodayResponses,
    };
    state = state.copyWith(
      outcomes: {...state.outcomes, plan.id: outcome},
      response: pool.pickLine(ref.read(randomProvider)),
    );
    await ref.read(repositoryProvider).setOutcome(plan.id, outcome);
  }

  /// 下一件事；最後一件之後進入歷程問題。
  void next() {
    if (state.stage != ReviewStage.outcomes || state.currentOutcome == null) return;
    if (state.index + 1 < state.plans.length) {
      state = state.copyWith(index: state.index + 1, clearResponse: true);
      return;
    }
    final outcomes = [for (final p in state.plans) state.outcomes[p.id]!];
    final didSomething = outcomes.any((o) => o != Outcome.notToday);
    final anyNotToday = outcomes.contains(Outcome.notToday);
    final questions = [
      ...ReviewCopy.anyDayQuestions.lines,
      if (didSomething) ...ReviewCopy.didSomethingQuestions.lines,
    ];
    final random = ref.read(randomProvider);
    state = state.copyWith(
      stage: ReviewStage.question,
      clearResponse: true,
      question: questions[random.nextInt(questions.length)],
      chips: [
        ...ReviewCopy.anyDayChips,
        if (didSomething) ...ReviewCopy.didSomethingChips,
        if (anyNotToday) ...ReviewCopy.notTodayChips,
      ],
    );
  }

  /// 孩子回答了（已經過安全檢查）或跳過（null）。
  Future<void> answer(String? words) async {
    if (state.stage != ReviewStage.question) return;
    final clean = (words?.trim().isEmpty ?? true) ? null : words!.trim();
    state = state.copyWith(stage: ReviewStage.learning, thinking: false);
    await ref.read(repositoryProvider).saveReflection(_todayKey, clean);
    if (!ref.mounted) return;
    await _learn(clean);
  }

  /// 反思命中危機訊號：不存反思、不學，直接道晚安並結束這一天。
  Future<void> stopForSafety() async {
    if (state.stage != ReviewStage.question) return;
    state = state.copyWith(endedBySafety: true);
    await _end();
  }

  Future<void> _learn(String? words) async {
    final request = LessonRequest(
      outcomes: [for (final p in state.plans) state.outcomes[p.id] ?? Outcome.notToday],
      tasks: [for (final p in state.plans) p.task],
      tone: ref.read(toneProvider),
      childWords: words,
    );
    _cancelTimer();
    _thinkingTimer = Timer(AppConfig.llmThinkingAfter, () {
      if (ref.mounted && state.stage == ReviewStage.learning) state = state.copyWith(thinking: true);
    });
    LessonResult result;
    try {
      result = await ref.read(lessonServiceProvider).learn(request);
    } catch (_) {
      // 約定上 learn 不丟例外；萬一丟了，退回離線範本。
      result = await ref.read(templateLessonServiceProvider).learn(request);
    }
    _cancelTimer();
    if (!ref.mounted) return;
    state = state.copyWith(stage: ReviewStage.lesson, lesson: result, thinking: false);
  }

  /// 「記下來」（true）或「不用」（false），然後結束。
  Future<void> decideSave(bool save) async {
    if (state.stage != ReviewStage.lesson) return;
    final lesson = state.lesson;
    if (save && lesson != null && state.canSave) {
      await ref.read(repositoryProvider).saveLesson(_todayKey, lesson);
      if (!ref.mounted) return;
      state = state.copyWith(saved: true);
    }
    await _end();
  }

  Future<void> _end() async {
    await ref.read(repositoryProvider).endDay(_todayKey);
    if (!ref.mounted) return;
    state = state.copyWith(stage: ReviewStage.ending, thinking: false);
  }

  void _cancelTimer() {
    _thinkingTimer?.cancel();
    _thinkingTimer = null;
  }
}

final reviewControllerProvider = NotifierProvider.autoDispose<ReviewController, ReviewState>(ReviewController.new);
