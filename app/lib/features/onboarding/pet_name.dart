import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../copy/line.dart';
import '../../copy/onboarding.dart';
import '../../core/config.dart';
import '../../core/copy_rules.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../providers.dart';
import '../../safety/safety_gate.dart';

/// 名字能不能用：不能空、不超過字數、不能有佔位符的括號，也不能是文案規則擋下的詞（「天才」⋯）。
/// 名字會出現在步步的每一句話裡，所以兩種語氣都要過。
bool petNameAllowed(String raw, CopyRules rules) {
  final t = raw.trim();
  // 和輸入框的 maxLength 一樣用「字」（grapheme）算，表情符號組合算一個。
  if (t.isEmpty || t.characters.length > AppConfig.maxPetNameChars) return false;
  if (t.contains('{') || t.contains('}')) return false;
  return AgeTone.values.every((tone) => rules.check(t, tone: tone).isEmpty);
}

/// 依設定更新 [PetName]，名字一換就讓整棵畫面重畫（每一句「步步」都要換）。
class PetNameScope extends ConsumerStatefulWidget {
  const PetNameScope({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<PetNameScope> createState() => _PetNameScopeState();
}

class _PetNameScopeState extends ConsumerState<PetNameScope> {
  String _shown = PetName.original;

  void _rebuildAll() {
    if (!mounted) return;
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) {
    PetName.current = ref.watch(settingsProvider.select((s) => s.value?.petName));
    if (PetName.current != _shown) {
      _shown = PetName.current;
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
    }
    return widget.child;
  }
}

/// 取名字的輸入框：「用這個名字」先過危機偵測、再過文案規則；另一顆按鈕保留／換回原本的名字。
class PetNameForm extends ConsumerStatefulWidget {
  const PetNameForm({super.key, required this.onDone});

  /// 存好之後（名字已寫進設定）。
  final VoidCallback onDone;

  @override
  ConsumerState<PetNameForm> createState() => _PetNameFormState();
}

class _PetNameFormState extends ConsumerState<PetNameForm> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _retry = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _use() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    final safe = await passesSafetyCheck(context, ref, text);
    if (!mounted) return;
    if (!safe || !petNameAllowed(text, ref.read(copyRulesProvider))) {
      _controller.clear();
      setState(() {
        _busy = false;
        _retry = safe;
      });
      return;
    }
    await _save(text);
  }

  Future<void> _save(String? name) async {
    setState(() => _busy = true);
    await ref.read(repositoryProvider).setPetName(name);
    // 先換上新名字：設定的 stream 下一刻才到，接下來那句「以後我就叫⋯」不能還是舊名字。
    PetName.current = name;
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final tone = ref.watch(toneProvider);
    final named = ref.watch(settingsProvider).value?.petName != null;
    final original = {'original': PetName.original};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('pet-name-field'),
          controller: _controller,
          maxLength: AppConfig.maxPetNameChars,
          decoration: InputDecoration(hintText: OnboardingCopy.nameHint.of(tone)),
          onChanged: (_) => setState(() => _retry = false),
          onSubmitted: (_) => _use(),
        ),
        if (_retry)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s),
            child: Text(
              OnboardingCopy.nameRetry.of(tone),
              key: const ValueKey('pet-name-retry'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
          ),
        const SizedBox(height: AppSpace.s),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpace.m,
          runSpacing: AppSpace.s,
          children: [
            FilledButton(
              key: const ValueKey('pet-name-use'),
              onPressed: _busy || _controller.text.trim().isEmpty ? null : _use,
              child: Text(OnboardingCopy.nameUse.of(tone)),
            ),
            OutlinedButton(
              key: const ValueKey('pet-name-keep'),
              onPressed: _busy ? null : () => _save(null),
              child: Text(named ? OnboardingCopy.nameBack.fill(tone, original) : OnboardingCopy.nameKeep.of(tone)),
            ),
          ],
        ),
      ],
    );
  }
}
