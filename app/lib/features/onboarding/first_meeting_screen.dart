import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bubu/bubu_view.dart';
import '../../copy/line.dart';
import '../../copy/onboarding.dart';
import '../../core/config.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import 'pet_name.dart';

enum _Step { hello, name, done }

/// 初次見面（文案庫 §4.1，D6）：步步自我介紹 → 孩子幫步步取名字（可以不取）→ 開始。
/// 首頁在 `onboarded` 之前顯示這一頁；家長「刪除全部資料」後也會再見一次面。
class FirstMeetingScreen extends ConsumerStatefulWidget {
  const FirstMeetingScreen({super.key});

  @override
  ConsumerState<FirstMeetingScreen> createState() => _FirstMeetingScreenState();
}

class _FirstMeetingScreenState extends ConsumerState<FirstMeetingScreen> {
  _Step _step = _Step.hello;
  late final int _hello = ref.read(randomProvider).nextInt(OnboardingCopy.hello.length);

  @override
  Widget build(BuildContext context) {
    final tone = ref.watch(toneProvider);
    final says = switch (_step) {
      _Step.hello => OnboardingCopy.hello.lines[_hello].of(tone),
      _Step.name => OnboardingCopy.nameAsk.fill(tone, {'original': PetName.original}),
      _Step.done => OnboardingCopy.nameDone.of(tone),
    };
    final action = switch (_step) {
      _Step.hello => Center(
          child: FilledButton(
            key: const ValueKey('hello-next'),
            onPressed: () => setState(() => _step = _Step.name),
            child: Text(OnboardingCopy.helloReply.of(tone)),
          ),
        ),
      _Step.name => PetNameForm(onDone: () => setState(() => _step = _Step.done)),
      _Step.done => Center(
          child: FilledButton(
            key: const ValueKey('hello-done'),
            onPressed: () => ref.read(repositoryProvider).setOnboarded(),
            child: Text(OnboardingCopy.start.of(tone)),
          ),
        ),
    };
    final text = Theme.of(context).textTheme;
    return Scaffold(
      key: const ValueKey('first-meeting'),
      body: SafeArea(
        child: AdaptiveFrame(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.l),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: LayoutConfig.contentMaxWidthPhone),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BubuView(
                      expression: _step == _Step.name ? BubuExpression.curious : BubuExpression.happy,
                      size: Layout.bubu(context, BubuSlot.hero),
                    ),
                    const SizedBox(height: AppSpace.l),
                    Container(
                      key: const ValueKey('first-meeting-bubble'),
                      padding: const EdgeInsets.all(AppSpace.m),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Text(says, style: text.bodyLarge, textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: AppSpace.l),
                    action,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
