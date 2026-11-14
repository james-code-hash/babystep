import 'line.dart';

/// 全 App 共用的短句（按鈕、標題）。各畫面自己的句子放在 `copy/<畫面>.dart`。
abstract final class CommonCopy {
  static const appName = Line.same('小步');
  static const bubuName = Line.same('步步');
  static const next = Line('下一步', '下一步');
  static const back = Line.same('上一步');
  static const skip = Line('先跳過', '跳過');
  static const done = Line.same('好了');
  static const cancel = Line.same('取消');
  static const save = Line.same('存起來');
  static const close = Line.same('關掉');
  static const yes = Line.same('好');
  static const no = Line.same('不用');
  static const writeMyOwn = Line('我自己寫', '自己寫');
  static const placeholderScreen = Line('這裡還在準備中', '準備中');
}

/// 內建的預設範本（家長可以改、刪、還原）。孩子自己寫的會另外存進孩子的事情庫。
abstract final class DefaultTemplates {
  /// (emoji, 事情)
  static const tasks = <(String, String)>[
    ('✏️', '寫數學作業'),
    ('📖', '看一本書'),
    ('🎹', '練習樂器'),
    ('🎒', '整理書包'),
    ('🧹', '收拾玩具'),
    ('🍽️', '幫忙收碗'),
    ('🤸', '動一動身體'),
    ('🪥', '自己刷牙'),
  ];

  /// 時間點，一律以「我」開頭。
  static const cues = <String>[
    '我吃完晚飯',
    '我放學回到家',
    '我洗完澡',
    '我吃完早餐',
    '我喝完水',
    '我換好衣服',
  ];

  /// 預設提醒時段：(名稱, 開始分鐘, 結束分鐘)。
  static const reminderSlots = <(String, int, int)>[
    ('放學後', 16 * 60, 18 * 60),
    ('吃完晚飯', 19 * 60, 20 * 60 + 30),
  ];
}
