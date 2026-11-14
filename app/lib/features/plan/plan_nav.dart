import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes.dart';

/// 離開排計畫流程，回到首頁。
void leavePlanFlow(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    Navigator.of(context).maybePop();
  } else if (router.canPop()) {
    router.pop();
  } else {
    router.go(Routes.home);
  }
}
