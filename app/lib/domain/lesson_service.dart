import 'models.dart';

/// 「步步學到」的輸入。只放當次需要的最小內容（B3、底線 8）。
class LessonRequest {
  const LessonRequest({
    required this.outcomes,
    required this.tasks,
    required this.tone,
    this.childWords,
  });

  /// 今天每件計畫的回顧狀態，順序與 [tasks] 相同。
  final List<Outcome> outcomes;

  /// 今天每件計畫的事情名稱。
  final List<String> tasks;
  final AgeTone tone;

  /// 孩子對歷程問題的原話；跳過就是 null。
  final String? childWords;

  bool get childSpoke => (childWords?.trim().length ?? 0) > 0;
}

/// 「步步學到」的結果。
class LessonResult {
  const LessonResult({required this.text, required this.kind, required this.source, this.sourceQuote});
  final String text;
  final LessonKind kind;
  final LessonSource source;

  /// 孩子原話裡的一段（LLM 結果才有；必須是 childWords 的子字串）。
  final String? sourceQuote;
}

/// 步步學到一件事。實作：範本引擎（離線）與 LLM（連線，失敗退回範本）。
///
/// 約定：
/// - 孩子沒說話 → 不呼叫 LLM。
/// - 永遠會回傳一句通過文案規則的句子（最差就是範本）；不會丟例外給畫面。
/// - 危機內容在呼叫之前就被攔下，不會進到這裡。
abstract interface class LessonService {
  Future<LessonResult> learn(LessonRequest request);
}
