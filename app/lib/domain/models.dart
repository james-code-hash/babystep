/// 純 Dart 的領域模型。不依賴 Flutter、不依賴 drift。
///
/// 刻意沒有的東西：心情（C2，不存）、「上次開啟」（底線 3）、完成率、連續天數（底線 1）。
library;

/// 步步說話的方式（B5）。lively ≈ 6–8 歲，concise ≈ 9–12 歲；畫面上不標年齡。
enum AgeTone { lively, concise }

/// 一件計畫的回顧狀態。三種狀態權重相同（底線 4）。
enum Outcome { done, partly, notToday }

/// 步步學到的事屬於哪一類（LLM 規格 §5.2 + 平淡日）。
enum LessonKind { method, selfKnowledge, feeling, world, choice, plainDay }

/// 一則筆記的來源。
enum LessonSource { template, llm, safety }

/// 範本是誰放的：內建預設、家長加的、孩子自己寫的（孩子的事情庫）。
enum TemplateOrigin { preset, parent, child }

T enumByName<T extends Enum>(List<T> values, String name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// 可以挑的事情。
class TaskTemplate {
  const TaskTemplate({
    required this.id,
    required this.emoji,
    required this.text,
    required this.origin,
    this.sortOrder = 0,
  });

  final String id;
  final String emoji;
  final String text;
  final TemplateOrigin origin;
  final int sortOrder;

  /// 家長建議的事（畫面上要標「可以不選」）。
  bool get suggestedByParent => origin == TemplateOrigin.parent;

  TaskTemplate copyWith({String? emoji, String? text, int? sortOrder}) => TaskTemplate(
        id: id,
        emoji: emoji ?? this.emoji,
        text: text ?? this.text,
        origin: origin,
        sortOrder: sortOrder ?? this.sortOrder,
      );

  Map<String, Object?> toJson() =>
      {'id': id, 'emoji': emoji, 'text': text, 'origin': origin.name, 'sortOrder': sortOrder};
}

/// 時間點範本。文字一律以「我」開頭（如「我吃完晚飯」），才能拼成「如果我吃完晚飯，我就⋯」。
class CueTemplate {
  const CueTemplate({
    required this.id,
    required this.text,
    required this.origin,
    this.sortOrder = 0,
  });

  final String id;
  final String text;
  final TemplateOrigin origin;
  final int sortOrder;

  /// 把孩子輸入的時間點補成「我⋯」開頭。
  static String normalize(String raw) {
    var t = raw.trim();
    if (t.startsWith('如果')) t = t.substring(2).trim();
    if (!t.startsWith('我')) t = '我$t';
    return t;
  }

  Map<String, Object?> toJson() =>
      {'id': id, 'text': text, 'origin': origin.name, 'sortOrder': sortOrder};
}

/// 今天的一件事，寫成「如果⋯我就⋯」。
class Plan {
  const Plan({
    required this.id,
    required this.dayKey,
    required this.order,
    required this.emoji,
    required this.task,
    required this.cue,
    this.why,
    this.outcome,
  });

  final String id;
  final String dayKey;
  final int order;
  final String emoji;

  /// 「我就⋯」那一槽（孩子挑的或自己寫的事情）。
  final String task;

  /// 「如果⋯」那一槽，以「我」開頭。
  final String cue;
  final String? why;
  final Outcome? outcome;

  /// 「如果我吃完晚飯，我就寫數學」。
  String get ifThen => '如果$cue，我就$task';

  Plan copyWith({Outcome? outcome, String? why}) => Plan(
        id: id,
        dayKey: dayKey,
        order: order,
        emoji: emoji,
        task: task,
        cue: cue,
        why: why ?? this.why,
        outcome: outcome ?? this.outcome,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'dayKey': dayKey,
        'order': order,
        'emoji': emoji,
        'task': task,
        'cue': cue,
        'why': why,
        'outcome': outcome?.name,
      };
}

/// 計畫草稿（還沒存進資料庫）。
class PlanDraft {
  const PlanDraft({required this.emoji, required this.task, required this.cue, this.why});
  final String emoji;
  final String task;
  final String cue;
  final String? why;
}

/// 一天的紀錄：晚上的反思原話與結束時間。
class DayRecord {
  const DayRecord({required this.dayKey, this.reflection, this.endedAt});
  final String dayKey;
  final String? reflection;
  final DateTime? endedAt;

  bool get ended => endedAt != null;

  Map<String, Object?> toJson() =>
      {'dayKey': dayKey, 'reflection': reflection, 'endedAt': endedAt?.toIso8601String()};
}

/// 步步學到的一件事（筆記本的一頁）。
class Lesson {
  const Lesson({
    required this.id,
    required this.dayKey,
    required this.text,
    required this.kind,
    required this.source,
    required this.createdAt,
    this.sourceQuote,
    this.favorite = false,
    this.sharedWithParent = false,
  });

  final String id;
  final String dayKey;
  final String text;
  final LessonKind kind;
  final String? sourceQuote;
  final bool favorite;
  final bool sharedWithParent;
  final LessonSource source;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'dayKey': dayKey,
        'text': text,
        'kind': kind.name,
        'sourceQuote': sourceQuote,
        'favorite': favorite,
        'sharedWithParent': sharedWithParent,
        'source': source.name,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// 步步的裝扮。只因孩子主動裝扮而改變（底線 2）。各欄位是 `bubu/` 目錄裡的配件 id。
class DressUp {
  const DressUp({this.hat = 'none', this.neck = 'none', this.color = 'cream'});
  final String hat;
  final String neck;
  final String color;

  static const DressUp initial = DressUp();

  DressUp copyWith({String? hat, String? neck, String? color}) =>
      DressUp(hat: hat ?? this.hat, neck: neck ?? this.neck, color: color ?? this.color);

  Map<String, Object?> toJson() => {'hat': hat, 'neck': neck, 'color': color};

  factory DressUp.fromJson(Map<String, Object?> j) => DressUp(
        hat: (j['hat'] as String?) ?? 'none',
        neck: (j['neck'] as String?) ?? 'none',
        color: (j['color'] as String?) ?? 'cream',
      );

  @override
  bool operator ==(Object other) =>
      other is DressUp && other.hat == hat && other.neck == neck && other.color == color;

  @override
  int get hashCode => Object.hash(hat, neck, color);
}

/// 家長設定的提醒時段（B1：孩子在這個時段打開 App，步步探頭）。以一天中的分鐘數表示。
class ReminderSlot {
  const ReminderSlot({required this.id, required this.label, required this.startMinute, required this.endMinute});
  final String id;
  final String label;
  final int startMinute;
  final int endMinute;

  bool contains(DateTime t) {
    final m = t.hour * 60 + t.minute;
    return m >= startMinute && m < endMinute;
  }

  Map<String, Object?> toJson() =>
      {'id': id, 'label': label, 'startMinute': startMinute, 'endMinute': endMinute};

  factory ReminderSlot.fromJson(Map<String, Object?> j) => ReminderSlot(
        id: j['id'] as String,
        label: j['label'] as String,
        startMinute: j['startMinute'] as int,
        endMinute: j['endMinute'] as int,
      );
}

/// 設定。注意：沒有「上次開啟」之類的欄位。
class AppSettings {
  const AppSettings({
    this.tone = AgeTone.lively,
    this.llmEnabled = false,
    this.reminderSlots = const [],
    this.parentPin,
    this.onboarded = false,
  });

  final AgeTone tone;
  final bool llmEnabled;
  final List<ReminderSlot> reminderSlots;

  /// 家長 PIN。不是資安機制，只是避免孩子誤入（B4）。不進匯出檔、不進 ParentView。
  final String? parentPin;
  final bool onboarded;

  AppSettings copyWith({
    AgeTone? tone,
    bool? llmEnabled,
    List<ReminderSlot>? reminderSlots,
    String? parentPin,
    bool? onboarded,
  }) =>
      AppSettings(
        tone: tone ?? this.tone,
        llmEnabled: llmEnabled ?? this.llmEnabled,
        reminderSlots: reminderSlots ?? this.reminderSlots,
        parentPin: parentPin ?? this.parentPin,
        onboarded: onboarded ?? this.onboarded,
      );
}
