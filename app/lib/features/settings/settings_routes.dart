import 'package:go_router/go_router.dart';

import '../../core/routes.dart';
import 'settings_screen.dart';

final settingsRoutes = <RouteBase>[
  GoRoute(path: Routes.settings, builder: (context, state) => const ChildSettingsScreen()),
];
