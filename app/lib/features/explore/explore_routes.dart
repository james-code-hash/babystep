import 'package:go_router/go_router.dart';

import '../../core/routes.dart';
import 'explore_screen.dart';

final exploreRoutes = <RouteBase>[
  GoRoute(path: Routes.explore, builder: (context, state) => const ExploreScreen()),
];
