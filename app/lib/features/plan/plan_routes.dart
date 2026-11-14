import 'package:go_router/go_router.dart';

import '../../core/routes.dart';
import 'plan_screen.dart';

final planRoutes = <RouteBase>[
  GoRoute(path: Routes.plan, builder: (context, state) => const PlanFlowScreen()),
];
