import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../copy/settings.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../providers.dart';

/// 把步步說的話唸出來（決策 I6）。只用裝置內建的語音，文字不離開裝置、不存。
abstract class Speaker {
  /// 這台裝置能不能唸（沒有語音引擎的平台，例如 Linux 桌面版，就不顯示朗讀）。
  bool get available;
  Future<void> speak(String text);
  Future<void> stop();
}

/// 裝置內建的文字轉語音（iOS／Android／macOS／Windows）。
class DeviceSpeaker implements Speaker {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  @override
  bool get available =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows);

  Future<void> _setUp() async {
    if (_ready) return;
    await _tts.setLanguage(ReadAloudConfig.language);
    await _tts.setSpeechRate(ReadAloudConfig.rate);
    await _tts.setPitch(ReadAloudConfig.pitch);
    _ready = true;
  }

  @override
  Future<void> speak(String text) async {
    if (!available) return;
    try {
      await _setUp();
      await _tts.stop();
      await _tts.speak(text);
    } on Object {
      // 唸不出來就算了：朗讀是輔助，不能讓畫面壞掉。
    }
  }

  @override
  Future<void> stop() async {
    if (!available) return;
    try {
      await _tts.stop();
    } on Object {
      // 同上。
    }
  }
}

final speakerProvider = Provider<Speaker>((ref) => DeviceSpeaker());

/// 孩子在設定裡打開、而且這台裝置能唸，才顯示朗讀按鈕。
final readAloudOnProvider = Provider<bool>(
  (ref) =>
      ref.watch(speakerProvider).available && (ref.watch(settingsProvider.select((s) => s.value?.readAloud)) ?? false),
);

/// 步步的對話泡泡：朗讀打開時，在句子旁邊多一顆「唸出來」，點了才唸（不自動出聲）。
/// 離開畫面、句子換了、或關掉朗讀時，正在唸的就停下來。
class ReadAloud extends ConsumerStatefulWidget {
  const ReadAloud({super.key, required this.text, required this.child});

  final String text;
  final Widget child;

  @override
  ConsumerState<ReadAloud> createState() => _ReadAloudState();
}

class _ReadAloudState extends ConsumerState<ReadAloud> {
  /// 這個泡泡唸過（還可能在唸）。
  Speaker? _speaking;

  void _stop() {
    _speaking?.stop();
    _speaking = null;
  }

  @override
  void didUpdateWidget(ReadAloud old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _stop();
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    // 上面蓋了別的畫面（例如從首頁點進設定）：這裡唸到一半就停。
    final covered = !(ModalRoute.of(context)?.isCurrent ?? true);
    if (covered && _speaking != null) _stop();
    if (!ref.watch(readAloudOnProvider)) {
      if (_speaking != null) _stop();
      return child;
    }
    final tone = ref.watch(toneProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: child),
        const SizedBox(width: AppSpace.xs),
        IconButton(
          key: const ValueKey('read-aloud'),
          tooltip: SettingsCopy.readAloudButton.of(tone),
          icon: const Icon(Icons.volume_up_outlined, color: AppColors.inkSoft),
          onPressed: () {
            final speaker = ref.read(speakerProvider);
            _speaking = speaker;
            speaker.speak(widget.text);
          },
        ),
      ],
    );
  }
}
