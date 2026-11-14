import 'package:go_router/go_router.dart';

import '../../core/routes.dart';
import 'parent_screen.dart';

final parentRoutes = <RouteBase>[
  GoRoute(path: Routes.parent, builder: (context, state) => const ParentGateScreen()),
];
