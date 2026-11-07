import 'models.dart';
import 'pocket.dart';

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
    this.familyToday = const [],
    this.familyNotes = const [],
    this.monthLetters = const [],
    this.sharedPocketCards = const [],
  });

  /// 家長與預設範本（孩子自己寫的事情庫不在這裡）。
  final List<TaskTemplate> taskTemplates;
  final List<CueTemplate> cueTemplates;
  final ParentSettingsView settings;

  /// 孩子主動按了「給家長看」的筆記。
  final List<SharedLesson> sharedLessons;

  /// 家人自己寫的「今天的我」（今天的）。
  final List<FamilyTodayView> familyToday;

  /// 家人留給孩子的話。刻意沒有「孩子看過了沒」（沒有已讀回條）。
  final List<FamilyNoteView> familyNotes;

  /// 月回顧的信（新的月份在前）。孩子那一句只有孩子自己寫了才有——寫給家人本身就是孩子的分享動作。
  final List<MonthLettersView> monthLetters;

  /// 孩子在口袋裡按了「給家長看」的卡（M1）。整張照原樣給，但不帶孩子翻完時按的感覺、收好沒、日期。
  final List<SharedPocketCard> sharedPocketCards;

  Map<String, Object?> toJson() => {
        'taskTemplates': [for (final t in taskTemplates) t.toJson()],
        'cueTemplates': [for (final c in cueTemplates) c.toJson()],
        'settings': settings.toJson(),
        'sharedLessons': [for (final l in sharedLessons) l.toJson()],
        'familyToday': [for (final f in familyToday) f.toJson()],
        'familyNotes': [for (final n in familyNotes) n.toJson()],
        'monthLetters': [for (final m in monthLetters) m.toJson()],
        'sharedPocketCards': [for (final c in sharedPocketCards) c.toJson()],
      };
}

/// 一個月的兩封信。
class MonthLettersView {
  const MonthLettersView({required this.month, this.child, this.parent});

  /// 'YYYY-MM'
  final String month;
  final String? child;
  final String? parent;

  Map<String, Object?> toJson() => {
        'month': month,
        if (child != null) 'child': child,
        if (parent != null) 'parent': parent,
      };
}

/// 家長寫的「今天的我」：家長自己寫的東西，原樣給家長看。
class FamilyTodayView {
  const FamilyTodayView({required this.id, required this.who, required this.text});
  final String id;
  final String who;
  final String text;

  Map<String, Object?> toJson() => {'id': id, 'who': who, 'text': text};
}

/// 家長留的話：只有家長自己寫的內容與日期，沒有孩子看過了沒。
class FamilyNoteView {
  const FamilyNoteView({required this.id, required this.dayKey, required this.who, required this.text});
  final String id;
  final String dayKey;
  final String who;
  final String text;

  Map<String, Object?> toJson() => {'id': id, 'dayKey': dayKey, 'who': who, 'text': text};
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

/// 孩子分享的一張口袋卡。刻意沒有：feeling（翻完時按的）、filedAway、createdAt。
class SharedPocketCard {
  const SharedPocketCard({
    required this.id,
    required this.subject,
    this.prompt,
    this.photo,
    this.thought,
    this.stuck,
    this.knowNow,
    this.ifCue,
    this.thenAction,
  });

  factory SharedPocketCard.of(PocketCard c) => SharedPocketCard(
        id: c.id,
        subject: c.subject,
        prompt: c.prompt,
        photo: c.photo,
        thought: c.thought,
        stuck: c.stuck,
        knowNow: c.knowNow,
        ifCue: c.ifCue,
        thenAction: c.thenAction,
      );

  final String id;
  final PocketSubject subject;
  final String? prompt;
  final String? photo;
  final String? thought;
  final PocketStuck? stuck;
  final String? knowNow;
  final String? ifCue;
  final String? thenAction;

  Map<String, Object?> toJson() => {
        'id': id,
        'subject': subject.name,
        if (prompt != null) 'prompt': prompt,
        if (photo != null) 'photo': photo,
        if (thought != null) 'thought': thought,
        if (stuck != null) 'stuck': stuck!.name,
        if (knowNow != null) 'knowNow': knowNow,
        if (ifCue != null) 'ifCue': ifCue,
        if (thenAction != null) 'thenAction': thenAction,
      };
}
