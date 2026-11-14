import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'safety_response.dart';

/// 自由輸入送出前呼叫。沒問題回傳 true；命中危機訊號就顯示預寫的安全回應（[SafetyResponseScreen]），
/// 等孩子關掉之後回傳 false（呼叫端不得存這段文字、不得送 LLM）。
///
/// 不存、不記錄、不通知家長（docs/decisions.md C6）。
Future<bool> passesSafetyCheck(BuildContext context, WidgetRef ref, String text) async {
  final detector = ref.read(crisisDetectorProvider);
  final hit = detector.detect(text);
  if (hit == null) return true;
  if (context.mounted) await SafetyResponseScreen.show(context, hit);
  return false;
}
