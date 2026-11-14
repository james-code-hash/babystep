/// 再看一次口袋（付費插件，決策 M1）的領域模型。純 Dart。
///
/// 刻意沒有的東西：分數、對錯、複習次數、「上次翻開」、到期日（底線 1、3、5）。
/// 孩子翻完按的那個鈕（[PocketFeeling]）也不存：存了就能被算成「弄懂率」。
library;

/// 口袋裡一張卡的科目。
enum PocketSubject { chinese, math, english, science, social, other }

/// 「卡在哪」：孩子自己選的，不是系統判斷的。
enum PocketStuck { tooFast, notYet, slip, question, unsure }

/// 翻完一張卡時孩子按的三個鈕之一。三個權重相同、都沒有後果、不存（底線 4）。
enum PocketFeeling { clearer, stillStuck, later }

/// 孩子能不能用口袋。由購買狀態算出來（第 2 段接商店；第 1 段只有 debug 開關）。
///
/// - [full]：買了或試用中，全部都能用。
/// - [readOnly]：試用到期或退款。已經放的卡照樣能看、能翻、能刪，只是不能放新的。
/// - [none]：從來沒有。孩子那邊完全看不到口袋。
enum PocketAccess { full, readOnly, none }

/// 一組卡，例如「11/7 數學小考」。名字是孩子取的。
class PocketGroup {
  const PocketGroup({required this.id, required this.name, required this.createdAt});
  final String id;
  final String name;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'createdAt': createdAt.toIso8601String()};
}

/// 孩子放進口袋的一張卡。每一格都可以不填。
class PocketCard {
  const PocketCard({
    required this.id,
    required this.subject,
    required this.createdAt,
    this.groupId,
    this.prompt,
    this.photo,
    this.thought,
    this.stuck,
    this.knowNow,
    this.ifCue,
    this.thenAction,
    this.filedAway = false,
    this.sharedWithParent = false,
  });

  final String id;
  final String? groupId;
  final PocketSubject subject;

  /// 題目的文字（孩子打的）。
  final String? prompt;

  /// 題目照片的檔名（存在 App 自己的資料夾，見 `PocketPhotoStore`）。
  final String? photo;

  /// 「我那時候怎麼想的」。
  final String? thought;
  final PocketStuck? stuck;

  /// 「現在我知道的」。可以先空著，之後再回來寫。
  final String? knowNow;

  /// 孩子自己寫的「如果⋯我就⋯」。
  final String? ifCue;
  final String? thenAction;

  /// 孩子把它「收好」了：還在，只是收到另一層。
  final bool filedAway;

  /// 孩子按了「給家長看」（底線 7：預設不分享）。
  final bool sharedWithParent;
  final DateTime createdAt;

  bool get hasIfThen => (ifCue?.trim().isNotEmpty ?? false) && (thenAction?.trim().isNotEmpty ?? false);

  Map<String, Object?> toJson() => {
        'id': id,
        'groupId': groupId,
        'subject': subject.name,
        'prompt': prompt,
        'photo': photo,
        'thought': thought,
        'stuck': stuck?.name,
        'knowNow': knowNow,
        'ifCue': ifCue,
        'thenAction': thenAction,
        'filedAway': filedAway,
        'sharedWithParent': sharedWithParent,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// 記卡畫面填好的內容。[id] 是 null 就是新的一張。
class PocketCardDraft {
  const PocketCardDraft({
    this.id,
    this.groupId,
    this.subject = PocketSubject.other,
    this.prompt,
    this.photo,
    this.thought,
    this.stuck,
    this.knowNow,
    this.ifCue,
    this.thenAction,
  });

  final String? id;
  final String? groupId;
  final PocketSubject subject;
  final String? prompt;
  final String? photo;
  final String? thought;
  final PocketStuck? stuck;
  final String? knowNow;
  final String? ifCue;
  final String? thenAction;

  /// 至少要有題目（文字或照片），其他都可以空著。
  bool get hasPrompt => (prompt?.trim().isNotEmpty ?? false) || photo != null;

  /// 孩子打的所有字（送出前一起過危機偵測，底線 9）。
  String get childWords => [prompt, thought, knowNow, ifCue, thenAction].whereType<String>().join('\n');
}
