import '../../core/copy_rules.dart';
import '../lesson_service.dart';

/// 呼叫 LLM 代理（Cloud Function `bubuLearn`）的最小介面，方便測試換成 fake。
abstract interface class LessonLlmClient {
  /// 送出最小內容，回傳 `{learned, source_quote}`；失敗就丟例外。
  Future<Map<String, Object?>> bubuLearn(Map<String, Object?> payload);
}

/// LLM 模式：逾時、驗證（source_quote 回溯、文案規則、字數）、重試、退回範本（C3、B3）。
///
/// TODO(build-c): 完整實作。
class LlmLessonService implements LessonService {
  LlmLessonService({required this.client, required this.fallback, required this.rules});

  final LessonLlmClient client;
  final LessonService fallback;
  final CopyRules rules;

  @override
  Future<LessonResult> learn(LessonRequest request) => fallback.learn(request);
}
