import 'dart:math';

import 'package:flutter/material.dart';

import 'config.dart';
import 'theme.dart';

/// 平板版面的小工具（docs/decisions.md E11、E12）。
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

/// 平板上步步待的「舞台」：一塊比紙色深一點的圓角底，中間一圈淡淡的光（E12）。
///
/// 只是背景，不隨孩子做了什麼改變（底線 2）。
class StagePanel extends StatelessWidget {
  const StagePanel({super.key, required this.child, this.padding = const EdgeInsets.all(AppSpace.l)});
  final Widget child;
  final EdgeInsets padding;

  static const panelKey = ValueKey('stage-panel');

  @override
  Widget build(BuildContext context) => DecoratedBox(
        key: panelKey,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.stage),
          gradient: const RadialGradient(
            center: Alignment(0, -0.25),
            radius: 0.9,
            colors: [AppColors.stageGlow, AppColors.stage],
          ),
        ),
        child: Padding(padding: padding, child: child),
      );
}

/// 平板橫放的兩欄：一邊是舞台（通常是步步＋泡泡），另一邊是放在一張紙上的主要內容（E12）。
///
/// 舞台佔可用寬度的 [LayoutConfig.stageFraction]（有上下限），從上到下撐滿；
/// 紙撐滿剩下的空間，裡面的內容不超過 [LayoutConfig.stageMainMaxWidth]、置中。
class TwoPaneRow extends StatelessWidget {
  const TwoPaneRow({super.key, required this.side, required this.main, this.sideAtEnd = false});

  final Widget side;
  final Widget main;

  /// true：旁邊那欄放右邊（例如小路的洞察）；這時它是一般的欄，不畫舞台底色。
  final bool sideAtEnd;

  static const rowKey = ValueKey('two-pane');
  static const sideKey = ValueKey('two-pane-side');
  static const mainKey = ValueKey('adaptive-main');
  static const sheetKey = ValueKey('two-pane-sheet');

  /// 可用寬度 [width] 時舞台多寬。
  static double sideWidth(double width) =>
      (width * LayoutConfig.stageFraction).clamp(LayoutConfig.stageMinWidth, LayoutConfig.stageMaxWidth);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final inner = constraints.maxWidth - 2 * LayoutConfig.stageInset;
          final sidePane = SizedBox(
            key: sideKey,
            width: sideWidth(inner),
            child: sideAtEnd ? side : StagePanel(padding: EdgeInsets.zero, child: side),
          );
          final radius = BorderRadius.circular(AppRadius.stage);
          // 內容放在一張和舞台一樣高的紙上，大螢幕上不會散在空白裡。
          final mainPane = Expanded(
            child: DecoratedBox(
              key: sheetKey,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: radius,
                border: Border.all(color: AppColors.line),
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    key: mainKey,
                    constraints: const BoxConstraints(maxWidth: LayoutConfig.stageMainMaxWidth),
                    child: main,
                  ),
                ),
              ),
            ),
          );
          const gap = SizedBox(width: LayoutConfig.paneGap);
          return Padding(
            padding: const EdgeInsets.all(LayoutConfig.stageInset),
            child: Row(
              key: rowKey,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: sideAtEnd ? [mainPane, gap, sidePane] : [sidePane, gap, mainPane],
            ),
          );
        },
      );
}

/// 一個可捲動的步驟畫面，旁邊（或上方）有步步。
///
/// - 手機：和原本一樣疊成一欄，[side] 在最上面（[sideAtEnd] 時在最下面）。
/// - 平板直放：[side] 在上方一條舞台裡（固定不捲），內容在下面、不夠高時上下置中。
/// - 平板橫放：[side] 是一整欄的舞台、垂直置中；內容在紙上捲動，不夠高時上下置中。
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

  /// 手機上 [side] 與內容之間的距離。
  final double gap;

  /// 單欄時的最大寬度（預設 [Layout.contentMaxWidth]）。
  final double? maxWidth;

  /// 主要內容那個捲動區的 key。
  final Key? scrollKey;

  @override
  Widget build(BuildContext context) {
    if (Layout.isTwoPane(context)) {
      return TwoPaneRow(
        sideAtEnd: sideAtEnd,
        side: Center(
          child: SingleChildScrollView(
            padding: sideAtEnd ? padding : const EdgeInsets.all(AppSpace.l),
            child: side(context, true),
          ),
        ),
        main: CenteredScroll(key: scrollKey, padding: padding, children: children),
      );
    }
    if (Layout.isTablet(context) && !sideAtEnd) {
      final height = MediaQuery.sizeOf(context).height;
      return AdaptiveFrame(
        maxWidth: maxWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpace.m),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: height * LayoutConfig.bannerMaxHeightFraction),
              child: StagePanel(child: SingleChildScrollView(child: side(context, false))),
            ),
            Expanded(child: CenteredScroll(key: scrollKey, padding: padding, children: children)),
          ],
        ),
      );
    }
    final top = side(context, false);
    return AdaptiveFrame(
      maxWidth: maxWidth,
      child: SingleChildScrollView(
        key: scrollKey,
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: sideAtEnd ? [...children, SizedBox(height: gap), top] : [top, SizedBox(height: gap), ...children],
        ),
      ),
    );
  }
}

/// 捲動區：內容比畫面矮時上下置中（平板上不會全部擠在上面、下面一大片空白）。
class CenteredScroll extends StatelessWidget {
  const CenteredScroll({super.key, required this.children, this.padding = const EdgeInsets.all(AppSpace.m)});
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight.isFinite ? max(0, constraints.maxHeight - padding.vertical) : 0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      );
}
