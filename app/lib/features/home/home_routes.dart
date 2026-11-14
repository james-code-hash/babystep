import 'package:go_router/go_router.dart';

import '../../core/routes.dart';
import 'home_screen.dart';

final homeRoutes = <RouteBase>[
  GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen()),
];
