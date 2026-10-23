import 'line.dart';

/// 家長區（B4）。給大人看的字，兩種語氣說法一樣，但一樣要過文案規則。
abstract final class ParentCopy {
  static const title = Line.same('家長區');

  // ---------------------------------------------------------------- PIN
  static const pinSetTitle = Line.same('第一次進來，請設一組 {n} 位數密碼');
  static const pinConfirmTitle = Line.same('再輸入一次，確認密碼');
  static const pinEnterTitle = Line.same('請輸入家長密碼');
  static const pinMismatch = Line.same('兩次輸入的不一樣，請重新設定');
  static const pinWrong = Line.same('密碼不對，再試一次');
  static const pinNote = Line.same('這組密碼只是避免孩子誤入家長區，不是安全鎖。');
  static const pinBackspace = Line.same('刪掉一個數字');

  // ---------------------------------------------------------------- 首頁
  static const intro = Line.same('這裡只放設定，以及孩子主動分享給你的筆記。');

  // ---------------------------------------------------------------- 事情範本
  static const tasksTitle = Line.same('事情範本');
  static const tasksNote = Line.same('這些是給孩子挑的選項。孩子可以不選，也可以自己寫。');
  static const addTask = Line.same('新增一件事');
  static const editTask = Line.same('修改這件事');
  static const taskEmojiLabel = Line.same('圖示（一個表情符號）');
  static const taskTextLabel = Line.same('事情');
  static const restoreDefaults = Line.same('還原預設範本');
  static const restoreConfirmTitle = Line.same('還原預設範本？');
  static const restoreConfirmBody =
      Line.same('事情範本和時間點範本會回到一開始的樣子，你加的範本會被移除。孩子自己寫的事情不受影響。');
  static const restoreConfirm = Line.same('還原');

  // ---------------------------------------------------------------- 時間點範本
  static const cuesTitle = Line.same('時間點範本');
  static const cuesNote = Line.same('孩子會拼成「如果我⋯，我就⋯」。輸入時會自動補上「我」開頭。');
  static const addCue = Line.same('新增時間點');
  static const editCue = Line.same('修改時間點');
  static const cueTextLabel = Line.same('時間點（例如：我吃完晚飯）');

  // ---------------------------------------------------------------- 提醒時段
  static const slotsTitle = Line.same('提醒時段');
  static const slotsNote = Line.same('孩子在這些時段打開 App、而且當天有計畫時，步步會探頭打個招呼。不會發推播。');
  static const addSlot = Line.same('新增時段');
  static const editSlot = Line.same('修改時段');
  static const slotLabel = Line.same('名稱（例如：放學後）');
  static const slotStart = Line.same('開始');
  static const slotEnd = Line.same('結束');
  static const slotRange = Line.same('{start}–{end}');
  static const slotInvalid = Line.same('結束時間要比開始時間晚');
  static const slotsEmpty = Line.same('目前沒有提醒時段，步步不會探頭。');

  // ---------------------------------------------------------------- 說話方式
  static const toneTitle = Line.same('預設說話方式');
  static const toneNote = Line.same('步步對孩子說話的語氣。孩子也可以在自己的設定裡改。');
  static const toneLively = Line.same('活潑');
  static const toneConcise = Line.same('簡潔');

  // ---------------------------------------------------------------- LLM
  static const llmTitle = Line.same('讓步步用 AI 想句子');
  static const llmOff = Line.same('關閉時：步步用內建的句子，完全離線。');
  static const llmOn =
      Line.same('開啟時：只會送出孩子今晚說的那幾個字、當天的一件事和語氣，供應商不保留、不拿去訓練。連不上就自動改用內建句子。');
  static const llmDevOnly = Line.same('目前只在開發用的模擬環境能用。');

  // ---------------------------------------------------------------- 資料
  static const dataTitle = Line.same('資料');
  static const exportButton = Line.same('匯出全部資料');
  static const exportNote = Line.same('匯出檔是完整資料，包含每天的計畫、回顧的狀態和孩子寫下的話。請和孩子一起決定要不要打開。');
  static const exportSubject = Line.same('小步 Little Steps 資料匯出');
  static const deleteButton = Line.same('刪除全部資料');
  static const deleteNote = Line.same('所有計畫、筆記、範本和設定都會從這台裝置刪掉，無法復原。');
  static const deleteConfirmTitle = Line.same('真的要刪除全部資料嗎？');
  static const deleteConfirmBody = Line.same('刪掉之後就找不回來了。建議先匯出一份。');
  static const deleteContinue = Line.same('繼續');
  static const deleteTypeTitle = Line.same('最後確認');
  static const deleteTypeBody = Line.same('請輸入「{word}」兩個字來確認。');
  static const deleteConfirmWord = Line.same('刪除');
  static const deleteFinal = Line.same('永久刪除');
  static const deleted = Line.same('資料已經刪除。');

  // ---------------------------------------------------------------- 分享的筆記
  static const sharedTitle = Line.same('孩子分享給你的筆記');
  static const sharedNote = Line.same('這些是孩子自己選了要給你看的。可以問問他：那是怎麼想到的？');
  static const sharedEmpty = Line.same('目前沒有分享的筆記。要不要分享，由孩子決定。');
  static const sharedDate = Line.same('{m}月{d}日');

  // ---------------------------------------------------------------- 共用
  static const edit = Line.same('修改');
  static const delete = Line.same('刪除');
  static const add = Line.same('新增');
  static const save = Line.same('儲存');
  static const cancel = Line.same('取消');
  static const lock = Line.same('離開家長區');
}
