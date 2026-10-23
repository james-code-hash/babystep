import 'dart:math';

import '../../core/copy_rules.dart';
import '../lesson_service.dart';
import '../models.dart';

/// 離線的範本引擎（C3）。
///
/// TODO(build-c): 依 (outcome × 孩子有沒有說話 × 語氣) 抽句子，三種 outcome 的池一樣大。
class TemplateLessonService implements LessonService {
  TemplateLessonService({required this.rules, required this.random});

  final CopyRules rules;
  final Random random;

  @override
  Future<LessonResult> learn(LessonRequest request) async => const LessonResult(
        text: '今天沒什麼特別要記的，就是普通的一天。',
        kind: LessonKind.plainDay,
        source: LessonSource.template,
      );
}
