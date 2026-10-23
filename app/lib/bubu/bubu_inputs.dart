import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../providers.dart';

export '../core/clock.dart' show clockProvider, Clock;
export '../providers.dart' show randomProvider, toneProvider;

/// `bubu/` 目錄唯一能讀的 App 狀態：裝扮、時鐘、亂數、語氣（底線 2）。
/// `bubu/` 其他檔案不得 import providers.dart、data/、features/；只能透過這個檔案拿輸入。
/// `test/guardrails/` 會檢查這件事。
final bubuDressUpProvider = Provider<DressUp>((ref) => ref.watch(dressUpProvider).value ?? DressUp.initial);
