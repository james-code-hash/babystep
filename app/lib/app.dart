import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'copy/common.dart';
import 'core/theme.dart';
import 'domain/models.dart';
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

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: CommonCopy.appName.of(AgeTone.lively),
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: _router,
        locale: const Locale('zh', 'TW'),
        supportedLocales: const [Locale('zh', 'TW'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      );
}
