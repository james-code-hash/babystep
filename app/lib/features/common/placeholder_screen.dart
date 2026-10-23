import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../copy/common.dart';
import '../../providers.dart';

/// Foundation 階段的暫時畫面；Build 階段會被各 feature 換掉。
class PlaceholderScreen extends ConsumerWidget {
  const PlaceholderScreen({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: Text(CommonCopy.placeholderScreen.of(tone), key: ValueKey('placeholder-$name'))),
    );
  }
}
