import 'dart:math';

import '../copy/line.dart';
import '../copy/surprise.dart';
import '../core/config.dart';
import 'bubu_expression.dart';

/// 今天探索角有沒有驚喜盒：只看日期（同一天結果一樣），跟孩子做了什麼無關，也不規律。
bool surpriseBoxOn(DateTime now) {
  final seed = now.year * 10000 + now.month * 100 + now.day;
  return Random(seed).nextDouble() < SurpriseConfig.boxChance;
}

/// 盒子裡的東西：一句步步的小故事＋一個表情。
(Line, BubuExpression) pickSurprise(Random random) {
  const faces = [BubuExpression.surprised, BubuExpression.happy, BubuExpression.relaxed];
  return (SurpriseCopy.stories.pickLine(random), faces[random.nextInt(faces.length)]);
}
