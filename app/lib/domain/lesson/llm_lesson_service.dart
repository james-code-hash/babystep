import 'dart:async';

import '../../copy/safety.dart';
import '../../core/config.dart';
import '../../core/copy_rules.dart';
import '../../safety/crisis_detector.dart';
import '../lesson_service.dart';
import '../models.dart';
import 'template_lesson_service.dart';

/// 呼叫 LLM 代理（Cloud Function `bubuLearn`）的最小介面，方便測試換成 fake。
abstract interface class LessonLlmClient {
  /// 送出最小內容，回傳 `{learned, source_quote}`；失敗就丟例外。
  Future<Map<String, Object?>> bubuLearn(Map<String, Object?> payload);
}

/// 送給 LLM 代理的欄位名稱。只有這四個（B3、底線 8）。
abstract final class LlmPayloadKeys {
  static const childWords = 'childWords';
  static const task = 'task';
  static const outcome = 'outcome';
  static const tone = 'tone';

  static const all = {childWords, task, outcome, tone};
}

/// LLM 模式：逾時、驗證（source_quote 回溯、文案規則、字數）、重試、退回範本（C3、B3）。
///
/// 流程：
/// 1. 孩子沒說話、或話少於 [AppConfig.minChildWordsForLlm] 個字 → 不呼叫，直接用 [fallback]。
/// 2. 防禦性危機檢查：有 [crisisDetector] 且孩子的話命中 → 不呼叫，用 [fallback]
///    （正常情況畫面在呼叫 learn 之前就已經用 `passesSafetyCheck` 攔下，不會走到這裡）。
/// 3. 只送 [LlmPayloadKeys.all] 這四個欄位：孩子原話、第一件事的名稱、它的回顧狀態、語氣。
/// 4. 每次回應都驗證；不過就重試，最多重試 [maxRetries] 次（不含第一次）。
///    全部嘗試共用一個 [timeout]（預設 [AppConfig.llmTimeout]），超過就退回範本。
/// 5. 伺服器回 `{fallback: true}` → 立刻用範本；`{safety: true}` → 回傳 [LessonSource.safety]
///    的預寫句子（呼叫端不得把它存進筆記本，應顯示安全回應）。
/// 6. 永遠不丟例外。
///
/// 「在想」的提示（[AppConfig.llmThinkingAfter]，3 秒）由畫面自己計時顯示，不在這裡。
class LlmLessonService implements LessonService {
  LlmLessonService({
    required this.client,
    required this.fallback,
    required this.rules,
    this.crisisDetector,
    this.timeout = AppConfig.llmTimeout,
    this.maxRetries = AppConfig.llmMaxRetries,
  });

  final LessonLlmClient client;
  final LessonService fallback;
  final CopyRules rules;
  final CrisisDetector? crisisDetector;
  final Duration timeout;
  final int maxRetries;

  @override
  Future<LessonResult> learn(LessonRequest request) async {
    try {
      final payload = buildPayload(request);
      if (payload == null) return await _fallback(request);
      if (crisisDetector?.detect(request.childWords) != null) return await _fallback(request);

      final cancel = _Cancel();
      final outcome = await _attempts(request, payload, cancel).timeout(timeout, onTimeout: () {
        cancel.cancelled = true;
        return null;
      });
      return outcome ?? await _fallback(request);
    } catch (_) {
      return _fallback(request);
    }
  }

  /// 要送出的最小內容；不該呼叫 LLM 時回傳 null。
  static Map<String, Object?>? buildPayload(LessonRequest request) {
    final words = request.childWords?.trim() ?? '';
    if (!request.childSpoke || words.runes.length < AppConfig.minChildWordsForLlm) return null;
    if (request.outcomes.isEmpty || request.tasks.isEmpty) return null;
    return {
      LlmPayloadKeys.childWords: words,
      LlmPayloadKeys.task: request.tasks.first,
      LlmPayloadKeys.outcome: request.outcomes.first.name,
      LlmPayloadKeys.tone: request.tone.name,
    };
  }

  /// 回傳 null = 用範本。
  Future<LessonResult?> _attempts(LessonRequest request, Map<String, Object?> payload, _Cancel cancel) async {
    final words = payload[LlmPayloadKeys.childWords] as String;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (cancel.cancelled) return null;
      final Map<String, Object?> response;
      try {
        response = await client.bubuLearn(Map.of(payload));
      } catch (_) {
        continue;
      }
      if (cancel.cancelled) return null;
      if (response['safety'] == true) return safetyResult(request.tone);
      if (response['fallback'] == true) return null;
      final r = _validate(response, childWords: words, tone: request.tone);
      if (r == _plainDayMarker) return TemplateLessonService.plainDay(request.tone);
      if (r != null) return r;
    }
    return null;
  }

  static const _plainDayMarker = LessonResult(text: '', kind: LessonKind.plainDay, source: LessonSource.template);

  /// 驗證一次回應；不合格回傳 null。
  ///
  /// - `kind` 是 `plainDay`：模型判斷今天沒什麼特別要記的（LLM 規格 §6 風險二允許）。
  ///   改用我們自己預寫的平淡日句子，不用模型的字。
  /// - 其他：`learned` 不是空的、過文案規則（L1＋L2＋語氣＋字數）、不含危機訊號；
  ///   `source_quote` 不是空的，且真的是孩子原話的子字串（防編造）。
  LessonResult? _validate(Map<String, Object?> response, {required String childWords, required AgeTone tone}) {
    final kindName = response['kind'];
    final kind = kindName is String ? enumByName(LessonKind.values, kindName, LessonKind.selfKnowledge) : null;
    if (kind == LessonKind.plainDay) return _plainDayMarker;

    final learned = response['learned'];
    final quote = response['source_quote'];
    if (learned is! String || quote is! String) return null;
    final text = learned.trim();
    final q = quote.trim();
    if (text.isEmpty || q.isEmpty) return null;
    if (!rules.passesGenerated(text, tone)) return null;
    if (!childWords.trim().contains(q)) return null;
    if (crisisDetector?.detect(text) != null) return null;
    return LessonResult(text: text, kind: kind ?? LessonKind.selfKnowledge, source: LessonSource.llm, sourceQuote: q);
  }

  /// 伺服器端攔下危機內容時的結果。
  static LessonResult safetyResult(AgeTone tone) =>
      LessonResult(text: SafetyCopy.lessonSafety.of(tone), kind: LessonKind.plainDay, source: LessonSource.safety);

  Future<LessonResult> _fallback(LessonRequest request) async {
    try {
      return await fallback.learn(request);
    } catch (_) {
      return TemplateLessonService.plainDay(request.tone);
    }
  }
}

class _Cancel {
  bool cancelled = false;
}
