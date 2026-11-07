import '../domain/pocket.dart';
import 'line.dart';

/// 再看一次口袋（M1）。放的是「我還在弄懂的地方」，不是錯題：
/// 不說對錯、不數張數、不催、不讚美結果（底線 1、3、4、5）。
abstract final class PocketCopy {
  static const title = Line('步步的再看一次口袋', '再看一次口袋');
  static const nav = Line('再看一次口袋', '口袋');

  static const empty = Line(
    '口袋現在空空的。考試或複習時卡住的題目，可以放進來給步步收著。',
    '口袋是空的。卡住的題目可以放進來。',
  );

  static const add = Line('放一張進口袋', '放一張');
  static const draw = Line('步步幫我抽一張', '隨手抽一張');
  static const nothingToDraw = Line('口袋裡現在沒有可以抽的卡。', '沒有可以抽的卡。');

  // ---------------------------------------------------------------- 篩選
  static const filterAll = Line.same('全部');
  static const filterFiledAway = Line.same('收好的');
  static const filterGroups = Line.same('一組一組看');

  // ---------------------------------------------------------------- 組
  static const groupTitle = Line('要放進哪一組？', '哪一組？');
  static const groupNone = Line.same('不分組');
  static const groupNew = Line('開一組新的', '新的一組');
  static const groupNameHint = Line('幫這一組取個名字，像是「11/7 數學小考」', '組名，例如「11/7 數學小考」');
  static const groupCreate = Line.same('開好了');
  static const cancel = Line.same('取消');

  // ---------------------------------------------------------------- 記一張
  static const editorTitle = Line('放一張進口袋', '放一張');
  static const editTitle = Line.same('改一改');
  static const promptTitle = Line('題目是什麼？', '題目');
  static const promptHint = Line('打幾個字，或拍一張照片', '打字或拍照');
  static const takePhoto = Line.same('拍照');
  static const pickPhoto = Line.same('從相簿挑');
  static const removePhoto = Line.same('拿掉照片');
  static const subjectTitle = Line('這是哪一科？', '科目');
  static const thoughtTitle = Line('你那時候怎麼想的？說給步步聽', '那時候怎麼想的？');
  static const thoughtHint = Line('想不起來也可以不寫。', '可以不寫。');
  static const stuckTitle = Line('你覺得卡在哪裡？', '卡在哪？');
  static const knowNowTitle = Line('現在你知道的是什麼？', '現在知道的');
  static const knowNowHint = Line('還不知道的話先空著，之後弄懂了再回來寫。', '先空著也可以，之後再寫。');
  static const ifThenTitle = Line('想給自己一句「如果⋯我就⋯」嗎？', '如果⋯我就⋯（可以不寫）');
  static const ifLabel = Line.same('如果');
  static const thenLabel = Line.same('我就');
  static const ifThenExample = Line('像是：如果看到應用題，我就先圈出它問什麼。', '例：如果看到應用題，我就先圈出它問什麼。');
  static const save = Line('放進口袋', '放進去');
  static const saveEdit = Line.same('改好了');
  static const needPrompt = Line('先寫題目或拍一張照片，步步才知道要收什麼。', '先放題目（文字或照片）。');

  // ---------------------------------------------------------------- 翻一張
  static const frontAsk = Line('要先自己想一想，還是直接翻過來看？', '先想一想，還是直接翻面？');
  static const thinkFirst = Line('我先想一想', '先想想');
  static const flip = Line('翻過來', '翻面');
  static const thinking = Line('想好了就翻過來吧。', '想好了再翻面。');
  static const thoughtLabel = Line.same('那時候怎麼想');
  static const stuckLabel = Line.same('卡在哪');
  static const knowNowLabel = Line.same('現在知道的');
  static const ifThenLabel = Line.same('如果⋯我就⋯');
  static const ifThenSentence = Line.same('如果{cue}，我就{action}。');
  static const blank = Line('（還空著）', '（空著）');
  static const feelingAsk = Line('翻完了，你覺得呢？', '翻完了，覺得呢？');

  static const fileAway = Line.same('收好');
  static const takeBack = Line('拿回口袋', '拿回來');
  static const edit = Line.same('改一改');
  static const share = Line.same('給家長看');
  static const shareExplain = Line('打開的話，家長會看到這整張卡，包括照片。', '打開的話，家長看得到整張卡和照片。');
  static const delete = Line('讓這張離開口袋', '刪掉這張');
  static const deleteAsk = Line('要讓這張離開口袋嗎？照片也會一起刪掉。', '要刪掉這張嗎？照片會一起刪掉。');
  static const deleteYes = Line.same('刪掉');
  static const deleteNo = Line('先留著', '留著');

  // ---------------------------------------------------------------- 首頁（只介紹一次）
  static const introBubu = Line(
    '步步多了一個「再看一次口袋」！卡住的題目可以放進來，想看再拿出來翻。',
    '多了一個「再看一次口袋」：卡住的題目可以放進去，想看再拿出來。',
  );
  static const introOpen = Line.same('去看看');
  static const introLater = Line.same('知道了');

  // ---------------------------------------------------------------- 我的設定
  static const settingTitle = Line.same('首頁顯示口袋');
  static const settingHint = Line('關掉的話，口袋會藏起來，裡面的卡都還在。', '關掉會藏起來，卡片都還在。');

  static Line subject(PocketSubject s) => switch (s) {
        PocketSubject.chinese => const Line.same('國語'),
        PocketSubject.math => const Line.same('數學'),
        PocketSubject.english => const Line.same('英文'),
        PocketSubject.science => const Line.same('自然'),
        PocketSubject.social => const Line.same('社會'),
        PocketSubject.other => const Line.same('其他'),
      };

  static Line stuck(PocketStuck s) => switch (s) {
        PocketStuck.tooFast => const Line.same('看太快'),
        PocketStuck.notYet => const Line.same('這個還不懂'),
        PocketStuck.slip => const Line.same('算錯或寫錯'),
        PocketStuck.question => const Line.same('題目看不懂'),
        PocketStuck.unsure => const Line.same('不知道'),
      };

  /// 三個鈕的字。三個一樣重（底線 4）。
  static Line feeling(PocketFeeling f) => switch (f) {
        PocketFeeling.clearer => const Line.same('比較清楚了'),
        PocketFeeling.stillStuck => const Line.same('還有一點卡'),
        PocketFeeling.later => const Line.same('先放著'),
      };

  /// 按完之後步步只好奇地問一句，不稱讚、不安慰、沒有後果（底線 4、5）。
  static Line reply(PocketFeeling f) => switch (f) {
        PocketFeeling.clearer => const Line('哪個地方變清楚了呢？步步好想知道。', '哪裡變清楚了？'),
        PocketFeeling.stillStuck => const Line('是卡在哪一步呢？', '卡在哪一步？'),
        PocketFeeling.later => const Line('好，步步先幫你收著。', '好，先收著。'),
      };
}

/// 家長區看到的口袋（只有孩子分享的卡）。
abstract final class PocketParentCopy {
  static const sharedTitle = Line.same('孩子分享的口袋卡');
  static const sharedNote = Line.same('這是孩子自己選擇給你看的卡。口袋裡其他的卡，這裡看不到。');
}
