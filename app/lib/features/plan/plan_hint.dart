import '../../copy/plan.dart';

/// 計畫品質提示（MCII，決策 I5）：「如果⋯我就⋯」太模糊時，步步問一個問題，不代寫。
enum PlanHint { taskVague, taskNegative, cueVague }

/// 這個計畫可以問的問題，先事情、再時間點（畫面一次只問第一個還沒說「這樣就好」的）。
List<PlanHint> planHintsFor({required String task, String? cue}) => [
      if (PlanCopy.negativeTaskWords.any(task.contains))
        PlanHint.taskNegative
      else if (PlanCopy.vagueTaskWords.any(task.contains))
        PlanHint.taskVague,
      if (cue != null && PlanCopy.vagueCueWords.any(cue.contains)) PlanHint.cueVague,
    ];

/// 第一個要問的；看不出問題就回傳 null。
PlanHint? planHintFor({required String task, String? cue}) {
  final all = planHintsFor(task: task, cue: cue);
  return all.isEmpty ? null : all.first;
}
