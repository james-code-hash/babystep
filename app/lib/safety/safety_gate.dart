import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// 自由輸入送出前呼叫。沒問題回傳 true；命中危機訊號就顯示預寫的安全回應，回傳 false
/// （呼叫端不得存這段文字、不得送 LLM）。
///
/// TODO(build-c): 顯示安全回應畫面（`safety_response.dart`）。
Future<bool> passesSafetyCheck(BuildContext context, WidgetRef ref, String text) async {
  final hit = ref.read(crisisDetectorProvider).detect(text);
  return hit == null;
}
