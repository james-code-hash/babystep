import 'package:flutter/material.dart';

import 'config.dart';
import 'theme.dart';

/// 平板版面的小工具（docs/decisions.md E11）。
///
/// 只改排版，不改行為、文案或任何顯示的資訊。數字都在 [LayoutConfig]。
enum FormFactor {
  phone,
  tablet;

  /// 依螢幕短邊判斷（直放、橫放都一樣）。
  static FormFactor of(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= LayoutConfig.tabletMinShortestSide ? tablet : phone;

  bool get isTablet => this == tablet;
}

/// 步步出現的位置，各自有手機／平板兩種大小。
enum BubuSlot { hero, step, review, empty }

abstract final class Layout {
  static bool isTablet(BuildContext context) => FormFactor.of(context).isTablet;

  /// 可用寬度夠寬（平板橫放）→ 步步放到旁邊一欄。
  static bool isTwoPane(BuildContext context) => MediaQuery.sizeOf(context).width >= LayoutConfig.twoPaneMinWidth;

  static double contentMaxWidth(BuildContext context) =>
      isTablet(context) ? LayoutConfig.contentMaxWidthTablet : LayoutConfig.contentMaxWidthPhone;

  static double gutter(BuildContext context) =>
      isTablet(context) ? LayoutConfig.frameGutterTablet : LayoutConfig.frameGutterPhone;

  static double bubu(BuildContext context, BubuSlot slot) {
    final tablet = isTablet(context);
    return switch (slot) {
      BubuSlot.hero => tablet ? LayoutConfig.bubuHeroTablet : LayoutConfig.bubuHeroPhone,
      BubuSlot.step => tablet ? LayoutConfig.bubuStepTablet : LayoutConfig.bubuStepPhone,
      BubuSlot.review => tablet ? LayoutConfig.bubuReviewTablet : LayoutConfig.bubuReviewPhone,
      BubuSlot.empty => tablet ? LayoutConfig.bubuEmptyTablet : LayoutConfig.bubuEmptyPhone,
    };
  }

  /// 筆記本一列放幾頁：手機一律一欄；平板依可用寬度。
  static int notebookColumns(BuildContext context, double width) {
    if (!isTablet(context)) return 1;
    return (width ~/ LayoutConfig.notebookColumnMinWidth).clamp(1, LayoutConfig.notebookMaxColumns);
  }
}

/// 把內容置中、限制最大寬度；平板再多留一點左右邊距。
///
/// 手機上等於原本的 `Center(ConstrainedBox(maxWidth: 560))`。
class AdaptiveFrame extends StatelessWidget {
  const AdaptiveFrame({super.key, required this.child, this.maxWidth});

  /// 預設 [Layout.contentMaxWidth]。
  final double? maxWidth;
  final Widget child;

  static const frameKey = ValueKey('adaptive-frame');

  @override
  Widget build(BuildContext context) {
    final gutter = Layout.gutter(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Center(
        child: ConstrainedBox(
          key: frameKey,
          constraints: BoxConstraints(maxWidth: maxWidth ?? Layout.contentMaxWidth(context)),
          child: child,
        ),
      ),
    );
  }
}

/// 寬螢幕上的兩欄：旁邊一欄固定寬（通常是步步＋泡泡），主要內容一欄不超過平板單欄寬度。
class TwoPaneRow extends StatelessWidget {
  const TwoPaneRow({super.key, required this.side, required this.main, this.sideAtEnd = false});

  final Widget side;
  final Widget main;

  /// true：旁邊那欄放右邊（例如小路的洞察）。
  final bool sideAtEnd;

  static const rowKey = ValueKey('two-pane');
  static const sideKey = ValueKey('two-pane-side');
  static const mainKey = ValueKey('adaptive-main');

  @override
  Widget build(BuildContext context) {
    final sidePane = SizedBox(key: sideKey, width: LayoutConfig.sidePaneWidth, child: side);
    final mainPane = Expanded(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          key: mainKey,
          constraints: const BoxConstraints(maxWidth: LayoutConfig.contentMaxWidthTablet),
          child: main,
        ),
      ),
    );
    const gap = SizedBox(width: LayoutConfig.paneGap);
    return AdaptiveFrame(
      maxWidth: LayoutConfig.wideMaxWidth,
      child: Row(
        key: rowKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: sideAtEnd ? [mainPane, gap, sidePane] : [sidePane, gap, mainPane],
      ),
    );
  }
}

/// 一個可捲動的步驟畫面，旁邊有步步。
///
/// - 窄（手機、平板直放）：和原本一樣疊成一欄，[side] 在最上面（[sideAtEnd] 時在最下面）。
/// - 寬（平板橫放）：[side] 自成一欄、垂直置中；其餘內容在主欄裡捲動。
///
/// 內容一次全部建好（不用 lazy ListView），按鈕永遠在樹上。
class AdaptiveTwoPane extends StatelessWidget {
  const AdaptiveTwoPane({
    super.key,
    required this.side,
    required this.children,
    this.sideAtEnd = false,
    this.padding = const EdgeInsets.all(AppSpace.m),
    this.gap = AppSpace.l,
    this.maxWidth,
    this.scrollKey,
  });

  /// 依 `wide` 回傳旁邊（或上方）那一塊。
  final Widget Function(BuildContext context, bool wide) side;
  final List<Widget> children;
  final bool sideAtEnd;
  final EdgeInsets padding;

  /// 窄版時 [side] 與內容之間的距離。
  final double gap;

  /// 窄版的最大寬度（預設 [Layout.contentMaxWidth]）。
  final double? maxWidth;

  /// 主要內容那個捲動區的 key。
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) {
    if (Layout.isTwoPane(context)) {
      return TwoPaneRow(
        sideAtEnd: sideAtEnd,
        side: Center(
          child: SingleChildScrollView(padding: padding, child: side(context, true)),
        ),
        main: _scroll([...children]),
      );
    }
    final top = side(context, false);
    return AdaptiveFrame(
      maxWidth: maxWidth,
      child: _scroll(sideAtEnd ? [...children, SizedBox(height: gap), top] : [top, SizedBox(height: gap), ...children]),
    );
  }

  Widget _scroll(List<Widget> items) => SingleChildScrollView(
    padding: padding,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
  );
}
