import 'dart:math';

import '../../copy/lessons.dart';
import '../../core/config.dart';
import '../../core/copy_rules.dart';
import '../lesson_service.dart';
import '../models.dart';

/// 離線的範本引擎（docs/decisions.md C3）。
///
/// 依（回顧狀態 × 孩子有沒有說話 × 語氣）從 `copy/lessons.dart` 抽一句。
///
/// - **哪一件事決定句子**：今天第一件計畫的回顧狀態。理由：和 LLM 模式送出的欄位一致（B3：第一件事的
///   名稱與狀態），而且順序是孩子自己排的。三種狀態的池一樣大、「沒做」的池全是「從選擇學到」，
///   所以不論哪一件決定、全部都沒做的一天也一樣學得到東西（底線 4）。
/// - **孩子說了話**：先試「引用原話」的池，把原話的一段帶進 `{quote}`；帶入後整句過不了文案規則或
///   超過 [AppConfig.maxBubuChars]，就換下一句，全部不行再退回不引用的池。引用的那段一定是
///   `childWords` 的子字串，放進 [LessonResult.sourceQuote]。
/// - **決定性**：每個嘗試的池只呼叫一次 `random.nextInt`，從那裡開始依序找第一句過得了規則的。
///   同一個 [Random] 種子 → 同一句。
/// - **永遠不丟例外**：最差回傳平淡日那句。
class TemplateLessonService implements LessonService {
  TemplateLessonService({required this.rules, required this.random});

  final CopyRules rules;
  final Random random;

  /// 引用原話時最少要幾個字，太短就不引用。
  static const int minQuoteChars = AppConfig.minQuoteChars;

  /// 平淡日（「今天沒什麼特別要記的」）。
  static LessonResult plainDay(AgeTone tone) => LessonResult(
        text: LessonCopy.plainDay.line.of(tone),
        kind: LessonCopy.plainDay.kind,
        source: LessonSource.template,
      );

  @override
  Future<LessonResult> learn(LessonRequest request) async {
    try {
      return _learn(request);
    } catch (_) {
      return plainDay(request.tone);
    }
  }

  LessonResult _learn(LessonRequest request) {
    final tone = request.tone;
    if (request.outcomes.isEmpty) return plainDay(tone);
    final pools = LessonCopy.poolsFor(request.outcomes.first);
    final task = request.tasks.isEmpty ? '' : request.tasks.first.trim();

    if (request.childSpoke) {
      final quoted = _pick(pools.quoted, tone, task: task, childWords: request.childWords!);
      if (quoted != null) return quoted;
    }
    return _pick(pools.silent, tone, task: task) ?? plainDay(tone);
  }

  LessonResult? _pick(List<LessonLine> pool, AgeTone tone, {required String task, String? childWords}) {
    if (pool.isEmpty) return null;
    final start = random.nextInt(pool.length);
    for (var i = 0; i < pool.length; i++) {
      final candidate = pool[(start + i) % pool.length];
      final r = _fill(candidate, tone, task: task, childWords: childWords);
      if (r != null) return r;
    }
    return null;
  }

  LessonResult? _fill(LessonLine candidate, AgeTone tone, {required String task, String? childWords}) {
    var text = candidate.line.of(tone);
    if (text.contains('{task}')) {
      if (task.isEmpty) return null;
      text = text.replaceAll('{task}', task);
    }
    String? sourceQuote;
    if (text.contains('{quote}')) {
      if (childWords == null) return null;
      // 句子裡 `{quote}` 以外的字數，剩下的才是引用可以用的字數。
      final budget = AppConfig.maxBubuChars - (text.runes.length - '{quote}'.runes.length);
      final q = pickQuote(childWords, budget);
      if (q == null) return null;
      sourceQuote = q.quote;
      text = text.replaceAll('{quote}', q.display);
    }
    if (text.contains('{') || !rules.passesGenerated(text, tone)) return null;
    return LessonResult(text: text, kind: candidate.kind, source: LessonSource.template, sourceQuote: sourceQuote);
  }

  /// 斷句用的標點（全形與半形）。
  static final RegExp _segment = RegExp(r'[^，。！？!?；;,.、．\n…⋯~～]+');
  static final RegExp _trailingPunct = RegExp(r'[\s，。！？!?；;,.、．…⋯~～]+$');

  /// 從孩子的原話挑一段放進句子，最多 [budget] 個字（含截短時的省略號）。
  ///
  /// 依序試：整段原話（去掉結尾標點）→ 第一個放得下的子句 → 第一個子句截短加「⋯」。
  /// 回傳的 `quote` 一定是 [childWords] 的子字串；`display` 是放進句子裡的樣子。
  static ({String quote, String display})? pickQuote(String childWords, int budget) {
    final whole = childWords.trim().replaceFirst(_trailingPunct, '');
    if (whole.runes.length < minQuoteChars || budget < minQuoteChars) return null;
    if (whole.runes.length <= budget) return (quote: whole, display: whole);

    final segments = [
      for (final m in _segment.allMatches(whole))
        if (m.group(0)!.trim().runes.length >= minQuoteChars) m.group(0)!.trim(),
    ];
    for (final s in segments) {
      if (s.runes.length <= budget) return (quote: s, display: s);
    }
    final ellipsis = LessonCopy.quoteEllipsis.lively;
    final keep = budget - ellipsis.runes.length;
    if (segments.isEmpty || keep < minQuoteChars) return null;
    final cut = String.fromCharCodes(segments.first.runes.take(keep)).trim();
    if (cut.runes.length < minQuoteChars) return null;
    return (quote: cut, display: '$cut$ellipsis');
  }
}
