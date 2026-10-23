import 'dart:math';

import '../copy/bubu.dart';
import '../domain/models.dart';

/// 首頁問候。只能吃（語氣、日期時間、隨機）——不讀計畫、回顧、上次開啟（底線 2、3）。
///
/// TODO(build-b): 依早晚、季節抽句子。
String greeting(AgeTone tone, DateTime now, Random random) => BubuCopy.greetings.pick(tone, random);
