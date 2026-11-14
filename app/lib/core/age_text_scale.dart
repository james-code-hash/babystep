import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../providers.dart';
import 'config.dart';

/// 小樹苗（活潑模式，6–8 歲）的字大一點（企劃書 §10.1；I3）。疊在系統字級設定上面。
/// 家長區用 [AgeTextScale.unscaled] 換回系統原本的大小。
class AgeTextScale extends ConsumerWidget {
  const AgeTextScale({super.key, required this.child});
  final Widget child;

  /// 在這一段畫面裡用系統原本的字級（家長區）。
  static Widget unscaled(BuildContext context, Widget child) {
    final base = context.dependOnInheritedWidgetOfExactType<_BaseScaler>()?.scaler;
    if (base == null) return child;
    return MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: base), child: child);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final base = mq.textScaler;
    final sprout = ref.watch(toneProvider) == AgeTone.lively;
    return _BaseScaler(
      scaler: base,
      child: sprout
          ? MediaQuery(
              data: mq.copyWith(textScaler: _Times(base, AgeConfig.sproutTextScale)),
              child: child,
            )
          : child,
    );
  }
}

class _BaseScaler extends InheritedWidget {
  const _BaseScaler({required this.scaler, required super.child});
  final TextScaler scaler;

  @override
  bool updateShouldNotify(_BaseScaler old) => old.scaler != scaler;
}

/// 系統字級 × 固定倍數（保留系統設定的非線性縮放）。
class _Times extends TextScaler {
  const _Times(this.base, this.factor);
  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.scale(14) / 14 * factor;

  @override
  bool operator ==(Object other) => other is _Times && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
