import 'models.dart';

/// 家長端能讀到的全部資料（底線 7）。家長區只能讀這個型別，不能直接碰 repository 的其他查詢。
///
/// 刻意沒有：outcome、完成率、心情、使用時長、反思原話、孩子沒分享的筆記。
/// `test/guardrails/` 有 key 白名單測試鎖住 [toJson] 的欄位。
class ParentView {
  const ParentView({
    required this.taskTemplates,
    required this.cueTemplates,
    required this.settings,
    required this.sharedLessons,
  });

  /// 家長與預設範本（孩子自己寫的事情庫不在這裡）。
  final List<TaskTemplate> taskTemplates;
  final List<CueTemplate> cueTemplates;
  final ParentSettingsView settings;

  /// 孩子主動按了「給家長看」的筆記。
  final List<SharedLesson> sharedLessons;

  Map<String, Object?> toJson() => {
        'taskTemplates': [for (final t in taskTemplates) t.toJson()],
        'cueTemplates': [for (final c in cueTemplates) c.toJson()],
        'settings': settings.toJson(),
        'sharedLessons': [for (final l in sharedLessons) l.toJson()],
      };
}

class ParentSettingsView {
  const ParentSettingsView({required this.tone, required this.llmEnabled, required this.reminderSlots});
  final AgeTone tone;
  final bool llmEnabled;
  final List<ReminderSlot> reminderSlots;

  Map<String, Object?> toJson() => {
        'tone': tone.name,
        'llmEnabled': llmEnabled,
        'reminderSlots': [for (final s in reminderSlots) s.toJson()],
      };
}

/// 孩子分享的一則筆記：只有句子本身和日期。
class SharedLesson {
  const SharedLesson({required this.id, required this.dayKey, required this.text});
  final String id;
  final String dayKey;
  final String text;

  Map<String, Object?> toJson() => {'id': id, 'dayKey': dayKey, 'text': text};
}
