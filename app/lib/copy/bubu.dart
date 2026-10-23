import 'line.dart';

/// 步步自己說的話（問候、表情旁白）。TODO(build-b): 依早晚、季節擴充。
abstract final class BubuCopy {
  static const greetings = LinePool([
    Line('嗨～步步在這裡！', '嗨。今天如何？'),
    Line('你來了！今天過得怎麼樣？', '你來了。今天怎麼樣？'),
  ]);
}
