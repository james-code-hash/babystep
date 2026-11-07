import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'copy/common.dart';
import 'core/age_text_scale.dart';
import 'core/layout.dart';
import 'core/theme.dart';
import 'domain/models.dart';
import 'features/onboarding/pet_name.dart';
import 'purchase/purchase_sync.dart';
import 'router.dart';

class LittleStepsApp extends StatefulWidget {
  const LittleStepsApp({super.key, this.router});

  /// 測試可以傳自己的 router。
  final GoRouter? router;

  @override
  State<LittleStepsApp> createState() => _LittleStepsAppState();
}

class _LittleStepsAppState extends State<LittleStepsApp> {
  late final GoRouter _router = widget.router ?? buildRouter();
  static final _tabletTheme = buildTheme(tablet: true);

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: CommonCopy.appName.of(AgeTone.lively),
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: _router,
        locale: const Locale('zh', 'TW'),
        supportedLocales: const [Locale('zh', 'TW'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // 平板上字、按鈕、選項大一號（E12）；手機和原本一樣。
        builder: (context, child) => Theme(
          data: Layout.isTablet(context) ? _tabletTheme : Theme.of(context),
          child: PurchaseSync(child: PetNameScope(child: AgeTextScale(child: child ?? const SizedBox.shrink()))),
        ),
      );
}
