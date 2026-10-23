import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../copy/line.dart';
import '../../copy/parent.dart';
import '../../core/config.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import 'parent_home.dart';
import 'pin_pad.dart';

enum _Stage { create, confirm, verify, open }

/// 家長區入口：第一次設 PIN（輸入兩次），之後每次進來都要輸入（B4，不是資安機制）。
///
/// 通過之後家長區內容直接在這個畫面裡顯示（不另外開路由），所以沒辦法用網址繞過 PIN。
/// 存好的 PIN 從 [settingsProvider] 讀（[ParentView] 刻意不帶 PIN）。
class ParentGateScreen extends ConsumerStatefulWidget {
  const ParentGateScreen({super.key});

  @override
  ConsumerState<ParentGateScreen> createState() => _ParentGateScreenState();
}

class _ParentGateScreenState extends ConsumerState<ParentGateScreen> {
  /// null：還沒開始輸入，依有沒有存過 PIN 決定是「設定」還是「輸入」。
  _Stage? _stage;
  String _entry = '';
  String? _firstEntry;
  Line? _message;

  _Stage _currentStage(String? savedPin) => _stage ?? (savedPin == null ? _Stage.create : _Stage.verify);

  void _digit(String d, String? savedPin) {
    if (_entry.length >= AppConfig.parentPinLength) return;
    setState(() {
      _entry += d;
      _message = null;
    });
    if (_entry.length == AppConfig.parentPinLength) _submit(savedPin);
  }

  void _backspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  Future<void> _submit(String? savedPin) async {
    final entry = _entry;
    switch (_currentStage(savedPin)) {
      case _Stage.create:
        setState(() {
          _firstEntry = entry;
          _entry = '';
          _stage = _Stage.confirm;
        });
      case _Stage.confirm:
        if (entry == _firstEntry) {
          await ref.read(repositoryProvider).setParentPin(entry);
          if (!mounted) return;
          setState(() {
            _firstEntry = null;
            _entry = '';
            _stage = _Stage.open;
          });
        } else {
          setState(() {
            _firstEntry = null;
            _entry = '';
            _stage = _Stage.create;
            _message = ParentCopy.pinMismatch;
          });
        }
      case _Stage.verify:
        setState(() {
          _entry = '';
          if (entry == savedPin) {
            _stage = _Stage.open;
          } else {
            _message = ParentCopy.pinWrong;
          }
        });
      case _Stage.open:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(Line l) => l.of(AgeTone.concise);
    if (_stage == _Stage.open) return const ParentHome();
    final settings = ref.watch(settingsProvider);
    final loaded = settings.hasValue;
    final savedPin = settings.value?.parentPin;
    final stage = _currentStage(savedPin);

    final title = switch (stage) {
      _Stage.create => ParentCopy.pinSetTitle.fill(AgeTone.concise, {'n': '${AppConfig.parentPinLength}'}),
      _Stage.confirm => t(ParentCopy.pinConfirmTitle),
      _ => t(ParentCopy.pinEnterTitle),
    };
    return Scaffold(
      appBar: AppBar(title: Text(t(ParentCopy.title))),
      body: SafeArea(
        child: !loaded
            ? const Center(child: CircularProgressIndicator())
            // PIN 鍵盤置中、不撐滿大螢幕。
            : AdaptiveFrame(
                maxWidth: LayoutConfig.pinMaxWidth,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpace.m),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, key: const ValueKey('pin-title'), style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpace.s),
                        SizedBox(
                          height: 24,
                          child: _message == null
                              ? null
                              : Text(t(_message!), key: const ValueKey('pin-message'), style: const TextStyle(color: AppColors.inkSoft)),
                        ),
                        const SizedBox(height: AppSpace.s),
                        PinPad(entered: _entry.length, onDigit: (d) => _digit(d, savedPin), onBackspace: _backspace),
                        const SizedBox(height: AppSpace.m),
                        Text(t(ParentCopy.pinNote), style: const TextStyle(fontSize: 14, color: AppColors.inkSoft), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
