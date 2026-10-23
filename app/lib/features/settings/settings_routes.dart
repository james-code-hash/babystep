import 'package:go_router/go_router.dart';

import '../../core/routes.dart';
import 'dress_up_screen.dart';
import 'settings_screen.dart';

final settingsRoutes = <RouteBase>[
  GoRoute(path: Routes.settings, builder: (context, state) => const ChildSettingsScreen()),
  // Routes.dressUp = '/settings/dress-up'
  GoRoute(path: Routes.dressUp, builder: (context, state) => const DressUpScreen()),
];
