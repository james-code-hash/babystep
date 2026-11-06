import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bubu/bubu_view.dart';
import '../../copy/onboarding.dart';
import '../../copy/settings.dart';
import '../../core/config.dart';
import '../../core/layout.dart';
import '../../core/theme.dart';
import '../../providers.dart';
import '../onboarding/pet_name.dart';

/// 我的設定 → 幫步步取名字（D6）。隨時都能換，也能換回「步步」。
class PetNameScreen extends ConsumerWidget {
  const PetNameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    return Scaffold(
      appBar: AppBar(title: Text(SettingsCopy.nameTitle.of(tone))),
      body: SafeArea(
        child: AdaptiveFrame(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: LayoutConfig.contentMaxWidthPhone),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BubuView(expression: BubuExpression.curious, size: Layout.bubu(context, BubuSlot.step)),
                    const SizedBox(height: AppSpace.m),
                    Text(
                      OnboardingCopy.nameAskAgain.of(tone),
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpace.l),
                    PetNameForm(onDone: () => context.pop()),
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
