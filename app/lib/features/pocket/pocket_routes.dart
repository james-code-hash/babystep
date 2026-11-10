import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes.dart';
import 'pocket_card_screen.dart';
import 'pocket_editor.dart';
import 'pocket_screen.dart';

/// 再看一次口袋（M1）。沒有權限的時候孩子看不到入口；就算直接開網址也只會看到空的口袋，沒有「放一張」。
final pocketRoutes = <RouteBase>[
  GoRoute(path: Routes.pocket, builder: (context, state) => const PocketScreen()),
  GoRoute(path: Routes.pocketNew, builder: (context, state) => const PocketEditorScreen()),
  GoRoute(
    path: '/pocket/card/:id',
    builder: (context, state) => PocketCardScreen(key: ValueKey(state.pathParameters['id']), cardId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/pocket/edit/:id',
    builder: (context, state) => PocketEditorScreen(cardId: state.pathParameters['id']),
  ),
];
