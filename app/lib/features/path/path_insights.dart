import '../../data/repository.dart';
import 'path_config.dart';

/// 小路下方的「只跟自己比」的發現（C5）。純函式、只吃 [PlannedDay]（本來就沒有 outcome）。
///
/// 刻意沒有：完成率、平均、「最好的一天」、連著幾天、跟別人比。
class PathInsights {
  const PathInsights({this.topCue, this.topTask, required this.daysThisMonth});

  /// 最常用的時間點（原樣，以「我」開頭）；不夠多就是 null。
  final String? topCue;

  /// 最常排的事情；不夠多就是 null。
  final String? topTask;

  /// 這個月（[monthOf] 的年月）有想計畫的天數。
  final int daysThisMonth;

  static PathInsights from(List<PlannedDay> days, DateTime monthOf) {
    String two(int n) => n.toString().padLeft(2, '0');
    final prefix = '${monthOf.year.toString().padLeft(4, '0')}-${two(monthOf.month)}-';
    return PathInsights(
      topCue: _mostCommon([for (final d in days) ...d.cues]),
      topTask: _mostCommon([for (final d in days) ...d.tasks]),
      daysThisMonth: days.where((d) => d.dayKey.startsWith(prefix)).length,
    );
  }

  /// 出現最多次的（至少 [PathConfig.insightMinRepeats] 次）；同樣多次時取最近用過的。
  static String? _mostCommon(List<String> items) {
    final count = <String, int>{};
    final lastIndex = <String, int>{};
    for (final (i, raw) in items.indexed) {
      final s = raw.trim();
      if (s.isEmpty) continue;
      count[s] = (count[s] ?? 0) + 1;
      lastIndex[s] = i;
    }
    String? best;
    for (final s in count.keys) {
      if (count[s]! < PathConfig.insightMinRepeats) continue;
      if (best == null ||
          count[s]! > count[best]! ||
          (count[s]! == count[best]! && lastIndex[s]! > lastIndex[best]!)) {
        best = s;
      }
    }
    return best;
  }
}
